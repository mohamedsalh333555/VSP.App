#!/usr/bin/env python3
"""Local-only negative/positive SQL test of legacy reject_join_request."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "supabase/tests/baseline_reject_join_request_staging_20261113.sql"
CANDIDATE = ROOT / "supabase/migrations/20261113172000_guard_reject_join_request_authorization.sql"
CONTRACT = ROOT / "supabase/tests/reject_join_request_isolated_contract.sql"

def isolated_psql_environment(env: dict[str, str]) -> dict[str, str]:
    """Strip libpq redirects; the subprocess must use its explicit loopback CLI target."""
    unsafe = {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }
    return {key: value for key, value in env.items() if key not in unsafe}



def only_disposable_local_pg(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("Explicit isolated contract flag required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Refusing a non-local PostgreSQL host")
    if env.get("PGPORT") != "5432" or env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Refusing wrong PostgreSQL port or database")


def extract_function(path: Path) -> str:
    sql = path.read_text(encoding="utf-8")
    begin = sql.lower().find(
        "create or replace function public.reject_join_request("
    )
    end = sql.find("$function$;", begin)
    if begin < 0 or end < 0:
        raise RuntimeError("Unexpected reject_join_request definition")
    return sql[begin:end + len("$function$;")]


def psql(dbname: str, *, content: str | None = None, command: str | None = None):
    argv = ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1", "--port=5432",
            "--username=postgres", "--dbname=" + dbname,
            "-v", "ON_ERROR_STOP=1", "-q"]
    if command is not None:
        argv.extend(["-c", command])
    return subprocess.run(argv, input=content, text=True, capture_output=True,
                          env=isolated_psql_environment(dict(os.environ)), timeout=60)


def main() -> int:
    only_disposable_local_pg(dict(os.environ))
    test_db = "vsp_reject_contracts"
    create = psql("postgres", command="CREATE DATABASE " + test_db)
    if create.returncode != 0:
        raise RuntimeError("Cannot create isolated SQL database")
    contract = CONTRACT.read_text(encoding="utf-8")
    placeholder = "-- REJECT_JOIN_FUNCTION_HERE"
    if contract.count(placeholder) != 1:
        raise RuntimeError("Invalid SQL contract placeholder")
    try:
        baseline = psql(test_db, content=(
            "BEGIN;\n" + contract.replace(placeholder, extract_function(BASELINE))
            + "\nROLLBACK;\n"
        ))
        if baseline.returncode == 0 or "FAIL: foreign caller with NULL owner" not in baseline.stderr:
            print("BASELINE_REJECT_BYPASS_NOT_REPRODUCED", file=sys.stderr)
            return 1
        print("PASS: original reject RPC fails unauthorized-null-owner negative control")
        fixed = psql(test_db, content=(
            "BEGIN;\n" + contract.replace(placeholder, extract_function(CANDIDATE))
            + "\nROLLBACK;\n"
        ))
        if fixed.returncode != 0:
            print("PATCHED_REJECT_CONTRACT_FAILED:", fixed.stderr[-1500:], file=sys.stderr)
            return 1
        print("PASS: corrected reject RPC authorizes host and protects pending request")
        return 0
    finally:
        cleanup = psql("postgres", command="DROP DATABASE IF EXISTS " + test_db + " WITH (FORCE)")
        if cleanup.returncode != 0:
            raise RuntimeError("Unable to clean isolated database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("REJECT_ISOLATED_CONTRACT_ERROR:", str(exc), file=sys.stderr)
        raise SystemExit(1)
