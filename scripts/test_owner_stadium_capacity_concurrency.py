#!/usr/bin/env python3
"""Isolated quota-trigger candidate: direct REST-equivalent SQL and two-client race.

This script never accesses a hosted database, customer data or user accounts.
It refuses non-loopback targets and any existing scratch DB by name.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
CANDIDATE = ROOT / "docs/security/sql/owner_stadium_capacity_guard_candidate.sql"
MODERATION_CANDIDATE = ROOT / "docs/security/sql/stadium_moderation_write_guard_candidate.sql"
SCRATCH = "vsp_owner_quota_contracts"
FREE = "10000000-0000-4000-8000-000000000001"
PRO = "10000000-0000-4000-8000-000000000002"
RACE = "10000000-0000-4000-8000-000000000003"

FIXTURE = r"""-- Disposable fixture, NEVER run against staging/production.
-- Roles are global to the local Postgres *cluster* and may have been created
-- earlier by account-security contracts in the sibling scratch database.
DO $fixture_roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
END;
$fixture_roles$;
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA public, auth TO authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $auth$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$auth$;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  role text NOT NULL DEFAULT 'owner',
  max_stadiums integer NOT NULL CHECK (max_stadiums > 0)
);
CREATE TABLE public.stadiums (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.users(id),
  is_deleted_by_owner boolean DEFAULT false,
  name text,
  is_verified boolean DEFAULT true,
  is_blocked boolean DEFAULT false,
  is_featured boolean DEFAULT false,
  rating numeric DEFAULT 0,
  reviews_count integer DEFAULT 0
);
GRANT SELECT, INSERT, UPDATE ON public.stadiums TO authenticated;
GRANT SELECT ON public.users TO authenticated;
ALTER TABLE public.stadiums ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_read ON public.stadiums FOR SELECT TO authenticated
USING (auth.uid() = owner_id);
CREATE POLICY own_insert ON public.stadiums FOR INSERT TO authenticated
WITH CHECK (auth.uid() = owner_id);
CREATE POLICY own_update ON public.stadiums FOR UPDATE TO authenticated
USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

CREATE FUNCTION public.is_admin_or_cofounder(p_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog,public,pg_temp
AS $admin$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND role IN ('admin','co_founder')
  )
$admin$;

-- Isolated admin role may approve/moderate any pitch.
CREATE POLICY moderation_admin_all ON public.stadiums FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

-- Minimal signature-compatible stand-in for the real evaluator.
-- Uses server-side owner rows and counts active stadiums; does not take
-- client price, plan or max/count inputs. It is not a full schema replay.
CREATE FUNCTION public.evaluate_owner_stadium_capacity(
  p_owner_id uuid, p_exclude_stadium_id uuid DEFAULT NULL::uuid
)
RETURNS TABLE (
  allowed boolean, current_count integer, max_allowed integer,
  is_trial boolean, is_sub_active boolean, plan_code text, message text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,public,pg_temp
AS $eval$
DECLARE v_count integer; v_max integer;
BEGIN
  SELECT max_stadiums INTO v_max FROM public.users WHERE id=p_owner_id;
  SELECT count(*)::integer INTO v_count
    FROM public.stadiums
    WHERE owner_id = p_owner_id
      AND COALESCE(is_deleted_by_owner,false) = false
      AND (p_exclude_stadium_id IS NULL OR id <> p_exclude_stadium_id);
  RETURN QUERY SELECT v_count < v_max, v_count, v_max,
    false,false,CASE WHEN v_max = 1 THEN 'basic' ELSE 'pro' END::text,
    'isolated fixture'::text;
END;
$eval$;

INSERT INTO public.users(id,role,max_stadiums) VALUES
 ('10000000-0000-4000-8000-000000000001','owner',1),
 ('10000000-0000-4000-8000-000000000002','owner',3),
 ('10000000-0000-4000-8000-000000000003','owner',1),
 ('10000000-0000-4000-8000-000000000004','admin',99);

INSERT INTO public.stadiums(owner_id,name) VALUES
 ('10000000-0000-4000-8000-000000000002','pro-1'),
 ('10000000-0000-4000-8000-000000000002','pro-2');
"""


def reject_nonlocal_targets(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("VSP_CONTRACT_ISOLATED=1 is required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost"):
        raise RuntimeError("Only local loopback PostgreSQL is accepted")
    if env.get("PGPORT") != "5432":
        raise RuntimeError("Unexpected PostgreSQL port")
    if env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Only vsp_security_contracts CI source is accepted")
    if env.get("PGUSER") != "postgres":
        raise RuntimeError("Only disposable fixture-owner credentials accepted")


def safe_env(env: dict[str, str]) -> dict[str, str]:
    banned = {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGUSER", "PGDATABASE",
        "PGOPTIONS", "PGSERVICE", "PGSERVICEFILE", "PGPASSFILE",
    }
    return {k: v for k, v in env.items() if k not in banned}


def run(database: str, statement: str) -> subprocess.CompletedProcess[str]:
    if database not in ("postgres", SCRATCH):
        raise RuntimeError("Database name outside the isolated allowlist")
    return subprocess.run([
        "psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
        "--port=5432", "--username=postgres", "--dbname=" + database,
        "--set=ON_ERROR_STOP=1", "-q", "-A", "-t",
    ], input=statement, text=True, capture_output=True, timeout=45,
        env=safe_env(dict(os.environ)), check=False)


def ok(database: str, statement: str) -> str:
    result = run(database, statement)
    if result.returncode:
        raise RuntimeError(result.stderr[-1300:])
    return result.stdout.strip()


def deny(database: str, statement: str, marker: str) -> None:
    result = run(database, statement)
    if result.returncode == 0 or marker not in result.stderr:
        raise RuntimeError("Expected rejection " + marker + ": " + result.stderr[-1300:])


def as_owner(owner: str, statement: str) -> str:
    return f"""BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.role = 'authenticated';
SET LOCAL request.jwt.claim.sub = '{owner}';
{statement}
COMMIT;
"""


def count_active(owner: str) -> int:
    return int(ok(SCRATCH, f"""SELECT count(*) FROM public.stadiums
WHERE owner_id='{owner}' AND COALESCE(is_deleted_by_owner,false)=false;"""))


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    created = False
    create = run("postgres", "CREATE DATABASE " + SCRATCH + ";")
    if create.returncode:
        raise RuntimeError("Refusing to adopt or overwrite an existing scratch database")
    created = True
    try:
        ok(SCRATCH, FIXTURE)

        # Reproduce the source risk before applying the candidate: ownership-
        # only RLS permits a basic owner to create two venues.
        ok(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES
('{FREE}','baseline-1'),('{FREE}','baseline-2');
"""))
        if count_active(FREE) != 2:
            raise RuntimeError("Baseline over-limit write not reproduced")
        ok(SCRATCH, f"DELETE FROM public.stadiums WHERE owner_id='{FREE}';")
        print("PASS: ownership-only baseline reproduces over-limit INSERT", flush=True)

        ok(SCRATCH, CANDIDATE.read_text(encoding="utf-8"))

        ok(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES('{FREE}','free-first');
"""))
        deny(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES('{FREE}','free-second');
"""), "STADIUM_LIMIT_EXCEEDED")
        if count_active(FREE) != 1:
            raise RuntimeError("Free owner quota violated")
        print("PASS: free plan accepts 1 and rejects 2", flush=True)

        ok(SCRATCH, as_owner(PRO, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES('{PRO}','pro-third');
"""))
        deny(SCRATCH, as_owner(PRO, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES('{PRO}','pro-fourth');
"""), "STADIUM_LIMIT_EXCEEDED")
        if count_active(PRO) != 3:
            raise RuntimeError("Pro owner quota violated")
        print("PASS: Pro plan accepts 3 and rejects 4", flush=True)

        deny(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name) VALUES('{PRO}','cross-owner');
"""), "STADIUM_OWNER_UNAUTHORIZED")
        if count_active(PRO) != 3:
            raise RuntimeError("Cross-owner insert changed the database")
        print("PASS: caller cannot create pitch for another owner", flush=True)

        # Soft-deleted fixtures are excluded from the quota until reactivated.
        ok(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name,is_deleted_by_owner)
VALUES('{FREE}','archived',true);
"""))
        deny(SCRATCH, as_owner(FREE, """
UPDATE public.stadiums SET is_deleted_by_owner=false
WHERE name='archived';
"""), "STADIUM_LIMIT_EXCEEDED")
        if count_active(FREE) != 1:
            raise RuntimeError("Reactivation bypassed the quota")
        ok(SCRATCH, as_owner(FREE, """
UPDATE public.stadiums SET name='first-edited' WHERE name='free-first';
"""))
        print("PASS: over-limit reactivation rejected; editing an active venue still works",
              flush=True)

        # Trigger names fire lexically. The delay runs *after* acquiring the
        # owner lock, forcing the second independent SQL connection to contend.
        ok(SCRATCH, """
CREATE FUNCTION public.test_hold_owner_lock() RETURNS trigger
LANGUAGE plpgsql AS $delay$ BEGIN PERFORM pg_sleep(0.35); RETURN NEW; END; $delay$;
CREATE TRIGGER zzz_hold_owner_lock BEFORE INSERT ON public.stadiums
FOR EACH ROW EXECUTE FUNCTION public.test_hold_owner_lock();
""")

        barrier = threading.Barrier(2)

        def attempt(number: int) -> subprocess.CompletedProcess[str]:
            barrier.wait(timeout=10)
            return run(SCRATCH, as_owner(RACE, f"""
INSERT INTO public.stadiums(owner_id,name)
VALUES('{RACE}','race-{number}');
"""))

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(attempt, (1, 2)))
        successes = [p for p in results if p.returncode == 0]
        rejected = [p for p in results if p.returncode != 0 and
                    "STADIUM_LIMIT_EXCEEDED" in p.stderr]
        if len(successes) != 1 or len(rejected) != 1 or count_active(RACE) != 1:
            raise RuntimeError("Concurrent quota breach or unexpected error: "
                               + " | ".join(p.stderr[-500:] for p in results))
        print("PASS: independent concurrent direct INSERTs serialize to one winner",
              flush=True)

        # Reproduce the actual production function's privilege confusion on
        # this isolated database. SECURITY DEFINER is owned by postgres;
        # current_user is therefore postgres even when an authenticated venue
        # owner invoked UPDATE via PostgREST-equivalent SQL.
        ok(SCRATCH, """
CREATE OR REPLACE FUNCTION public.protect_stadium_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO public, pg_temp
AS $legacy_moderation$
BEGIN
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN NEW;
  END IF;
  IF NEW.rating IS DISTINCT FROM OLD.rating
     OR NEW.reviews_count IS DISTINCT FROM OLD.reviews_count
     OR NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'LEGACY_MODERATION_SHOULD_BLOCK_OWNER';
  END IF;
  RETURN NEW;
END;
$legacy_moderation$;
CREATE TRIGGER trg_protect_stadium_sensitive_fields
BEFORE UPDATE ON public.stadiums
FOR EACH ROW EXECUTE FUNCTION public.protect_stadium_sensitive_fields();
""")
        guard_owner = ok(SCRATCH, """
SELECT pg_get_userbyid(proowner)
FROM pg_proc
WHERE oid = 'public.protect_stadium_sensitive_fields()'::regprocedure;
""")
        if guard_owner != "postgres":
            raise RuntimeError("Disposable SECURITY DEFINER owner mismatch")

        # Source-equivalent production bypass: the legacy protection trigger
        # is installed and still permits an authenticated owner's forged
        # rating/review write because its privileged early return always fires.
        ok(SCRATCH, as_owner(PRO, """
UPDATE public.stadiums SET rating=4.9, reviews_count=450,
  is_blocked=false WHERE name='pro-1';
"""))
        baseline = ok(SCRATCH, """
SELECT rating::text || '/' || reviews_count::text
FROM public.stadiums WHERE name='pro-1';
""")
        if baseline != "4.9/450":
            raise RuntimeError("Baseline owner review-tampering not reproduced")
        ok(SCRATCH, """
UPDATE public.stadiums SET rating=0, reviews_count=0, is_verified=false
WHERE name='pro-1';
""")
        print("PASS: production-style SECURITY DEFINER early bypass permits forged rating/review count",
              flush=True)

        ok(SCRATCH, MODERATION_CANDIDATE.read_text(encoding="utf-8"))

        for field_update in (
            "rating=5",
            "reviews_count=10000",
            "is_blocked=true",
            "is_featured=true",
            "is_verified=true",
        ):
            deny(SCRATCH, as_owner(PRO, f"""
UPDATE public.stadiums SET {field_update} WHERE name='pro-1';
"""), "STADIUM_MODERATION_FIELD_FORBIDDEN")
        print("PASS: owner cannot forge reviews, unblock/alter moderation or self-verify",
              flush=True)

        # Existing owner edits and voluntary review demotion remain possible.
        ok(SCRATCH, as_owner(PRO, """
UPDATE public.stadiums SET name='pro-edited', is_verified=false
WHERE name='pro-1';
"""))
        print("PASS: owner venue edits and re-review remain available", flush=True)

        # New legitimate owner rows default to unverified, even when older
        # staging/production schemas originally defaulted verified=true.
        # Explicit self-verification and forged ratings still fail closed.
        ok(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name,is_deleted_by_owner)
VALUES('{FREE}', 'unapproved-default-insert', true);
"""))
        verified_flag = ok(SCRATCH, """
SELECT is_verified::text FROM public.stadiums
WHERE name='unapproved-default-insert';
""")
        if verified_flag != "false":
            raise RuntimeError("New owner venue must default to unverified")
        deny(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name,is_deleted_by_owner,is_verified)
VALUES('{FREE}', 'forged-owner-verification', true,true);
"""), "STADIUM_MODERATION_FIELD_FORBIDDEN")
        deny(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name,is_deleted_by_owner,is_verified,rating)
VALUES('{FREE}', 'forged-insert', true,false,5);
"""), "STADIUM_MODERATION_FIELD_FORBIDDEN")
        ok(SCRATCH, as_owner(FREE, f"""
INSERT INTO public.stadiums(owner_id,name,is_deleted_by_owner,is_verified)
VALUES('{FREE}', 'properly-unverified-archive', true,false);
"""))
        print("PASS: owner default unverified; explicit approval/rating forgery denied", flush=True)

        # Admin approval remains possible. Test as an independent JWT subject
        # with a real admin policy in the disposable test database.
        admin = "10000000-0000-4000-8000-000000000004"
        ok(SCRATCH, as_owner(admin, """
UPDATE public.stadiums SET is_verified=true, is_blocked=true, rating=3.5
WHERE name='pro-edited';
"""))
        actual = ok(SCRATCH, """
SELECT is_verified::text || '/' || is_blocked::text || '/' || rating::text
FROM public.stadiums WHERE name='pro-edited';
""")
        if actual != "true/true/3.5":
            raise RuntimeError("Admin moderation was blocked in the fixture")
        print("PASS: approved admin role retains moderator permissions", flush=True)
        return 0
    finally:
        if created:
            drop = run("postgres", "DROP DATABASE " + SCRATCH + " WITH (FORCE);")
            if drop.returncode:
                raise RuntimeError("Cannot clean up isolated scratch DB: " + drop.stderr[-500:])


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired,
            threading.BrokenBarrierError) as exc:
        print("OWNER_QUOTA_ISOLATED_CONTRACT_FAILED: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
