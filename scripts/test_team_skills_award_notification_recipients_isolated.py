#!/usr/bin/env python3
"""Verify source-controlled Team Skills award notifications in disposable Postgres."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/team_skills_award_notification_recipients_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117033000_team_skills_award_notification_active_roster_guard.sql"
DB="vsp_team_skills_award_notice_recipients_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_TEAM_SKILLS_AWARD_NOTICE_MIGRATION"
    if fixture.count(marker)!=1: raise RuntimeError("Missing award source marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode: raise RuntimeError("Could not create local test database")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("TEAM_SKILLS_AWARD_RECIPIENT_FAIL: "+result.stderr[-2800:],file=sys.stderr)
            return 1
        print("PASS: captain + active approved roster notified once, inactive/withdrawn/other cup excluded")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode: raise RuntimeError("Local test DB cleanup failed")

if __name__=="__main__":
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_AWARD_RECIPIENT_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
