#!/usr/bin/env python3
"""Exercise real SQL stage approval notifications in isolated PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/team_skills_approved_score_notice_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117061000_team_skills_approved_phase_score_notification.sql"
DB="vsp_skills_approved_score_notice_isolated"

def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_TEAM_SKILLS_SCORE_NOTIFICATION_MIGRATION"
    if fixture.count(marker)!=1: raise RuntimeError("Missing unique approved-score notice marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode: raise RuntimeError("Fresh local score-notice DB required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("SCORE_NOTICE_FAIL: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: only server-approved scores from live cups reach their captains, once per score")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode: raise RuntimeError("Disposable score-notice database cleanup failed")

if __name__=="__main__":
    try: raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("SCORE_NOTICE_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
