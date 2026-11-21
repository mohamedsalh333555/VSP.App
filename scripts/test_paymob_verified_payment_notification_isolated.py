#!/usr/bin/env python3
"""Actual Paymob receipt SQL in a fresh, strictly local PostgreSQL database."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase/migrations/20261117070000_paymob_verified_booking_payment_notification.sql"
FIXTURE=ROOT/"supabase/tests/paymob_verified_payment_notification_isolated_contract.sql"
DB="vsp_paymob_receipt_verified_isolated"
def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    sql=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_PAYMOB_NOTIFICATION_MIGRATION"
    if sql.count(marker)!=1:raise RuntimeError("Missing real source marker")
    sql=sql.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh local SQL database required")
    try:
        result=psql(DB,sql=sql)
        if result.returncode:
            print("PAYMOB_VERIFIED_RECEIPT_FAIL: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: signed+settled per-booking gross verified, canonical recipients, partial/final and replay dedup")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode:raise RuntimeError("Local test DB cleanup failed")
if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("PAYMOB_VERIFIED_RECEIPT_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
