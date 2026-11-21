#!/usr/bin/env python3
"""Exercise actual notification update trigger as separate PostgreSQL roles."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql,reject_nonlocal_targets
ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/notifications_read_flag_only_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261117073000_notifications_client_edit_read_flag_only.sql"
DB="vsp_notification_client_read_flag_isolated"
def main()->int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    marker="-- ACTUAL_NOTIFICATION_READ_FLAG_GUARD"
    if fixture.count(marker)!=1:raise RuntimeError("Missing source marker")
    fixture=fixture.replace(marker,MIGRATION.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:raise RuntimeError("Fresh isolated SQL DB required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("NOTIFICATION_READ_FLAG_FAIL: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: authenticated users may change only own is_read, never event/recipient/booking content")
        return 0
    finally:
        removed=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if removed.returncode:raise RuntimeError("Cannot clean up read-only notification DB")
if __name__=="__main__":
    try:raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("NOTIFICATION_READ_FLAG_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
