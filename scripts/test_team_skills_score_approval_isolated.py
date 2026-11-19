#!/usr/bin/env python3
"""Use current PostgreSQL approval RPC in disposable localhost SQL only.

Covers authorization, successful approval, audit trace and duplicate denial.
These role-claim transactions do NOT replace separate signed-in JWT E2E.
"""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
CONTRACT=ROOT/"supabase/tests/team_skills_score_approval_isolated_contract.sql"
MIGRATION=ROOT/"supabase/migrations/20261116030000_team_skills_cup_foundation.sql"
DATABASE="vsp_team_skills_score_approval_isolated"


def actual_sql() -> str:
    migration=MIGRATION.read_text(encoding="utf-8")
    function="create or replace function public.team_skills_approve_score("
    grant="grant execute on function public.team_skills_approve_score(uuid) to authenticated;"
    if migration.count(function)!=1 or migration.count(grant)!=1:
        raise RuntimeError("Score approval migration signature drift")
    start=migration.index(function)
    stop=migration.index(grant,start)+len(grant)
    fixture=CONTRACT.read_text(encoding="utf-8")
    marker="-- ACTUAL_TEAM_SKILLS_APPROVE_SCORE_FUNCTION_HERE"
    if fixture.count(marker)!=1:
        raise RuntimeError("Unique score approval fixture marker missing")
    view="create or replace view public.team_skills_leaderboard "
    view_grant="grant select on public.team_skills_leaderboard to authenticated;"
    if migration.count(view)!=1 or migration.count(view_grant)!=1:
        raise RuntimeError("Canonical leaderboard view signature drift")
    view_start=migration.index(view)
    view_stop=migration.index(view_grant,view_start)+len(view_grant)
    view_marker="-- ACTUAL_TEAM_SKILLS_LEADERBOARD_VIEW_HERE"
    if fixture.count(view_marker)!=1:
        raise RuntimeError("Unique leaderboard view fixture marker missing")
    return fixture.replace(view_marker,migration[view_start:view_stop]).replace(
        marker,migration[start:stop])


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode:
        raise RuntimeError("A fresh disposable localhost database is required")
    try:
        result=psql(DATABASE,sql=actual_sql())
        if result.returncode:
            print("TEAM_SKILLS_SCORE_APPROVAL_FAIL: "+result.stderr[-3000:],
                  file=sys.stderr)
            return 1
        print("PASS: pending result excluded from leaderboard; admin approves exact score; standings update once; outsider and duplicate denied; audit once")
        return 0
    finally:
        removed=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if removed.returncode:
            raise RuntimeError("Temporary score approval database cleanup failed")


if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired,ValueError) as exc:
        print("TEAM_SKILLS_SCORE_APPROVAL_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
