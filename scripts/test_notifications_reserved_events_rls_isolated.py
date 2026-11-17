#!/usr/bin/env python3
"""Check reserved notification receipts against actual RLS in local PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
SQL=ROOT/"supabase/migrations/20261117071000_notifications_reserved_financial_events_rls.sql"
FIXTURE=ROOT/"supabase/tests/notifications_reserved_events_rls_isolated_contract.sql"
DB="vsp_notifications_reserved_events_isolated"
def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    s=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_RESERVED_EVENT_RLS_MIGRATION"
    if s.count(marker)!=1:raise RuntimeError("Missing RLS source marker")
    s=s.replace(marker,SQL.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh isolated notification RLS database required")
    try:
        result=psql(DB,sql=s)
        if result.returncode:
            print("RESERVED_NOTIFICATION_RLS_FAIL: "+result.stderr[-3400:],file=sys.stderr)
            return 1
        print("PASS: generic self-notification allowed; user fake Paymob/refund/Team Skills notices denied")
        return 0
    finally:
        removed=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if removed.returncode:raise RuntimeError("Test notification database cleanup failed")
if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("RESERVED_NOTIFICATION_RLS_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
