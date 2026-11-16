#!/usr/bin/env python3
"""Execute the real team-registration notification migration in disposable SQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=ROOT/"supabase/tests/team_skills_registration_notify_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261116085000_team_skills_registration_status_notifications.sql"
DATABASE="vsp_team_skills_notify_isolated"


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=CONTRACT.read_text(encoding="utf-8")
    marker="-- TEAM_SKILLS_NOTIFY_MIGRATION"
    if fixture.count(marker)!=1:
        raise RuntimeError("Expected exactly one notification migration marker")
    sql=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode:
        raise RuntimeError("Must create a fresh disposable notification database")
    try:
        result=psql(DATABASE,sql=sql)
        if result.returncode:
            print("TEAM_SKILLS_NOTIFY_FAIL: "+result.stderr[-2400:],file=sys.stderr)
            return 1
        print("PASS: approved/rejected/waitlist notifications reach the captain once, not other teams")
        return 0
    finally:
        deleted=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if deleted.returncode:
            raise RuntimeError("Disposable notification database cleanup failed")


if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_NOTIFY_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
