#!/usr/bin/env python3
"""Two independent SQL connections race to approve the final Team Skills slot.

Strictly disposable localhost PostgreSQL. The cup row lock is exercised
under contention, not merely with sequential capacity assertions.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "supabase/tests/team_skills_capacity_isolated_contract.sql"
MIGRATION = ROOT / "supabase/migrations/20261116094000_team_skills_waitlist_promotion_capacity.sql"
DATABASE = "vsp_team_skills_capacity_race"
CUP = "00000000-0000-0000-0000-000000000001"
ADMIN = "00000000-0000-0000-0000-000000009001"
WAITING = (
    "00000000-0000-0000-0000-000000000115",
    "00000000-0000-0000-0000-000000000116",
)


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture = CONTRACT.read_text(encoding="utf-8")
    marker = "-- CAPACITY_MIGRATION_HERE"
    if fixture.count(marker) != 1:
        raise RuntimeError("Missing unique review-function marker")
    # Reuse the same SQL schema, auth, and actual migration as sequential CI.
    setup = fixture.split("insert into public.team_skills_cups(", 1)[0]
    setup = setup.replace(marker, MIGRATION.read_text(encoding="utf-8"))
    setup += f"""
insert into public.team_skills_cups(id,status,starts_at,max_teams)
values('{CUP}','registration',now()+interval '3 days',4);
insert into public.team_skills_registrations(id,cup_id,status)
values
('00000000-0000-0000-0000-000000000111','{CUP}','approved'),
('00000000-0000-0000-0000-000000000112','{CUP}','approved'),
('00000000-0000-0000-0000-000000000113','{CUP}','approved'),
('{WAITING[0]}','{CUP}','waitlist'),
('{WAITING[1]}','{CUP}','waitlist');

-- Hold a winning UPDATE long enough to ensure the other SQL connection
-- attempts its own review while the first transaction still holds the cup lock.
create function public.fixture_delay_review() returns trigger
language plpgsql as $delay$
begin
  perform pg_sleep(0.3);
  return new;
end $delay$;
create trigger fixture_delay_review
before update on public.team_skills_registrations
for each row execute function public.fixture_delay_review();
"""
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh local SQL race database required")
    try:
        seeded = psql(DATABASE, sql=setup)
        if seeded.returncode:
            raise RuntimeError("Staging fixture failed: " + seeded.stderr[-1400:])

        def attempt(registration_id: str) -> str:
            # Catch only the known full-capacity rejection; other SQL failures
            # must fail the test and never masquerade as successful isolation.
            query = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{ADMIN}',true);
do $attempt$
begin
  begin
    perform public.team_skills_review_registration('{registration_id}','approved',null);
  exception when others then
    if position('capacity' in lower(sqlerrm))=0 then raise; end if;
  end;
end $attempt$;
commit;
select status from public.team_skills_registrations where id='{registration_id}';
"""
            result = psql(DATABASE, sql=query)
            if result.returncode:
                raise RuntimeError("Race SQL session failed: " + result.stderr[-1200:])
            statuses = [line.strip() for line in result.stdout.splitlines()
                        if line.strip() in ("approved", "waitlist")]
            if len(statuses) != 1:
                raise RuntimeError("Missing scoped review status: " + result.stdout[-300:])
            return statuses[0]

        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(attempt, WAITING))
        if sorted(outcomes) != ["approved", "waitlist"]:
            raise RuntimeError("Final slot race allowed both or neither team")

        inspect = psql(DATABASE, sql=f"""
select count(*) as accepted
from public.team_skills_registrations
where cup_id='{CUP}' and status='approved';
""")
        # psql's default aligned table output ends with "(1 row)", not "4".
        counts = [line.strip() for line in inspect.stdout.splitlines()
                  if line.strip().isdigit()]
        if inspect.returncode or counts != ["4"]:
            raise RuntimeError("Approved team count diverged after concurrent review")
        print("PASS: 2 independent SQL sessions, one waitlist approval and one capacity denial")
        return 0
    finally:
        drop = psql("postgres", command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if drop.returncode:
            raise RuntimeError("Disposable SQL race database cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_RACE_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
