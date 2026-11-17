#!/usr/bin/env python3
"""Race two independent authenticated-captain SQL sessions for the final cup slot.

Uses the actual checked-in Team Skills registration RPC on an exclusively
disposable PostgreSQL database on localhost. No remote Supabase connection.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "supabase/tests/team_skills_auto_waitlist_isolated_contract.sql"
MIGRATION = ROOT / "supabase/migrations/20261116164000_team_skills_blocked_captain_roster_guard.sql"
DATABASE = "vsp_team_skills_enrollment_last_slot"
CUP = "00000000-0000-0000-0000-000000000001"


def identity(n: int) -> str:
    return "00000000-0000-0000-0000-" + str(n).zfill(12)


def setup_sql() -> str:
    fixture = FIXTURE.read_text(encoding="utf-8")
    marker = "-- AUTO_WAITLIST_REGISTRATION_FUNCTION"
    if fixture.count(marker) != 1 or fixture.count("do $applications$") != 1:
        raise RuntimeError("Team Skills fixture drift")
    setup = fixture.split("do $applications$", 1)[0]
    setup = setup.replace(marker, MIGRATION.read_text(encoding="utf-8"))
    return setup + """
do $fixtures$
declare n integer; t uuid; capt uuid; people uuid[]; rid uuid;
begin
  for n in 1..3 loop
    t:=('00000000-0000-0000-0000-'||lpad((200+n)::text,12,'0'))::uuid;
    capt:=('00000000-0000-0000-0000-'||lpad((900+n)::text,12,'0'))::uuid;
    select array_agg(user_id order by user_id) into people
    from public.team_members where team_id=t;
    insert into public.team_skills_registrations(
       cup_id,team_id,captain_id,goalkeeper_id,representative_id,status)
    values('00000000-0000-0000-0000-000000000001',
       t,capt,people[1],people[2],'pending') returning id into rid;
    insert into public.team_skills_roster(
       cup_id,registration_id,player_id,position,active)
    select '00000000-0000-0000-0000-000000000001',rid,
       x,case when x=people[1] then 'goalkeeper' else 'field' end,true
    from unnest(people) x;
  end loop;
end $fixtures$;
do $roles$ begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then
   create role authenticated;
 end if;
end $roles$;
grant usage on schema public to authenticated;
grant execute on function public.team_skills_register(
  uuid,uuid,uuid[],uuid,uuid) to authenticated;
create function public.fixture_delay_registration() returns trigger
language plpgsql as $delay$
begin
  perform pg_sleep(0.3);
  return new;
end $delay$;
create trigger fixture_delay_registration
before insert on public.team_skills_registrations
for each row execute function public.fixture_delay_registration();
"""


def register(n: int) -> str:
    captain = identity(900+n)
    team = identity(200+n)
    people = [identity(5000+n*100+j) for j in range(1, 6)]
    ids = ",".join("'" + person + "'" for person in people)
    sql = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{captain}',true);
select public.team_skills_register(
  '{CUP}','{team}',array[{ids}]::uuid[],
  '{people[0]}','{people[1]}');
commit;
select status from public.team_skills_registrations
 where cup_id='{CUP}' and team_id='{team}';
"""
    r = psql(DATABASE, sql=sql)
    if r.returncode:
        raise RuntimeError("Concurrent signup failed: " + r.stderr[-1300:])
    statuses = [x.strip() for x in r.stdout.splitlines()
                if x.strip() in ("pending", "waitlist")]
    if len(statuses) != 1:
        raise RuntimeError("Expected one persisted captain status, got: " + r.stdout[-400:])
    return statuses[0]


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable local SQL database required")
    try:
        seeded = psql(DATABASE, sql=setup_sql())
        if seeded.returncode:
            raise RuntimeError("Captain race fixture setup failed: " + seeded.stderr[-1700:])
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(register, (4, 5)))
        if sorted(results) != ["pending", "waitlist"]:
            raise RuntimeError("Two captains did not split final slot and waitlist: " + repr(results))
        checked = psql(DATABASE, sql=f"""
select concat(
 (select count(*) from public.team_skills_registrations
  where cup_id='{CUP}' and status='pending'), ':',
 (select count(*) from public.team_skills_registrations
  where cup_id='{CUP}' and status='waitlist'), ':',
 (select count(*) from public.team_skills_roster
  where cup_id='{CUP}' and active), ':',
 (select count(*) from public.team_skills_audit
  where cup_id='{CUP}' and action='register_team'));
""")
        if checked.returncode or "4:1:25:2" not in checked.stdout:
            raise RuntimeError("Final slot, roster or audit count wrong: " + checked.stdout[-300:])
        print("PASS: independent captain connections race last slot; 4 pending, 1 waitlisted, 25 roster slots, 2 audits")
        return 0
    finally:
        removed = psql("postgres", command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if removed.returncode:
            raise RuntimeError("Registration concurrency fixture cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print("TEAM_SKILLS_REGISTRATION_RACE_ERROR: " + str(error), file=sys.stderr)
        raise SystemExit(1)
