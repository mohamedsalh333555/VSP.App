#!/usr/bin/env python3
"""Full Team Skills bracket progression against actual latest SQL functions.

Always uses a fresh disposable localhost PostgreSQL database, never hosted.
"""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"supabase/tests/team_skills_knockout_advancement_isolated_contract.sql"
GENERATOR=ROOT/"supabase/migrations/20261116084000_team_skills_final_seeding_freeze.sql"
APPROVAL=ROOT/"supabase/migrations/20261116088000_team_skills_closed_event_write_guards.sql"
DATABASE="vsp_team_skills_knockout_advancement_isolated"


def extract_function(path: Path, name: str) -> str:
    source=path.read_text(encoding="utf-8")
    marker="create or replace function "+name+"("
    if source.count(marker)!=1:
        raise RuntimeError("Missing latest canonical function: "+name)
    start=source.index(marker)
    end=source.index("end $$;",start)+len("end $$;")
    return source[start:end]


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    sql=FIXTURE.read_text(encoding="utf-8")
    replacements={
        "-- INJECT_REAL_BRACKET_GENERATOR":extract_function(
            GENERATOR,"public.team_skills_generate_knockout"),
        "-- INJECT_REAL_MATCH_APPROVAL":extract_function(
            APPROVAL,"public.team_skills_approve_knockout_match")
    }
    for marker,actual in replacements.items():
        if sql.count(marker)!=1:
            raise RuntimeError("Expected exactly one source insertion marker "+marker)
        sql=sql.replace(marker,actual)
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable localhost PostgreSQL required")
    try:
        result=psql(DATABASE,sql=sql)
        if result.returncode:
            print("TEAM_SKILLS_ADVANCEMENT_FAIL: "+result.stderr[-2700:],file=sys.stderr)
            return 1
        print("PASS: actual knockout RPC promotes both semifinals, selects final champion, denies ties, repeat, outsider and cancelled cup")
        return 0
    finally:
        cleaned=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if cleaned.returncode:
            raise RuntimeError("Temporary knockout SQL database cleanup failed")


if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired,ValueError) as e:
        print("TEAM_SKILLS_ADVANCEMENT_ERROR: "+str(e),file=sys.stderr)
        raise SystemExit(1)
