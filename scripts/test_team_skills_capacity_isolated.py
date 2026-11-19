#!/usr/bin/env python3
"""Run the Team Skills max-team/approval authorization regression on disposable PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "supabase/tests/team_skills_capacity_isolated_contract.sql"
MIGRATION = ROOT / "supabase/migrations/20261116094000_team_skills_waitlist_promotion_capacity.sql"
DATABASE = "vsp_team_skills_capacity_isolated"


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    template = CONTRACT.read_text(encoding="utf-8")
    marker = "-- CAPACITY_MIGRATION_HERE"
    if template.count(marker) != 1:
        raise RuntimeError("Missing unique waitlist capacity migration marker")
    sql = template.replace(marker, MIGRATION.read_text(encoding="utf-8"))
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable team skills capacity database required")
    try:
        result = psql(DATABASE, sql=sql)
        if result.returncode:
            print("TEAM_SKILLS_CAPACITY_FAILED: " + result.stderr[-2200:], file=sys.stderr)
            return 1
        print("PASS: full cup denies promotion; nonadmin denied; freed slot approved; admin reject reason recorded once with inactive roster")
        return 0
    finally:
        drop = psql("postgres", command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if drop.returncode:
            raise RuntimeError("Capacity test database cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_CAPACITY_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
