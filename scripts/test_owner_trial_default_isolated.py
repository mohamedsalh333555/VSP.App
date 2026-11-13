#!/usr/bin/env python3
"""Test the owner-trial default candidate in disposable local PostgreSQL only.

Does not touch real users, payments, staging, or production.
"""
from __future__ import annotations
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / "docs/security/sql/owner_trial_365_day_default_candidate.sql"
DB = "vsp_owner_trial_contracts"


def reject_unsafe_target(env: dict[str, str]) -> None:
    expected = {
        "VSP_CONTRACT_ISOLATED": "1",
        "PGHOST": "127.0.0.1",
        "PGPORT": "5432",
        "PGDATABASE": "vsp_security_contracts",
        "PGUSER": "postgres",
    }
    for key, value in expected.items():
        if env.get(key) != value:
            raise RuntimeError("Refusing non-isolated trial test: " + key)


def run(database: str, statement: str) -> subprocess.CompletedProcess[str]:
    if database not in (DB, "postgres"):
        raise RuntimeError("Unsupported SQL database target")
    env = {k: v for k,v in os.environ.items() if k not in {
        "PGHOSTADDR", "PGOPTIONS", "PGSERVICE", "PGSERVICEFILE",
        "PGPASSFILE", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
    }}
    return subprocess.run(
        ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
         "--port=5432", "--username=postgres", "--dbname=" + database,
         "--set=ON_ERROR_STOP=1", "-q", "-A", "-t"],
        text=True, input=statement, capture_output=True, timeout=45,
        env=env, check=False,
    )


def ok(database: str, statement: str) -> str:
    result = run(database, statement)
    if result.returncode:
        raise RuntimeError(result.stderr[-1100:])
    return result.stdout.strip()


def main() -> int:
    reject_unsafe_target(dict(os.environ))
    create = run("postgres", "CREATE DATABASE " + DB + ";")
    if create.returncode:
        raise RuntimeError("Never overwrite existing trial-test database")
    try:
        setup = """
CREATE TABLE public.users(
 id integer primary key,
 subscription_plan text default 'free_trial',
 trial_ends_at timestamptz default (timezone('utc',now()) + interval '365 days')
);
INSERT INTO public.users(id) VALUES(1);
"""
        ok(DB, setup)
        before = ok(DB, """
SELECT (trial_ends_at > now()+interval '300 days')::text
FROM public.users WHERE id=1;
""")
        if before != "true":
            raise RuntimeError("Pre-fix 365-day entitlement default not reproduced")

        candidate = SQL.read_text()
        ok(DB, candidate)
        ok(DB, candidate) # idempotent replay without overwriting existing records
        ok(DB, "INSERT INTO public.users(id) VALUES (2);")
        after = ok(DB, """
SELECT jsonb_build_object(
  'new_trial_null', (SELECT trial_ends_at IS NULL FROM public.users WHERE id=2),
  'old_preserved', (SELECT trial_ends_at > now()+interval '300 days'
                       FROM public.users WHERE id=1)
)::text;
""")
        if '"new_trial_null": true' not in after or '"old_preserved": true' not in after:
            raise RuntimeError("Default removal altered existing users or new user trial")

        ok(DB, """
UPDATE public.users SET trial_ends_at=now()+interval '7 days' WHERE id=2;
""")
        explicit = ok(DB, """
SELECT (trial_ends_at > now()+interval '6 days'
    AND trial_ends_at < now()+interval '8 days')::text
FROM public.users WHERE id=2;
""")
        if explicit != "true":
            raise RuntimeError("Explicit seven-day trial could not be stored")

        # A different policy default must not be overwritten by a stale patch.
        drift = run(DB, "ALTER TABLE public.users ALTER COLUMN trial_ends_at "
                        "SET DEFAULT (now()+interval '30 days');\n" + candidate)
        if drift.returncode == 0 or "OWNER_TRIAL_DEFAULT_SOURCE_DRIFT" not in drift.stderr:
            raise RuntimeError("Unreviewed trial default drift not rejected")
        print("PASS: 365-day default removed for new owners only; existing owner preserved")
        print("PASS: explicit seven-day trial can be stored; unexpected default refused")
        return 0
    finally:
        drop = run("postgres", "DROP DATABASE " + DB + " WITH (FORCE);")
        if drop.returncode:
            raise RuntimeError("Disposable trial database could not be deleted")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print("OWNER_TRIAL_DEFAULT_CONTRACT_FAILED: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
