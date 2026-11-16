#!/usr/bin/env python3
"""Race two independent SQL clients for the same goalkeeper opponent team.

The test refuses all hosted PostgreSQL endpoints and drops its temporary
localhost database even if an assertion fails.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'supabase/migrations/20261116092000_team_skills_keeper_station_team_conflicts.sql'
FIXTURE = ROOT / 'supabase/tests/team_skills_keeper_station_concurrency_fixture.sql'
DATABASE = 'vsp_team_skills_keeper_station_race'
ADMIN = '00000000-0000-0000-0000-000000009001'
TEAM_TWO = '00000000-0000-0000-0000-000000000202'
TEAM_FOUR = '00000000-0000-0000-0000-000000000204'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    marker = '-- TEAM_SKILLS_KEEPER_TEAM_MIGRATION'
    sql = FIXTURE.read_text(encoding='utf-8')
    if sql.count(marker) != 1:
        raise RuntimeError('Missing unique goalkeeper station migration marker')
    sql = sql.replace(marker, MIGRATION.read_text(encoding='utf-8'))
    created = psql('postgres', command='CREATE DATABASE ' + DATABASE)
    if created.returncode:
        raise RuntimeError('Fresh disposable local database required')
    try:
        setup = psql(DATABASE, sql=sql)
        if setup.returncode:
            raise RuntimeError('Keeper fixture failed: ' + setup.stderr[-1700:])

        def race(registration_id: str) -> str:
            statement = f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{ADMIN}',true);
do $attempt$
declare outcome text:='scheduled';
begin
 begin
   perform public.team_skills_schedule_goalkeeper(
    '{registration_id}','{TEAM_TWO}',
    now()+interval '2 days 1 hour',now()+interval '2 days 1 hour 10 minutes');
 exception when others then
   if position('participating team' in lower(sqlerrm))>0 then
     outcome:='conflict';
   else raise;end if;
 end;
 perform set_config('vsp_keeper_race_outcome',outcome,true);
end $attempt$;
select current_setting('vsp_keeper_race_outcome');
commit;
"""
            result = psql(DATABASE, sql=statement)
            if result.returncode:
                raise RuntimeError('Keeper station session error: ' + result.stderr[-1500:])
            outcomes = [line.strip() for line in result.stdout.splitlines()
                        if line.strip() in ('scheduled','conflict')]
            if len(outcomes) != 1:
                raise RuntimeError('Cannot read keeper station outcome: ' + result.stdout[-450:])
            return outcomes[0]

        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(race, [
                '00000000-0000-0000-0000-000000000101',
                '00000000-0000-0000-0000-000000000103',
            ]))
        if sorted(outcomes) != ['conflict','scheduled']:
            raise RuntimeError('Shared shooting opponent was double-booked: ' + str(outcomes))

        # Exactly adjacent intervals are legal, and cancellation of a
        # conflicting request must leave the schedule/audit unchanged.
        next_station = psql(DATABASE, sql=f"""
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','{ADMIN}',true);
select public.team_skills_schedule_goalkeeper(
 '00000000-0000-0000-0000-000000000104','{TEAM_TWO}',
 now()+interval '2 days 1 hour 10 minutes',
 now()+interval '2 days 1 hour 20 minutes');
commit;
""")
        if next_station.returncode:
            raise RuntimeError('Adjacent keeper session failed: ' + next_station.stderr[-1500:])

        inspect = psql(DATABASE, sql="""
select count(*) from public.team_skills_goalkeeper_trials;
select count(*) from public.team_skills_audit where action='schedule_goalkeeper';
""")
        counts = [line.strip() for line in inspect.stdout.splitlines() if line.strip().isdigit()]
        if inspect.returncode or counts != ['2','2']:
            raise RuntimeError('Keeper schedule/audit diverged after race: ' + str(counts))
        print('PASS: two DB sessions, one shared-opponent booking only, adjacent slot accepted')
        return 0
    finally:
        drop = psql('postgres', command='DROP DATABASE IF EXISTS ' + DATABASE + ' WITH (FORCE)')
        if drop.returncode:
            raise RuntimeError('Disposable keeper station test database could not be cleaned')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_KEEPER_RACE_ERROR: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
