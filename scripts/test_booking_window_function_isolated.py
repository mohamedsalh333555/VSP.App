#!/usr/bin/env python3
"""Test only the booking-window validator using an ephemeral CI PostgreSQL DB.

Never connect to production or staging. Two transactions are opened on the
local CI service; both are rolled back/aborted before disconnect.
"""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "supabase/migrations/20261006005321_enforce_booking_operating_hours_and_breaks.sql"
CANDIDATE = ROOT / "supabase/migrations/20261113143000_fix_expired_stadium_maintenance_booking_guard.sql"
CONTRACT = ROOT / "supabase/tests/booking_operating_maintenance_guard_contract.sql"

def isolated_psql_environment(env: dict[str, str]) -> dict[str, str]:
    """Strip libpq redirects; the subprocess must use its explicit loopback CLI target."""
    unsafe = {
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE",
    }
    return {key: value for key, value in env.items() if key not in unsafe}



def assert_isolated_environment(env: dict[str, str]) -> None:
    if env.get("VSP_CONTRACT_ISOLATED") != "1":
        raise RuntimeError("VSP_CONTRACT_ISOLATED=1 required")
    if env.get("PGHOST") not in ("127.0.0.1", "localhost", "::1"):
        raise RuntimeError("Refusing non-loopback PostgreSQL host")
    if env.get("PGDATABASE") != "vsp_security_contracts":
        raise RuntimeError("Refusing non-ephemeral database name")
    if env.get("PGPORT") != "5432":
        raise RuntimeError("Unexpected test PostgreSQL port")


def extract_validator_definition(path: Path) -> str:
    source = path.read_text(encoding="utf-8")
    begin = source.lower().find(
        "create or replace function public.vsp_validate_stadium_booking_window("
    )
    if begin < 0:
        raise RuntimeError(f"Validator not found in {path.name}")
    marker = "$function$;" if "$function$;" in source[begin:] else "$$;"
    finish = source.find(marker, begin)
    if finish < 0:
        raise RuntimeError(f"Could not locate end of validator in {path.name}")
    sql = source[begin : finish + len(marker)]
    if "returns boolean" not in sql.lower():
        raise RuntimeError("Unexpected validator return type")
    return sql


def run_psql(sql: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["psql", "--no-psqlrc", "-X", "--host=127.0.0.1",
         "--port=5432", "--username=postgres",
         "--dbname=vsp_security_contracts", "-v", "ON_ERROR_STOP=1", "-q"],
        input=sql,
        text=True,
        capture_output=True,
        env=isolated_psql_environment(dict(os.environ)),
        timeout=55,
        check=False,
    )


def main() -> int:
    assert_isolated_environment(dict(os.environ))
    contract = CONTRACT.read_text(encoding="utf-8")
    original = extract_validator_definition(BASELINE)
    fixed = extract_validator_definition(CANDIDATE)

    # Negative gate: the same assertions MUST catch the deployed baseline bug.
    negative = run_psql("BEGIN;\n" + original + "\n" + contract + "\nROLLBACK;\n")
    if negative.returncode == 0 or "FAIL: expired maintenance marker" not in negative.stderr:
        print(
            "EXPECTED_BASELINE_FAILURE_NOT_DETECTED: "
            + negative.stderr[-1800:],
            file=sys.stderr,
        )
        return 1
    print("PASS: baseline function rejected by SQL regression contract")

    # Positive gate: the candidate must pass the full contract, including
    # expired/active maintenance, overnight shift breaks, and null timestamps.
    positive = run_psql("BEGIN;\n" + fixed + "\n" + contract + "\nROLLBACK;\n")
    if positive.returncode != 0:
        print("REMEDIATION_SQL_CONTRACT_FAILED: " + positive.stderr[-3000:], file=sys.stderr)
        return 1
    print("PASS: candidate booking validator passed isolated PostgreSQL SQL cases")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"ISOLATED_BOOKING_CONTRACT_ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
