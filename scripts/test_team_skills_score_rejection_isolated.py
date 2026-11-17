#!/usr/bin/env python3
"""Test reject -> audit -> correct -> approve for Team Skills on disposable SQL.

Latest source functions are extracted verbatim and assembled in a localhost
PostgreSQL fixture. Never use a hosted or non-isolated target.
"""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT = Path(__file__).resolve().parents[1]
DATABASE = "vsp_team_skills_score_rejection_isolated"
CONTRACT = ROOT / "supabase/tests/team_skills_score_rejection_isolated_contract.sql"
FOUNDATION = ROOT / "supabase/migrations/20261116030000_team_skills_cup_foundation.sql"
CORRECTION = ROOT / "supabase/migrations/20261116084000_team_skills_final_seeding_freeze.sql"
REJECTION = ROOT / "supabase/migrations/20261117020000_team_skills_reject_score_audited.sql"


def actual_function(file: Path, name: str) -> str:
    code = file.read_text(encoding="utf-8")
    marker = "create or replace function " + name + "("
    if code.count(marker) != 1:
        raise RuntimeError("Team Skills function missing or duplicated: " + name)
    start = code.index(marker)
    end = code.index("end $$;", start) + len("end $$;")
    return code[start:end]


def sql_contract() -> str:
    source = CONTRACT.read_text(encoding="utf-8")
    replacements = {
        "-- SCORE_CALCULATION_HERE": actual_function(
            FOUNDATION, "vsp_skills_private.score"),
        "-- APPROVE_SCORE_HERE": actual_function(
            FOUNDATION, "public.team_skills_approve_score"),
        "-- CORRECT_SCORE_HERE": actual_function(
            CORRECTION, "public.team_skills_correct_score"),
        "-- REJECT_SCORE_HERE": actual_function(
            REJECTION, "public.team_skills_reject_score"),
    }
    # The approver RPC is granted explicitly in its migration. All SQL
    # fixtures run under a deliberately limited authenticated role.
    replacements["-- APPROVE_SCORE_HERE"] += (
        "\ngrant execute on function public.team_skills_approve_score(uuid) "
        "to authenticated;")
    replacements["-- CORRECT_SCORE_HERE"] += (
        "\ngrant execute on function public.team_skills_correct_score("
        "uuid,numeric,text) to authenticated;")
    replacements["-- REJECT_SCORE_HERE"] += (
        "\nrevoke all on function public.team_skills_reject_score("
        "uuid,text) from public,anon,authenticated;"
        "\ngrant execute on function public.team_skills_reject_score("
        "uuid,text) to authenticated;")
    for marker, body in replacements.items():
        if source.count(marker) != 1:
            raise RuntimeError("Expected one fixture marker: " + marker)
        source = source.replace(marker, body)
    return source


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable localhost PostgreSQL required")
    try:
        result = psql(DATABASE, sql=sql_contract())
        if result.returncode:
            print("TEAM_SKILLS_REJECTION_FAILED: " + result.stderr[-3000:],
                  file=sys.stderr)
            return 1
        print("PASS: only admin rejects pending score with reason; "
              "audit once; correction returns pending; reapproval succeeds; "
              "duplicate, outsider, cancelled cup and seeded finals denied")
        return 0
    finally:
        removed = psql("postgres", command="DROP DATABASE IF EXISTS "
                       + DATABASE + " WITH (FORCE)")
        if removed.returncode:
            raise RuntimeError("Score rejection SQL fixture cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired, ValueError) as e:
        print("TEAM_SKILLS_REJECTION_ERROR: " + str(e), file=sys.stderr)
        raise SystemExit(1)
