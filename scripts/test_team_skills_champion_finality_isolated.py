#!/usr/bin/env python3
"""Verify championship fairness, title tie guards, and final score freeze.

Executes checked-in migrations only on a newly created disposable PostgreSQL
database on localhost. Hosted databases and production credentials are refused.
"""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=ROOT/'supabase/tests/team_skills_champion_finality_isolated_contract.sql'
MIGRATIONS=[
 ROOT/'supabase/migrations/20261116098000_team_skills_champion_finality.sql',
 ROOT/'supabase/migrations/20261116099000_team_skills_champion_finality_uuid_fix.sql',
]
DATABASE='vsp_team_skills_champion_finality_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=CONTRACT.read_text(encoding='utf-8')
    marker='-- CHAMPION_FINALITY_REAL_MIGRATIONS'
    if fixture.count(marker)!=1:
        raise RuntimeError('Missing unique finality migration insertion marker')
    sql=fixture.replace(marker,'\n'.join(
        path.read_text(encoding='utf-8') for path in MIGRATIONS))
    created=psql('postgres',command='CREATE DATABASE '+DATABASE)
    if created.returncode:
        raise RuntimeError('Fresh disposable finality database required')
    try:
        outcome=psql(DATABASE,sql=sql)
        if outcome.returncode:
            print('TEAM_SKILLS_CHAMPION_FINALITY_FAIL: '+outcome.stderr[-2800:],
                  file=sys.stderr)
            return 1
        print('PASS: all-stage completion, sole top score, and frozen championship results')
        return 0
    finally:
        dropped=psql('postgres',command='DROP DATABASE IF EXISTS '+DATABASE+' WITH (FORCE)')
        if dropped.returncode:
            raise RuntimeError('Disposable champion test database cleanup failed')


if __name__=='__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_CHAMPION_FINALITY_ERROR: '+str(exc),file=sys.stderr)
        raise SystemExit(1)
