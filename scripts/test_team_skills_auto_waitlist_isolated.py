#!/usr/bin/env python3
"""Execute captain-only bounded Team Skills waitlist on disposable Postgres."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT/'supabase/migrations/20261116093000_team_skills_automatic_waitlist_registration.sql'
FIXTURE = ROOT/'supabase/tests/team_skills_auto_waitlist_isolated_contract.sql'
DATABASE = 'vsp_team_skills_auto_waitlist_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture = FIXTURE.read_text(encoding='utf-8')
    marker = '-- AUTO_WAITLIST_REGISTRATION_FUNCTION'
    if fixture.count(marker)!=1:
        raise RuntimeError('Missing unique waitlist RPC marker')
    sql = fixture.replace(marker, MIGRATION.read_text(encoding='utf-8'))
    created = psql('postgres', command='CREATE DATABASE '+DATABASE)
    if created.returncode:
        raise RuntimeError('Fresh disposable local database required')
    try:
        result = psql(DATABASE,sql=sql)
        if result.returncode:
            print('TEAM_SKILLS_AUTO_WAITLIST_FAILED: '+result.stderr[-2600:],file=sys.stderr)
            return 1
        print('PASS: 4 pending + 4 waitlisted; 9th denied; captains isolated; audit correct')
        return 0
    finally:
        dropped = psql('postgres',command='DROP DATABASE IF EXISTS '+DATABASE+' WITH (FORCE)')
        if dropped.returncode:
            raise RuntimeError('Could not clean temporary waitlist database')


if __name__=='__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_AUTO_WAITLIST_ERROR: '+str(exc),file=sys.stderr)
        raise SystemExit(1)
