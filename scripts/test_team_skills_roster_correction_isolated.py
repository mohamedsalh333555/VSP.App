#!/usr/bin/env python3
"""Test the current captain-only roster correction RPC on disposable PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'supabase/migrations/20261116106000_team_skills_preapproval_roster_corrections.sql'
CONTRACT = ROOT / 'supabase/tests/team_skills_roster_correction_isolated_contract.sql'
DATABASE = 'vsp_team_skills_roster_correction_isolated'


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    marker = '-- TEAM_SKILLS_PENDING_ROSTER_CORRECTION_MIGRATION'
    fixture = CONTRACT.read_text(encoding='utf-8')
    if fixture.count(marker) != 1:
        raise RuntimeError('Missing unique roster-correction migration marker')
    sql = fixture.replace(marker, MIGRATION.read_text(encoding='utf-8'))
    created = psql('postgres', command='CREATE DATABASE ' + DATABASE)
    if created.returncode:
        raise RuntimeError('Fresh local-only test database is required')
    try:
        result = psql(DATABASE, sql=sql)
        if result.returncode:
            print('TEAM_SKILLS_ROSTER_CORRECTION_FAIL: ' +
                  result.stderr[-2600:], file=sys.stderr)
            return 1
        print('PASS: captain correction, 5 active players, blocker and approval denial')
        return 0
    finally:
        dropped = psql('postgres', command='DROP DATABASE IF EXISTS ' +
                       DATABASE + ' WITH (FORCE)')
        if dropped.returncode:
            raise RuntimeError('Disposable roster-correction database cleanup failed')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print('TEAM_SKILLS_ROSTER_CORRECTION_ERROR: ' + str(exc),
              file=sys.stderr)
        raise SystemExit(1)
