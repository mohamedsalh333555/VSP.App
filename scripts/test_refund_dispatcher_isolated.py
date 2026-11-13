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
    # The disposable CI PostgreSQL service already has Supabase-related
    # roles from the account security fixture; no real external role used.
    completed = subprocess.run(
        ["psql", "-X", "--no-psqlrc", "-v", "ON_ERROR_STOP=1", "-q"],
        input="BEGIN;\n" + fixture + "\nROLLBACK;\n",
        text=True,
        capture_output=True,
        timeout=55,
        check=False,
    )
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
