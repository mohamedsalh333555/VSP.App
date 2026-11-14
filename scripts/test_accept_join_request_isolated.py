#!/usr/bin/env python3
"""Negative-vs-positive SQL guard in disposable local CI PostgreSQL only."""
from __future__ import annotations
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "supabase/tests/baseline_accept_join_request_staging_20261113.sql"
CANDIDATE = ROOT / "supabase/migrations/20261113171000_guard_open_join_acceptance_consent.sql"
CONTRACT = ROOT / "supabase/tests/accept_join_request_isolated_contract.sql"

def isolated_psql_environment(env: dict[str, str]) -> dict[str, str]:
    """Strip libpq redirects; the subprocess must use its explicit loopback CLI target."""
    unsafe = {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }
    return {key: value for key, value in env.items() if key not in unsafe}



def reject_nonlocal_targets(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("Isolated contract consent required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Refusing any non-loopback SQL server")
    if env.get("PGPORT") != "5432":
        raise RuntimeError("Unexpected SQL port")
    if env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Only ephemeral security contract DB accepted")


def extract_function(path: Path) -> str:
    sql = path.read_text(encoding="utf-8")
    begin = sql.lower().find(
        "create or replace function public.accept_join_request("
    )
    end = sql.find("$function$;", begin)
    if begin < 0 or end < 0:
        raise RuntimeError("Missing accept_join_request function delimiters")
    return sql[begin:end + len("$function$;")]


def run_psql(dbname: str, sql: str | None = None, command: str | None = None):
    argv = ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1", "--port=5432",
            "--username=postgres", "--dbname=" + dbname,
            "-v", "ON_ERROR_STOP=1", "-q"]
    if command is not None:
        argv.extend(["-c", command])
    return subprocess.run(argv, input=sql, text=True, capture_output=True,
                          env=isolated_psql_environment(dict(os.environ)), timeout=60)


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    dbname = "vsp_join_contracts"
    create = run_psql("postgres", command="CREATE DATABASE " + dbname)
    if create.returncode != 0:
        raise RuntimeError("Cannot create disposable join-test database")
    contract = CONTRACT.read_text(encoding="utf-8")
    tag = "-- ACCEPT_JOIN_FUNCTION_HERE"
    if contract.count(tag) != 1:
        raise RuntimeError("Invalid contract template")
    try:
        original = run_psql(
            dbname, "BEGIN;\n" + contract.replace(tag, extract_function(BASELINE)) + "\nROLLBACK;\n"
        )
        if original.returncode == 0 or "FAIL: no pending consent" not in original.stderr:
            print("BASELINE_JOIN_BYPASS_NOT_REPRODUCED", file=sys.stderr)
            return 1
        print("PASS: deployed baseline fails no-consent join test")
        fixed = run_psql(
            dbname, "BEGIN;\n" + contract.replace(tag, extract_function(CANDIDATE)) + "\nROLLBACK;\n"
        )
        if fixed.returncode != 0:
            print("JOIN_SECURITY_FIX_FAILED:", fixed.stderr[-1600:], file=sys.stderr)
            return 1
        print("PASS: patched join RPC enforces consent, ownership, capacity and idempotency")
        return 0
    finally:
        drop = run_psql("postgres", command="DROP DATABASE IF EXISTS " + dbname + " WITH (FORCE)")
        if drop.returncode != 0:
            raise RuntimeError("Failed to remove disposable join-test database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("JOIN_CONTRACT_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
