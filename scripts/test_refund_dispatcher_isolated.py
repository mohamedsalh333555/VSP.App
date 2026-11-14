#!/usr/bin/env python3
"""SQL-only, rollback-safe verification for the refund dispatcher.

Never connects to staging, production, Supabase APIs, or Paymob.
"""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/20261113160000_guard_refund_dispatcher_project_isolation.sql"
CONTRACT = ROOT / "supabase/tests/refund_dispatcher_isolated_contract.sql"

def isolated_psql_environment(env: dict[str, str]) -> dict[str, str]:
    """Strip libpq redirects; the subprocess must use its explicit loopback CLI target."""
    unsafe = {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }
    return {key: value for key, value in env.items() if key not in unsafe}

def contract_psql_args(database: str) -> list[str]:
    """Always use a numeric local host, fixed port and ephemeral fixture owner."""
    if database not in ("postgres", "vsp_refund_contracts"):
        raise RuntimeError("Unexpected isolated SQL database")
    return ["psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
            "--port=5432", "--username=postgres", "--dbname=" + database,
            "-v", "ON_ERROR_STOP=1", "-q"]



def verify_local_fixture_target(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("VSP_CONTRACT_ISOLATED=1 is required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Refusing any remote database host")
    if env.get("PGPORT") != "5432":
        raise RuntimeError("Refusing unexpected database port")
    if env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Refusing any non-ephemeral database")


def get_dispatcher_definition() -> str:
    content = MIGRATION.read_text(encoding="utf-8")
    begin = content.lower().find(
        "create or replace function public.reconcile_cancellation_refund_queue()"
    )
    if begin < 0:
        raise RuntimeError("Missing refund dispatcher")
    end_marker = "$function$;"
    end = content.find(end_marker, begin)
    if end < 0:
        raise RuntimeError("Missing refund dispatcher terminator")
    return content[begin:end + len(end_marker)]


def main() -> int:
    verify_local_fixture_target(dict(os.environ))
    fixture = CONTRACT.read_text(encoding="utf-8")
    placeholder = "-- VALIDATOR_IMPLEMENTATION_HERE"
    if fixture.count(placeholder) != 1:
        raise RuntimeError("Unexpected contract placeholder")
    fixture = fixture.replace(placeholder, get_dispatcher_definition())
    # The earlier account security suite intentionally leaves many public
    # fixture relations in the CI cluster. A separate, disposable database
    # avoids clashing with those tables (and cannot change their data).
    isolated_db = "vsp_refund_contracts"
    create = subprocess.run(
        contract_psql_args("postgres") + ["-c", f"CREATE DATABASE {isolated_db}"],
        text=True, capture_output=True, timeout=20, check=False,
        env=isolated_psql_environment(dict(os.environ)),
    )
    if create.returncode != 0:
        print("REFUND_TEST_DATABASE_CREATION_FAILED", file=sys.stderr)
        return 1
    try:
        completed = subprocess.run(
            contract_psql_args(isolated_db),
            input="BEGIN;\n" + fixture + "\nROLLBACK;\n",
            text=True, capture_output=True, timeout=55, check=False,
            env=isolated_psql_environment(dict(os.environ)),
        )
    finally:
        # This separate database exists only inside the isolated CI Postgres
        # service. Destroy it even when the contract itself fails.
        drop = subprocess.run(
            contract_psql_args("postgres") + [
                "-c", f"DROP DATABASE IF EXISTS {isolated_db} WITH (FORCE)"
            ],
            text=True, capture_output=True, timeout=20, check=False,
        env=isolated_psql_environment(dict(os.environ)),
        )
        if drop.returncode != 0:
            raise RuntimeError("Could not clean up disposable refund test database")
    if completed.returncode != 0:
        # Error messages are synthetic assertion messages, not secrets.
        print("REFUND_ISOLATED_CONTRACT_FAILED:", completed.stderr[-2000:], file=sys.stderr)
        return 1
    print("PASS: refund dispatcher project guard, three queues and leases (mock network)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("REFUND_CONTRACT_ERROR:", str(exc), file=sys.stderr)
        raise SystemExit(1)
