#!/usr/bin/env python3
"""Test real Team Skills cash/waiver check-in RPCs on isolated local PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / 'supabase/migrations/20261116070000_team_skills_hospitality_checkin.sql'
HARDENED = ROOT / 'supabase/migrations/20261116091000_team_skills_checkin_closed_status_first.sql'
FIXTURE = ROOT / 'supabase/tests/team_skills_cash_checkin_isolated_contract.sql'
DATABASE = 'vsp_team_skills_cash_checkin_isolated'


def real_function(source: str, name: str) -> str:
    marker = 'create or replace function public.' + name + '('
    if source.count(marker) != 1:
        raise RuntimeError('Expected unique deployed RPC source: ' + name)
    start = source.index(marker)
    end = source.index('end $$;', start)
    if end < 0:
        raise RuntimeError('RPC source end missing: ' + name)
    return source[start:end + len('end $$;')]


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    base = ORIGINAL.read_text(encoding='utf-8')
    latest = HARDENED.read_text(encoding='utf-8')
    sql = FIXTURE.read_text(encoding='utf-8')
    marker = '-- CHECKIN_AND_RECEIPT_REAL_FUNCTIONS'
    if sql.count(marker) != 1:
        raise RuntimeError('Missing unique check-in RPC injection marker')
    sql = sql.replace(marker, '\n'.join([
        real_function(base, 'team_skills_confirm_hospitality'),
        real_function(latest, 'team_skills_check_in'),
    ]))
    created = psql('postgres', command='CREATE DATABASE ' + DATABASE)
    if created.returncode:
        raise RuntimeError('Disposable PostgreSQL test database could not be created')
    try:
        result = psql(DATABASE, sql=sql)
        if result.returncode:
            print('TEAM_SKILLS_CASH_CHECKIN_FAIL: ' + result.stderr[-2700:], file=sys.stderr)
            return 1
        print('PASS: no unpaid check-in, audited cash/waiver, zero-fee teams, idempotent entry')
        return 0
    finally:
        deleted = psql('postgres', command='DROP DATABASE IF EXISTS ' + DATABASE + ' WITH (FORCE)')
        if deleted.returncode:
            raise RuntimeError('Could not clean up disposable check-in database')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_CASH_CHECKIN_ERROR: ' + str(exc), file=sys.stderr)
        raise SystemExit(1)
