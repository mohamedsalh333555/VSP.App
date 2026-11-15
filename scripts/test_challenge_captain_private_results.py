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
RANKING_MIGRATION = ROOT / "supabase/migrations/20261003193000_challenge_mutual_result_agreement_and_points.sql"
NON_PLAYED_CANDIDATE = ROOT / "docs/security/sql/challenge_non_played_report_candidate.sql"
REVIEW_CANDIDATE = ROOT / "docs/security/sql/challenge_non_played_review_candidate.sql"
READ_ONLY_PREFLIGHT = ROOT / "supabase/tests/read_only_challenge_result_rollout_preflight.sql"
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
    report_marker = "-- INSTALL_NOT_PLAYED_REPORT_CANDIDATE"
    if source.count(report_marker) != 1:
        raise RuntimeError("Non-played report contract marker drift")
    source = source.replace(report_marker,NON_PLAYED_CANDIDATE.read_text(encoding="utf-8"))
    review_marker = "-- INSTALL_NOT_PLAYED_REVIEW_CANDIDATE"
    if source.count(review_marker) != 1:
        raise RuntimeError("Non-played review contract marker drift")
    source = source.replace(review_marker,REVIEW_CANDIDATE.read_text(encoding="utf-8"))
    ranking_marker = "-- INSTALL_CHALLENGE_RANKING_TRIGGER"
    raw_ranking = RANKING_MIGRATION.read_text(encoding="utf-8")
    signature = "CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()"
    if source.count(ranking_marker) != 1 or raw_ranking.count(signature) != 1:
        raise RuntimeError("Ranking source or contract marker drift")
    ranking_sql = raw_ranking[raw_ranking.index(signature):].strip()
    if not ranking_sql.endswith("$function$;"):
        raise RuntimeError("Ranking source definition boundary changed")
    source = source.replace(ranking_marker, ranking_sql + """
CREATE TRIGGER trg_calculate_elo BEFORE UPDATE OF status,final_outcome,match_result_status
ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.calculate_elo_on_match_completion();
""")
    preflight = READ_ONLY_PREFLIGHT.read_text(encoding="utf-8")
    import re
    stripped = "\n".join(line.split("--", 1)[0] for line in preflight.splitlines())
    if re.search(r"\b(?:INSERT|UPDATE|DELETE|CREATE|DROP|ALTER|TRUNCATE|COPY|CALL|DO|GRANT|REVOKE|EXECUTE|SET)\b", stripped, re.I):
        raise RuntimeError("Read-only staging preflight contains a write statement")
    source += "\n" + preflight
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
