#!/usr/bin/env python3
"""Two independent local SQL sessions compete for the final pickup slot.

Never touches staging, production, Paymob or any user account. The entire
fixture lives inside a fresh disposable PostgreSQL CI database.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys

from test_accept_join_request_isolated import (
    CANDIDATE, CONTRACT, extract_function, isolated_psql_environment,
    reject_nonlocal_targets,
)

TEST_DB = "vsp_join_race_contracts"
BOOKING = "10000000-0000-4000-8000-000000000011"
HOST = "20000000-0000-4000-8000-000000000011"
PLAYERS = (
    "30000000-0000-4000-8000-000000000011",
    "30000000-0000-4000-8000-000000000012",
)


def psql_args(database: str) -> list[str]:
    if database not in ("postgres", TEST_DB):
        raise RuntimeError("Unexpected database in isolated concurrency test")
    return [
        "psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
        "--port=5432", "--username=postgres", "--dbname=" + database,
        "--set=ON_ERROR_STOP=1", "-q", "-A", "-t",
    ]


def sql(database: str, content: str, timeout: int = 60) -> str:
    proc = subprocess.run(
        psql_args(database),
        input=content, text=True, capture_output=True, timeout=timeout,
        env=isolated_psql_environment(dict(os.environ)), check=False,
    )
    if proc.returncode:
        raise RuntimeError("Isolated SQL contract failed: " + proc.stderr[-700:])
    return proc.stdout.strip()


def main() -> int:
    reject_nonlocal_targets(dict(os.environ))
    # Refuse an existing DB. Never adopt/drop a pre-existing test database.
    sql("postgres", "CREATE DATABASE " + TEST_DB + ";")
    try:
        template = CONTRACT.read_text(encoding="utf-8").split("do $contract$", 1)[0]
        tag = "-- ACCEPT_JOIN_FUNCTION_HERE"
        if template.count(tag) != 1:
            raise RuntimeError("Missing join fixture marker")
        candidate = extract_function(CANDIDATE)
        setup = template.replace(tag, candidate) + f"""
insert into public.bookings(
 id,created_by_user_id,owner_id,status,current_players,total_field_capacity,
 pending_user_ids,joined_user_ids
) values(
 '{BOOKING}', '{HOST}',null,'confirmed',1,2,
 array['{PLAYERS[0]}','{PLAYERS[1]}'],array[]::uuid[]
);

-- Delay the winning UPDATE while the lock is held, encouraging actual
-- contention by the second connection rather than a purely serial test.
create function public.fixture_hold_join_lock()
returns trigger language plpgsql as $test$
begin
  perform pg_sleep(0.3);
  return new;
end;
$test$;
create trigger fixture_hold_join_lock before update on public.bookings
for each row execute function public.fixture_hold_join_lock();
"""
        sql(TEST_DB, setup)

        def attempt(player: str) -> dict:
            result = sql(TEST_DB, f"""
begin;
set local request.jwt.claim.role = 'authenticated';
set local request.jwt.claim.sub = '{HOST}';
select public.accept_join_request('{BOOKING}','{player}')::text;
commit;
""")
            return json.loads(result)

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(attempt, PLAYERS))
        successes = [r for r in results if r.get("success") is True]
        full = [r for r in results if r.get("error") == "BOOKING_FULL"]
        if len(successes) != 1 or len(full) != 1:
            raise RuntimeError("Last-slot race did not resolve to one winner")

        state = json.loads(sql(TEST_DB, f"""
select jsonb_build_object(
  'players',current_players,
  'joined',cardinality(joined_user_ids),
  'pending',cardinality(pending_user_ids),
  'first_joined','{PLAYERS[0]}'::uuid=any(joined_user_ids),
  'second_joined','{PLAYERS[1]}'::uuid=any(joined_user_ids)
)::text from public.bookings where id='{BOOKING}';
"""))
        if (
            state["players"] != 2 or state["joined"] != 1 or
            state["pending"] != 1 or
            (state["first_joined"] == state["second_joined"])
        ):
            raise RuntimeError("Final slot counters/roster diverged")
        print("PASS: independent SQL clients cannot take the same final slot")
        return 0
    finally:
        sql("postgres", "DROP DATABASE IF EXISTS " + TEST_DB + " WITH (FORCE);")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        print("LOCAL_JOIN_RACE_CONTRACT_FAILED: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
