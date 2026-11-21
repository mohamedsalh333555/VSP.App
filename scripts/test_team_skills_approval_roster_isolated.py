#!/usr/bin/env python3
"""Exercise the actual Team Skills admin-approval roster trigger locally."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/'supabase/migrations/20261116104000_team_skills_review_current_roster_guard.sql'
FIXTURE=ROOT/'supabase/tests/team_skills_approval_roster_isolated_contract.sql'
DATABASE='vsp_team_skills_approval_roster_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    marker='-- ACTUAL_TEAM_SKILLS_APPROVAL_ROSTER_GUARD'
    fixture=FIXTURE.read_text(encoding='utf-8')
    if fixture.count(marker)!=1:
        raise RuntimeError('Expected exactly one approval trigger insertion point')
    sql=fixture.replace(marker,MIGRATION.read_text(encoding='utf-8'))
    created=psql('postgres',command='CREATE DATABASE '+DATABASE)
    if created.returncode:
        raise RuntimeError('Cannot create fresh localhost test database')
    try:
        outcome=psql(DATABASE,sql=sql)
        if outcome.returncode:
            print('TEAM_SKILLS_APPROVAL_ROSTER_FAILED: '+outcome.stderr[-2800:],
                  file=sys.stderr)
            return 1
        print('PASS: approval denies blocked captain/player, ex-member, 4-player roster and wrong keeper')
        return 0
    finally:
        dropped=psql('postgres',command='DROP DATABASE IF EXISTS '+DATABASE+' WITH (FORCE)')
        if dropped.returncode:
            raise RuntimeError('Could not clean temporary Team Skills approval database')


if __name__=='__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_APPROVAL_ROSTER_ERROR: '+str(exc),file=sys.stderr)
        raise SystemExit(1)
