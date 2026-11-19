#!/usr/bin/env python3
"""Apply a candidate live-function fix only inside a disposable loopback SQL DB."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CANDIDATE = ROOT / "docs/security/sql/booking_public_feed_logo_sync_fix_candidate.sql"
FIXTURE = ROOT / "supabase/tests/booking_public_feed_logo_sync_contract.sql"
DB = "vsp_public_feed_logo_sync_contracts"


def require_isolated(env: dict[str, str]) -> None:
    if (env.get("VSP_CONTRACT_ISOLATED") != "1"
        or env.get("PGHOST") != "127.0.0.1"
        or env.get("PGPORT") != "5432"
        or env.get("PGDATABASE") != "vsp_security_contracts"):
        raise RuntimeError("Refusing non-isolated PostgreSQL target")


def psql(db: str, *, sql: str) -> subprocess.CompletedProcess[str]:
    if db not in ("postgres", DB):
        raise RuntimeError("Database target not allowlisted")
    env = {k: v for k, v in os.environ.items()
           if k not in ("PGHOST","PGHOSTADDR","PGPORT","PGDATABASE",
                        "PGUSER","PGSERVICE","PGSERVICEFILE","PGOPTIONS","PGPASSFILE")}
    return subprocess.run([
        "psql","-X","--no-psqlrc","--host=127.0.0.1","--port=5432",
        "--username=postgres","--dbname="+db,
        "-v","ON_ERROR_STOP=1","-q",
    ], input=sql,text=True,capture_output=True,
    timeout=75,check=False,env=env)


def main() -> int:
    require_isolated(dict(os.environ))
    patch = CANDIDATE.read_text(encoding="utf-8")
    if (patch.count("CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()") != 1
        or patch.count("opponent_team_logo_url=excluded.opponent_team_logo_url,") != 1
        or "excluded.opponent_team_logo," in patch):
        raise RuntimeError("Public-feed function source drift; inspect new staging signature")
    fixture = FIXTURE.read_text(encoding="utf-8")
    marker = "-- INSTALL_FEED_LOGO_SYNC_FIX"
    if fixture.count(marker) != 1:
        raise RuntimeError("Public-feed SQL contract marker drift")
    sql = "BEGIN;\n" + fixture.replace(marker, patch) + "\nROLLBACK;\n"
    created = psql("postgres",sql=f"CREATE DATABASE {DB};")
    if created.returncode:
        raise RuntimeError("Unable to create disposable SQL contract database")
    try:
        result = psql(DB,sql=sql)
        if result.returncode:
            print("BOOKING_PUBLIC_FEED_LOGO_SQL_FAILED: " +
                  result.stderr[-2400:],file=sys.stderr)
            return 1
        print("PASS: public booking insert/update, logo sync, privacy, " +
              "cancelled/open_join suppression, republish, delete, financial invariants")
        return 0
    finally:
        deleted = psql("postgres",sql=f"DROP DATABASE IF EXISTS {DB} WITH (FORCE);")
        if deleted.returncode:
            raise RuntimeError("Unable to remove disposable SQL contract database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError,RuntimeError,subprocess.TimeoutExpired) as exc:
        print("BOOKING_PUBLIC_FEED_LOGO_RUNNER_ERROR: " + str(exc),file=sys.stderr)
        raise SystemExit(1)
