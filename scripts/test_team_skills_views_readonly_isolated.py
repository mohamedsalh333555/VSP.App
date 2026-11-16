#!/usr/bin/env python3
"""Least-privilege check for Team Skills invoker views in disposable PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT/'supabase/tests/team_skills_views_readonly_isolated_contract.sql'
MIGRATION = ROOT/'supabase/migrations/20261116097000_team_skills_views_select_only.sql'
DATABASE = 'vsp_team_skills_views_readonly_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    marker = '-- TEAM_SKILLS_VIEWS_READONLY_MIGRATION'
    contract = CONTRACT.read_text(encoding='utf-8')
    if contract.count(marker) != 1:
        raise RuntimeError('Missing unique view migration placeholder')
    sql = contract.replace(marker, MIGRATION.read_text(encoding='utf-8'))
    created = psql('postgres', command='CREATE DATABASE ' + DATABASE)
    if created.returncode:
        raise RuntimeError('Cannot create fresh, local-only test database')
    try:
        checked = psql(DATABASE, sql=sql)
        if checked.returncode:
            print('TEAM_SKILLS_VIEWS_READONLY_FAIL: ' + checked.stderr[-2700:],
                  file=sys.stderr)
            return 1
        print('PASS: all three views keep authenticated SELECT and deny writes/anon')
        return 0
    finally:
        dropped = psql('postgres', command='DROP DATABASE IF EXISTS ' + DATABASE + ' WITH (FORCE)')
        if dropped.returncode:
            raise RuntimeError('Disposable view test database cleanup failed')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_VIEWS_READONLY_ERROR: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
