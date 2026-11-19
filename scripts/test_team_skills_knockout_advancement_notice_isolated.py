#!/usr/bin/env python3
"""Test real knockout advancement notification trigger in disposable PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/team_skills_knockout_advancement_notice_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117062000_team_skills_knockout_approved_advancement_notification.sql"
DB="vsp_knockout_advancement_notice_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_KNOCKOUT_ADVANCEMENT_NOTICE"
    if fixture.count(marker)!=1: raise RuntimeError("Missing unique knockout notice marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode: raise RuntimeError("Fresh disposable knockout DB required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("KNOCKOUT_ADVANCEMENT_NOTICE_FAIL: "+result.stderr[-3000:],file=sys.stderr)
            return 1
        print("PASS: only officially approved knockout winners advance once; cancelled/draft never notified")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode: raise RuntimeError("Disposable knockout DB cleanup failed")

if __name__=="__main__":
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("KNOCKOUT_ADVANCEMENT_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
