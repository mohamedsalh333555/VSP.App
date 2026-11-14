#!/usr/bin/env python3
"""Exercise the member-only roster RPC against a disposable local PostgreSQL DB."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261114212217_fix_team_roster_order.sql"
CONTRACT = ROOT / "supabase/tests/team_roster_order_isolated_contract.sql"
DATABASE = "vsp_roster_order_contracts"


def reject_nonlocal_targets(env: dict[str, str]) -> None:
    if (env.get("VSP_CONTRACT_ISOLATED") != "1"
            or env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1")
            or env.get("PGPORT") != "5432"
            or env.get("PGDATABASE") != "vsp_security_contracts"):
        raise RuntimeError("Refusing non-isolated PostgreSQL target")


def psql(database: str, sql: str | None = None, command: str | None = None):
    env = {key: value for key, value in os.environ.items() if key not in {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }}
    argv = ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1", "--port=5432",
            "--username=postgres", "--dbname=" + database, "-v", "ON_ERROR_STOP=1", "-q"]
    if command is not None:
        argv += ["-c", command]
    return subprocess.run(argv, input=sql, text=True, capture_output=True, env=env, timeout=60)


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    fixture = CONTRACT.read_text(encoding="utf-8")
    marker = "-- ROSTER_FUNCTION_HERE"
    if fixture.count(marker) != 1:
        raise RuntimeError("Missing unique roster migration marker")
    sql = fixture.replace(marker, MIGRATION.read_text(encoding="utf-8"))
    created = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if created.returncode:
        raise RuntimeError("Fresh disposable roster database required")
    try:
        result = psql(DATABASE, sql="BEGIN;\n" + sql + "\nROLLBACK;\n")
        if result.returncode:
            print("ROSTER_CONTRACT_FAILED: " + result.stderr[-2300:], file=sys.stderr)
            return 1
        print("PASS: roster order, member/admin access and outsider/anon denial")
        return 0
    finally:
        dropped = psql("postgres", command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if dropped.returncode:
            raise RuntimeError("Disposable roster database cleanup failed")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("ROSTER_CONTRACT_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
