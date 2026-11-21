#!/usr/bin/env python3
"""Use the actual cash-booking notice migration against a disposable database."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/cash_booking_confirmed_notification_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117060000_cash_booking_confirmed_notification_server_guard.sql"
DATABASE="vsp_cash_booking_notice_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_CASH_BOOKING_MIGRATION"
    if fixture.count(marker)!=1: raise RuntimeError("Missing unique cash notice marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode: raise RuntimeError("Disposable cash booking test DB must be fresh")
    try:
        result=psql(DATABASE,sql=fixture)
        if result.returncode:
            print("CASH_BOOKING_NOTICE_FAIL: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: cash INSERT and UPDATE confirmation, owner/captain authority, dedup and cancellation silence")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if dropped.returncode: raise RuntimeError("Disposable DB cleanup failed")

if __name__=="__main__":
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("CASH_BOOKING_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
