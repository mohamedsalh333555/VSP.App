#!/usr/bin/env python3
"""Test real booking-cancellation receipt in disposable PostgreSQL only."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/booking_cancellation_notification_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117063000_booking_cancellation_notification_authoritative.sql"
DB="vsp_booking_cancellation_notice_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_BOOKING_CANCELLATION_MIGRATION"
    if fixture.count(marker)!=1:raise RuntimeError("Missing cancellation notice marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh isolated cancellation DB required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("BOOKING_CANCELLATION_NOTICE_FAIL: "+result.stderr[-3200:],file=sys.stderr)
            return 1
        print("PASS: only actual cancellation sends private one-time owner/booker notices, never refund-success claims")
        return 0
    finally:
        deleted=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if deleted.returncode:raise RuntimeError("Local cancellation DB cleanup failed")

if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("BOOKING_CANCELLATION_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
