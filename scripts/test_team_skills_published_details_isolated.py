#!/usr/bin/env python3
"""Exercise the canonical Team Skills publication RPC and RLS in local PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "supabase/migrations/20261116030000_team_skills_cup_foundation.sql"
FIXTURE = ROOT / "supabase/tests/team_skills_published_details_isolated_contract.sql"
DB = "vsp_team_skills_published_details_isolated"


def statement(source: str, begin: str, ending: str) -> str:
    if source.count(begin) != 1:
        raise RuntimeError("Canonical Team Skills source missing or ambiguous: " + begin)
    start = source.index(begin)
    stop = source.index(ending, start) + len(ending)
    return source[start:stop]


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    source = SOURCE.read_text(encoding="utf-8")
    fixture = FIXTURE.read_text(encoding="utf-8")
    originals = {
        "-- ACTUAL_TEAM_SKILLS_IS_ADMIN": statement(
            source, "create or replace function vsp_skills_private.is_admin()", "$$;"),
        "-- ACTUAL_TEAM_SKILLS_PUBLISHED_POLICY": statement(
            source, 'create policy "published_cups_or_admin"', ";"),
        "-- ACTUAL_TEAM_SKILLS_SET_STATUS": statement(
            source, "create or replace function public.team_skills_set_status(", "end $$;"),
    }
    for marker, body in originals.items():
        if fixture.count(marker) != 1:
            raise RuntimeError("Missing unique published-cup fixture marker")
        fixture = fixture.replace(marker, body)
    created = psql("postgres", command="CREATE DATABASE " + DB)
    if created.returncode:
        raise RuntimeError("Fresh local PostgreSQL database required")
    try:
        result = psql(DB, sql=fixture)
        if result.returncode:
            print("TEAM_SKILLS_PUBLISHED_DETAILS_FAILED: " + result.stderr[-3000:],
                  file=sys.stderr)
            return 1
        print("PASS: real publish RPC + RLS: draft private, player sees published, blocked admin denied, only active admin publishes once with timestamp/audit; anon denied")
        return 0
    finally:
        dropped = psql("postgres",
                       command="DROP DATABASE IF EXISTS " + DB + " WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Published-cup local database cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_PUBLISHED_DETAILS_ERROR: " + str(exc),
              file=sys.stderr)
        raise SystemExit(1)
