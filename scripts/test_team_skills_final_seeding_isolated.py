#!/usr/bin/env python3
"""Verify Team Skills final bracket seed and score immutability on local SQL.

Uses only a freshly created disposable PostgreSQL on localhost and extracts
the actual functions/triggers from the migration under test.
"""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "supabase/tests/team_skills_final_seeding_isolated_contract.sql"
MIGRATION = ROOT / "supabase/migrations/20261116084000_team_skills_final_seeding_freeze.sql"
DATABASE = "vsp_team_skills_final_seed_isolated"


def actual_sql() -> str:
    source = MIGRATION.read_text(encoding="utf-8")
    blocks = []
    for name in (
        "public.team_skills_generate_knockout",
        "vsp_skills_private.guard_score_after_seeding",
    ):
        marker = "create or replace function " + name + "("
        if source.count(marker) != 1:
            raise RuntimeError("Expected exactly one migration function: " + name)
        start = source.index(marker)
        end = source.index("end $$;", start) + len("end $$;")
        blocks.append(source[start:end])
    trigger_marker = "drop trigger if exists team_skills_freeze_score_after_seed"
    if source.count(trigger_marker) != 1:
        raise RuntimeError("Missing unique score-freeze trigger")
    blocks.append(source[source.index(trigger_marker):])
    fixture = CONTRACT.read_text(encoding="utf-8")
    marker = "-- FINAL_SEEDING_FUNCTIONS_HERE"
    if fixture.count(marker) != 1:
        raise RuntimeError("Expected one final-seeding injection marker")
    return fixture.replace(marker, "\n".join(blocks))


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    script = actual_sql()
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable SQL database required")
    try:
        result = psql(DATABASE, sql=script)
        if result.returncode:
            print("TEAM_SKILLS_FINAL_SEED_FAIL: " + result.stderr[-2600:], file=sys.stderr)
            return 1
        print("PASS: incomplete stages cannot seed; complete stages seed; existing scores cannot change")
        return 0
    finally:
        dropped = psql("postgres", command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Cannot clean up isolated final-seeding database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired, ValueError) as exc:
        print("TEAM_SKILLS_FINAL_SEED_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
