#!/usr/bin/env python3
"""Rebuild the colliding matchup fee functions in a disposable local database."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "supabase/migrations/20260926060000_fix_matchup_extra_team_fee_column_reference.sql"
CURRENT = ROOT / "supabase/migrations/20260926060000_remove_legacy_matchup_extra_team_fee.sql"
CONTRACT = ROOT / "supabase/tests/matchup_fee_migration_rebuild_contract.sql"
DATABASE = "vsp_matchup_fee_rebuild_contracts"


def reject_nonlocal_targets(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("Isolated contract opt-in required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Refusing non-loopback SQL target")
    if env.get("PGPORT") != "5432" or env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Refusing non-contract SQL target")


def psql(dbname: str, sql: str | None = None, command: str | None = None) -> subprocess.CompletedProcess[str]:
    env = {k: v for k, v in os.environ.items() if k not in {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }}
    args = ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1", "--port=5432",
            "--username=postgres", "--dbname=" + dbname, "-v", "ON_ERROR_STOP=1", "-q"]
    if command is not None:
        args += ["-c", command]
    return subprocess.run(args, input=sql, text=True, capture_output=True, env=env, timeout=60)


def contract_sql() -> str:
    sql = CONTRACT.read_text(encoding="utf-8")
    for marker, path in (("-- LEGACY_MIGRATION_HERE", LEGACY),
                         ("-- CURRENT_MIGRATION_HERE", CURRENT),
                         ("-- CURRENT_REPLAY_HERE", CURRENT),
                         ("-- CURRENT_REPLAY_AGAIN_HERE", CURRENT)):
        if sql.count(marker) != 1:
            raise RuntimeError("Contract missing unique marker: " + marker)
        sql = sql.replace(marker, path.read_text(encoding="utf-8"))
    return sql


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    sql = contract_sql()
    create = psql("postgres", command="CREATE DATABASE " + DATABASE)
    if create.returncode != 0:
        raise RuntimeError("Fresh disposable database required: " + create.stderr[-500:])
    try:
        result = psql(DATABASE, sql="BEGIN;\n" + sql + "\nROLLBACK;\n")
        if result.returncode:
            print("MATCHUP_FEE_REBUILD_FAILED: " + result.stderr[-3000:], file=sys.stderr)
            return 1
        print("PASS: legacy-to-five-team rebuild, replay, and transactional rollback")
        return 0
    finally:
        drop = psql("postgres", command="DROP DATABASE IF EXISTS " + DATABASE + " WITH (FORCE)")
        if drop.returncode:
            raise RuntimeError("Could not remove disposable fee-test database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("MATCHUP_FEE_REBUILD_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
