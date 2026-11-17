#!/usr/bin/env python3
"""Run actual invitation notification migration in an isolated local PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
MIGRATION=ROOT/"supabase/migrations/20261117160000_team_membership_invitation_status_notifications.sql"
FIXTURE=ROOT/"supabase/tests/team_invitation_status_notifications_isolated_contract.sql"
DB="vsp_team_invitation_notice_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    source=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_TEAM_INVITATION_NOTICE_MIGRATION"
    if source.count(marker)!=1: raise RuntimeError("Fixture marker drift")
    source=source.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode: raise RuntimeError("Fresh localhost invitation DB required")
    try:
        result=psql(DB,sql=source)
        if result.returncode:
            print("INVITATION_NOTICE_FAIL: "+result.stderr[-3200:],file=sys.stderr)
            return 1
        print("PASS: team invitation, captain acceptance/decline, expired and duplicate exclusion")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode: raise RuntimeError("Disposable invite DB cleanup failed")

if __name__=="__main__":
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("INVITATION_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
