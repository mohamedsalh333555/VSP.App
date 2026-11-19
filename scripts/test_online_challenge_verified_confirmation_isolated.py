#!/usr/bin/env python3
"""Use the actual signed Paymob challenge notice migration on localhost only."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
SQL=ROOT/"supabase/migrations/20261117162000_online_challenge_verified_confirmation_notifications.sql"
FIXTURE=ROOT/"supabase/tests/online_challenge_verified_confirmation_isolated_contract.sql"
DB="vsp_verified_online_challenge_notice_isolated"
def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_VERIFIED_CHALLENGE_NOTICE_MIGRATION"
    if fixture.count(marker)!=1:raise RuntimeError("Source marker drift")
    fixture=fixture.replace(marker,SQL.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh localhost test database required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("ONLINE_CHALLENGE_NOTICE_FAIL: "+result.stderr[-3400:],file=sys.stderr)
            return 1
        print("PASS: signed Paymob challenge notifies two verified captains; cancelled/unsigned matches silent")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode:raise RuntimeError("Local challenge test cleanup failed")
if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("ONLINE_CHALLENGE_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
