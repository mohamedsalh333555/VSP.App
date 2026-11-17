"""Verify one of two concurrent refund pre-dispatch order claims wins.

Disposable PostgreSQL only. Never pass hosted database connection values.
This tests the database CAS invariant, not the Paymob provider integration.
"""
from __future__ import annotations

import concurrent.futures
import os
import re
import subprocess


def psql(sql: str) -> list[str]:
    result = subprocess.run(
        ["psql", "-X", "-v", "ON_ERROR_STOP=1", "-A", "-t", "-c", sql],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
        timeout=20,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> None:
    if os.environ.get("PGHOST") != "127.0.0.1" or (
        os.environ.get("PGDATABASE") != "vsp_team_league_refund_isolated"
    ):
        raise SystemExit("Refusing to test refund CAS outside isolated CI PostgreSQL")
    db = psql("SELECT current_database()")
    if db != ["vsp_team_league_refund_isolated"]:
        raise SystemExit("Unexpected target database; no financial test executed")

    inserted = psql(
        "INSERT INTO public.team_league_payments(payment_status) "
        "VALUES ('paid') RETURNING id"
    )
    ids = [v for v in inserted if re.fullmatch(r"[0-9]+", v)]
    if len(ids) != 1:
        raise AssertionError(f"Expected one synthetic order, got {inserted}")
    row_id = int(ids[0])
    update = (
        "UPDATE public.team_league_payments "
        "SET payment_status='refund_pending' "
        f"WHERE id={row_id} AND payment_status='paid' RETURNING id"
    )
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
        results = list(workers.map(psql, [update, update]))
    winners = sum(1 for lines in results if str(row_id) in lines)
    if winners != 1:
        raise AssertionError(
            f"At-most-once refund dispatch claim violated: {winners} winners"
        )
    if psql(
        f"SELECT payment_status FROM public.team_league_payments WHERE id={row_id}"
    ) != ["refund_pending"]:
        raise AssertionError("The winning refund claim was not durably recorded")
    print("PASS: two isolated SQL sessions, one refund claim winner, no double dispatch")


if __name__ == "__main__":
    main()
