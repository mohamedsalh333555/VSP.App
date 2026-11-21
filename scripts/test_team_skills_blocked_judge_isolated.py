#!/usr/bin/env python3
"""Run assigned/blocked/organizer score-write guards on disposable PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
SQL=ROOT/"supabase/tests/team_skills_blocked_judge_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261116087000_team_skills_revoke_official.sql"
DATABASE="vsp_skills_judge_eligibility_isolated"


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    source=MIGRATION.read_text(encoding="utf-8")
    fixture=SQL.read_text(encoding="utf-8")
    marker="-- BLOCKED_JUDGE_FUNCTIONS_HERE"
    if fixture.count(marker)!=1:
        raise RuntimeError("Missing unique blocked-judge migration marker")
    script=fixture.replace(marker,source)
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable judge SQL database required")
    try:
        result=psql(DATABASE,sql=script)
        if result.returncode:
            print("TEAM_SKILLS_JUDGE_SECURITY_FAIL: "+result.stderr[-2600:],file=sys.stderr)
            return 1
        print("PASS: blocked judge denied, active assigned judge accepted, organizer write denied")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Disposable judge SQL database cleanup failed")


if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_JUDGE_SECURITY_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
