#!/usr/bin/env python3
"""Test Team Skills publication, live registration and closure against real SQL.

Strictly a fresh disposable localhost PostgreSQL DB; no hosted mutations.
"""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "supabase/tests/team_skills_registration_lifecycle_isolated_contract.sql"
FOUNDATION = ROOT / "supabase/migrations/20261116030000_team_skills_cup_foundation.sql"
REGISTRATION = ROOT / "supabase/migrations/20261117023000_team_skills_registration_governorate_guard.sql"
DB = "vsp_team_skills_registration_lifecycle_isolated"


def extract(path: Path, name: str) -> str:
    sql = path.read_text(encoding="utf-8")
    start_signature = "create or replace function " + name + "("
    if sql.count(start_signature) != 1:
        raise RuntimeError("Canonical Team Skills RPC absent: " + name)
    start = sql.index(start_signature)
    stop = sql.index("end $$;", start) + len("end $$;")
    return sql[start:stop]


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    script = FIXTURE.read_text(encoding="utf-8")
    for marker, body in {
        "-- REAL_TEAM_SKILLS_STATUS_FUNCTION": extract(
            FOUNDATION, "public.team_skills_set_status"),
        "-- REAL_TEAM_SKILLS_REGISTRATION_FUNCTION": extract(
            REGISTRATION, "public.team_skills_register"),
    }.items():
        if script.count(marker) != 1:
            raise RuntimeError("Unique lifecycle insertion marker missing")
        script = script.replace(marker, body)
    created = psql("postgres", command="CREATE DATABASE " + DB)
    if created.returncode:
        raise RuntimeError("Fresh disposable local PostgreSQL DB required")
    try:
        result = psql(DB, sql=script)
        if result.returncode:
            print("TEAM_SKILLS_LIFECYCLE_FAILED: " + result.stderr[-2800:],
                  file=sys.stderr)
            return 1
        print("PASS: admin publishes draft with timestamp and audit; captain enrolls real five-player roster; live status closes enrollment without deleting accepted signup; outsider, reopen and skip state denied")
        return 0
    finally:
        removed = psql("postgres", command="DROP DATABASE IF EXISTS " + DB + " WITH (FORCE)")
        if removed.returncode:
            raise RuntimeError("Lifecycle local DB cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_LIFECYCLE_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
