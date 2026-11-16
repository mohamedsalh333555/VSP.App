#!/usr/bin/env python3
"""Run actual Team Skills withdrawal/review SQL against isolated local Postgres."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/'supabase/tests/team_skills_withdrawal_waitlist_isolated_contract.sql'
WITHDRAWAL=ROOT/'supabase/migrations/20261116100000_team_skills_registration_withdrawal.sql'
REVIEW=ROOT/'supabase/migrations/20261116102000_team_skills_waitlist_review_capacity.sql'
COMPAT=ROOT/'supabase/migrations/20261116103000_team_skills_withdraw_compatibility.sql'
DATABASE='vsp_team_skills_withdrawal_review_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding='utf-8')
    marker='-- REAL_TEAM_WITHDRAWAL_AND_REVIEW_FUNCTIONS'
    if fixture.count(marker)!=1:
        raise RuntimeError('Missing unique Team Skills withdrawal injection marker')
    sql=fixture.replace(marker,WITHDRAWAL.read_text(encoding='utf-8')+
                              '\n'+REVIEW.read_text(encoding='utf-8')+
                              '\n'+COMPAT.read_text(encoding='utf-8'))
    result=psql('postgres',command='CREATE DATABASE '+DATABASE)
    if result.returncode:
        raise RuntimeError('Fresh disposable localhost SQL database required')
    try:
        outcome=psql(DATABASE,sql=sql)
        if outcome.returncode:
            print('TEAM_SKILLS_WITHDRAWAL_WAITLIST_FAIL: '+outcome.stderr[-3000:],
                  file=sys.stderr)
            return 1
        print('PASS: captain, outsider, admin, fee, audit and bounded waitlist withdrawal')
        return 0
    finally:
        drop=psql('postgres',command='DROP DATABASE IF EXISTS '+DATABASE+' WITH (FORCE)')
        if drop.returncode:
            raise RuntimeError('Could not clean isolated withdrawal SQL database')


if __name__=='__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_WITHDRAWAL_WAITLIST_ERROR: '+str(exc),file=sys.stderr)
        raise SystemExit(1)
