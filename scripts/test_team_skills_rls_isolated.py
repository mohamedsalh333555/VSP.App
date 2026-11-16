#!/usr/bin/env python3
"""Enforce Team Skills RLS in a disposable local PostgreSQL database."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261116080000_team_skills_fix_scoped_rls_policies.sql"
CONTRACT = ROOT / "supabase/tests/team_skills_rls_isolated_contract.sql"
DATABASE = "vsp_team_skills_rls_isolated"


def reject_nonlocal_targets(env: dict[str, str]) -> None:
    if (env.get("VSP_CONTRACT_ISOLATED") != "1"
            or env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1")
            or env.get("PGPORT") != "5432"
            or env.get("PGDATABASE") != "vsp_security_contracts"):
        raise RuntimeError("Refusing a non-isolated PostgreSQL target")


def psql(db: str, sql: str | None = None, command: str | None = None):
    env = {key: value for key, value in os.environ.items() if key not in {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }}
    argv = ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
            "--port=5432", "--username=postgres", "--dbname=" + db,
            "-v", "ON_ERROR_STOP=1", "-q"]
    if command is not None:
        argv += ["-c", command]
    return subprocess.run(argv, input=sql, text=True, capture_output=True,
                          env=env, timeout=60)


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture = CONTRACT.read_text(encoding="utf-8")
    marker = "-- TEAM_SKILLS_RLS_MIGRATION"
    if fixture.count(marker) != 1:
        raise RuntimeError("Missing unique RLS migration marker")
    migration = MIGRATION.read_text(encoding="utf-8")
    sql = fixture.replace(marker, migration)
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Could not create fresh ephemeral SQL test database")
    try:
        result = psql(DATABASE, sql=sql)
        if result.returncode:
            print("TEAM_SKILLS_RLS_FAILED: " + result.stderr[-2700:], file=sys.stderr)
            return 1
        print("PASS: authentic member sees one pending registration; one assigned judge's"
              " private score and keeper trial; outsider sees zero")
        return 0
    finally:
        dropped = psql("postgres",
                       command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Ephemeral team skills database cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("TEAM_SKILLS_RLS_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
