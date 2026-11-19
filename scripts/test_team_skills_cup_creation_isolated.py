#!/usr/bin/env python3
"""Verify actual Team Skills draft creation against disposable localhost PostgreSQL."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
FOUNDATION=ROOT/"supabase/migrations/20261116030000_team_skills_cup_foundation.sql"
MIGRATION=ROOT/"supabase/migrations/20261117024000_team_skills_create_cup_stadium_governorate_guard.sql"
FIXTURE=ROOT/"supabase/tests/team_skills_cup_creation_isolated_contract.sql"
DB="vsp_team_skills_cup_creation_isolated"

def source_function(source: str, signature: str, terminator: str='end $$;') -> str:
    marker="create or replace function "+signature+"("
    if source.count(marker)!=1:
        raise RuntimeError("Canonical function source missing or ambiguous: "+signature)
    start=source.index(marker)
    return source[start:source.index(terminator,start)+len(terminator)]

def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture=FIXTURE.read_text(encoding="utf-8")
    foundation=FOUNDATION.read_text(encoding="utf-8")
    source=MIGRATION.read_text(encoding="utf-8")
    pieces={
      "-- ACTUAL_TEAM_SKILLS_ADMIN_CHECK":source_function(
        foundation,"vsp_skills_private.is_admin",terminator="$$;"),
      "-- ACTUAL_TEAM_SKILLS_CREATE_CUP":source_function(
        source,"public.team_skills_create_cup")+
        "\nrevoke all on function public.team_skills_create_cup(text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text) from public,anon;\ngrant execute on function public.team_skills_create_cup(text,text,uuid,timestamptz,timestamptz,int,numeric,jsonb,text) to authenticated;",
    }
    for marker,contents in pieces.items():
        if fixture.count(marker)!=1:
            raise RuntimeError("Fixture insertion marker missing")
        fixture=fixture.replace(marker,contents)
    created=psql("postgres",command="CREATE DATABASE "+DB)
    if created.returncode:
        raise RuntimeError("Fresh disposable creation database required")
    try:
        result=psql(DB,sql=fixture)
        if result.returncode:
            print("TEAM_SKILLS_CREATION_FAILED: "+result.stderr[-3500:],file=sys.stderr)
            return 1
        print("PASS: real admin creates Aswan draft with 12 stages and one audit; player, blocked admin, anon, and Cairo stadium mismatch denied without side effects")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DB+" WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Disposable creation database cleanup failed")

if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_CREATION_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
