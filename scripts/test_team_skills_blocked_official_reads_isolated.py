#!/usr/bin/env python3
"""Exercise real Team Skills read RLS policy on disposable local PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'supabase/migrations/20261116089000_team_skills_blocked_official_read_rls.sql'
CONTRACT = ROOT / 'supabase/tests/team_skills_blocked_official_reads_isolated_contract.sql'
DATABASE = 'vsp_team_skills_blocked_read_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture = CONTRACT.read_text(encoding='utf-8')
    marker = '-- CURRENT_BLOCKED_OFFICIAL_READ_MIGRATION'
    if fixture.count(marker) != 1:
        raise RuntimeError('Missing unique blocked-official RLS injection marker')
    sql = fixture.replace(marker, MIGRATION.read_text(encoding='utf-8'))
    created = psql('postgres', command='CREATE DATABASE ' + DATABASE)
    if created.returncode:
        raise RuntimeError('A fresh local PostgreSQL fixture database is required')
    try:
        result = psql(DATABASE, sql=sql)
        if result.returncode:
            print('TEAM_SKILLS_BLOCKED_RLS_FAIL: ' + result.stderr[-2700:], file=sys.stderr)
            return 1
        print('PASS: active judge reads own private cup; blocked judge and outsider cannot')
        return 0
    finally:
        deleted = psql('postgres', command='DROP DATABASE IF EXISTS ' + DATABASE + ' WITH (FORCE)')
        if deleted.returncode:
            raise RuntimeError('Could not clean up disposable test database')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_BLOCKED_RLS_ERROR: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
