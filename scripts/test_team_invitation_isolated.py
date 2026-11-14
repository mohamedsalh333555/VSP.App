#!/usr/bin/env python3
"""Exercise invitation authorization/expiry in disposable local PostgreSQL."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
INVITE_MIGRATION = ROOT / "supabase/migrations/20261106170000_team_membership_invitations.sql"
RESPONSE_MIGRATION = ROOT / "supabase/migrations/20261106183000_serialize_team_invitation_acceptance.sql"
CONTRACT = ROOT / "supabase/tests/team_invitation_isolated_contract.sql"


def isolated_psql_environment(env: dict[str, str]) -> dict[str, str]:
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


def extract_function(path: Path, signature: str) -> str:
    sql = path.read_text(encoding="utf-8")
    begin = sql.lower().find("create or replace function public." + signature.lower())
    end = sql.find("$$;", begin)
    if begin < 0 or end < 0:
        raise RuntimeError("Missing function delimiters for " + signature)
    return sql[begin:end + len("$$;")]


def run_psql(dbname: str, sql: str | None = None, command: str | None = None):
    argv = [
        "psql", "-X", "--no-psqlrc", "--host=127.0.0.1", "--port=5432",
        "--username=postgres", "--dbname=" + dbname,
        "-v", "ON_ERROR_STOP=1", "-q",
    ]
    if command is not None:
        argv.extend(["-c", command])
    return subprocess.run(
        argv, input=sql, text=True, capture_output=True,
        env=isolated_psql_environment(dict(os.environ)), timeout=60,
    )


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    dbname = "vsp_team_invitation_contracts"
    create = run_psql("postgres", command="CREATE DATABASE " + dbname)
    if create.returncode != 0:
        raise RuntimeError("Cannot create disposable invitation-test database")
    contract = CONTRACT.read_text(encoding="utf-8")
    invite_tag = "-- INVITE_FUNCTION_HERE"
    response_tag = "-- RESPOND_FUNCTION_HERE"
    if contract.count(invite_tag) != 1 or contract.count(response_tag) != 1:
        raise RuntimeError("Invalid invitation contract template")
    sql = contract.replace(
        invite_tag,
        extract_function(INVITE_MIGRATION, "invite_team_member("),
    ).replace(
        response_tag,
        extract_function(RESPONSE_MIGRATION, "respond_team_membership_invitation("),
    )
    try:
        result = run_psql(dbname, "BEGIN;\n" + sql + "\nROLLBACK;\n")
        if result.returncode != 0:
            print("TEAM_INVITATION_CONTRACT_FAILED: " + result.stderr[-2400:], file=sys.stderr)
            return 1
        print("PASS: invitation captain, recipient, expiry, decline and dedupe guards")
        return 0
    finally:
        drop = run_psql("postgres", command="DROP DATABASE IF EXISTS " + dbname + " WITH (FORCE)")
        if drop.returncode != 0:
            raise RuntimeError("Failed to remove disposable invitation-test database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print("TEAM_INVITATION_CONTRACT_ERROR: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
