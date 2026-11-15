#!/usr/bin/env python3
"""Run independent captain-result SQL contracts in disposable local PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CANDIDATE = ROOT / "docs/security/sql/challenge_captain_private_result_candidate.sql"
CONTRACT = ROOT / "supabase/tests/challenge_captain_private_result_contract.sql"
DB = "vsp_captain_result_contracts"

def require_isolated(env: dict[str, str]) -> None:
    if (env.get("VSP_CONTRACT_ISOLATED") != "1"
        or env.get("PGHOST") != "127.0.0.1"
        or env.get("PGPORT") != "5432"
        or env.get("PGDATABASE") != "vsp_security_contracts"):
        raise RuntimeError("Refusing non-isolated PostgreSQL target")

def psql(db: str, *, query: str | None = None, input_sql: str | None = None):
    if db not in ("postgres", DB):
        raise RuntimeError("Database target not allowlisted")
    env = {k: v for k, v in os.environ.items() if k not in (
        "PGHOST", "PGHOSTADDR", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE")}
    args = ["psql","-X","--no-psqlrc","--host=127.0.0.1","--port=5432",
            "--username=postgres","--dbname="+db,"-v","ON_ERROR_STOP=1","-q"]
    if query:
        args.extend(["-c",query])
    return subprocess.run(args,input=input_sql,text=True,capture_output=True,
                          timeout=65,env=env,check=False)

def main() -> int:
    require_isolated(dict(os.environ))
    source = CONTRACT.read_text(encoding="utf-8")
    marker = "-- INSTALL_PRIVATE_RESULTS_CANDIDATE"
    if source.count(marker) != 1:
        raise RuntimeError("Contract marker mismatch")
    source = source.replace(marker,CANDIDATE.read_text(encoding="utf-8"))
    created = psql("postgres",query=f"CREATE DATABASE {DB}")
    if created.returncode != 0:
        raise RuntimeError("Unable to create separate ephemeral SQL database")
    try:
        completed = psql(DB,input_sql="BEGIN;\n"+source+"\nROLLBACK;\n")
        if completed.returncode != 0:
            print("CAPTAIN_RESULT_SQL_CONTRACT_FAILED: "+
                  completed.stderr[-2600:],file=sys.stderr)
            return 1
        print("PASS: independent votes, mismatch, all 3 agreements, 6 disagreements, "
              "retry, audit, auth, private columns and financial invariants")
        return 0
    finally:
        dropped = psql("postgres",query=f"DROP DATABASE IF EXISTS {DB} WITH (FORCE)")
        if dropped.returncode != 0:
            raise RuntimeError("Failed to remove temporary SQL database")

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("CAPTAIN_RESULT_SQL_RUNNER_ERROR: "+str(exc),file=sys.stderr)
        raise SystemExit(1)
