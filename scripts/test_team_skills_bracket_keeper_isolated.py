#!/usr/bin/env python3
"""Verify knockout placeholder and keeper tie constraints on local PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
from test_team_skills_rls_isolated import psql, reject_nonlocal_targets

ROOT=Path(__file__).resolve().parents[1]
SQL=ROOT/"supabase/tests/team_skills_bracket_keeper_guards_isolated.sql"
KNOCKOUT=ROOT/"supabase/migrations/20261116082000_team_skills_knockout_future_round_slots.sql"
KEEPER=ROOT/"supabase/migrations/20261116083000_team_skills_goalkeeper_award_tie_guard.sql"
DATABASE="vsp_team_skills_bracket_keeper_isolated"


def main():
    reject_nonlocal_targets(dict(os.environ))
    contract=SQL.read_text(encoding="utf-8")
    for marker,file in [
        ("-- KNOCKOUT_FIX_HERE",KNOCKOUT),
        ("-- KEEPER_FIX_HERE",KEEPER),
    ]:
        if contract.count(marker)!=1:
            raise RuntimeError("Expected exactly one "+marker)
        contract=contract.replace(marker,file.read_text(encoding="utf-8"))
    created=psql("postgres",command="CREATE DATABASE "+DATABASE)
    if created.returncode:
        raise RuntimeError("Could not create disposable bracket/keeper test database")
    try:
        result=psql(DATABASE,sql=contract)
        if result.returncode:
            print("TEAM_SKILLS_BRACKET_KEEPER_FAIL: "+result.stderr[-2600:],file=sys.stderr)
            return 1
        print("PASS: unresolved knockout rounds and objective goalkeeper tie approvals")
        return 0
    finally:
        dropped=psql("postgres",command="DROP DATABASE IF EXISTS "+DATABASE+" WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Disposable database cleanup failed")


if __name__=="__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError,OSError,subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_BRACKET_KEEPER_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
