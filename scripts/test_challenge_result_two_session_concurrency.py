#!/usr/bin/env python3
"""Two REAL PostgreSQL sessions against a newly created, disposable local DB.

No Supabase connections, no live bookings, no host overrides. The booking row
lock serializes captain submissions, owner reports, and admin restorations.
"""
from __future__ import annotations

import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time

from test_challenge_captain_private_results import (
    ROOT, CONTRACT, CANDIDATE, RANKING_MIGRATION,
    NON_PLAYED_CANDIDATE, REVIEW_CANDIDATE, FEED_CANDIDATE, HEAD_TO_HEAD_CANDIDATE, require_isolated,
)

DB = "vsp_challenge_result_concurrency"
HOME = "00000000-0000-0000-0000-000000000011"
AWAY = "00000000-0000-0000-0000-000000000022"
CAPTAIN_HOME = "00000000-0000-0000-0000-000000000101"
CAPTAIN_AWAY = "00000000-0000-0000-0000-000000000202"
OWNER = "00000000-0000-0000-0000-000000000404"
ADMIN = "00000000-0000-0000-0000-000000000505"


def cleaned_env() -> dict[str, str]:
    return {k: v for k, v in os.environ.items() if k not in (
        "PGHOSTADDR", "PGHOST", "PGPORT", "PGDATABASE", "PGUSER",
        "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGPASSFILE")}


def psql(database: str, *, query: str):
    """Fixed local target only: no dependency on the other runner's DB allowlist."""
    if database not in ("postgres", DB):
        raise RuntimeError("Refusing non-disposable SQL target")
    return subprocess.run([
        "psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
        "--port=5432", "--username=postgres", "--dbname=" + database,
        "-v", "ON_ERROR_STOP=1", "-q",
        "-c", query,
    ], text=True, capture_output=True, env=cleaned_env(),
       timeout=60, check=False)


def build_fixture() -> str:
    s = CONTRACT.read_text(encoding="utf-8")
    markers = {
        "-- INSTALL_NOT_PLAYED_REPORT_CANDIDATE": NON_PLAYED_CANDIDATE,
        "-- INSTALL_PRIVATE_RESULTS_CANDIDATE": CANDIDATE,
        "-- INSTALL_NOT_PLAYED_REVIEW_CANDIDATE": REVIEW_CANDIDATE,
        "-- INSTALL_NON_PLAYED_FEED_RLS_CANDIDATE": FEED_CANDIDATE,
        "-- INSTALL_ELIGIBLE_CHALLENGE_HEAD_TO_HEAD_CANDIDATE": HEAD_TO_HEAD_CANDIDATE,
    }
    for marker, path in markers.items():
        if s.count(marker) != 1:
            raise RuntimeError("Contract fixture marker drift: " + marker)
        s = s.replace(marker, path.read_text(encoding="utf-8"))
    marker = "-- INSTALL_CHALLENGE_RANKING_TRIGGER"
    definition = RANKING_MIGRATION.read_text(encoding="utf-8")
    signature = "CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()"
    if s.count(marker) != 1 or definition.count(signature) != 1:
        raise RuntimeError("Rank trigger source drift")
    body = definition[definition.index(signature):].strip()
    if not body.endswith("$function$;"):
        raise RuntimeError("Rank trigger source boundary drift")
    s = s.replace(marker, body + """
CREATE TRIGGER trg_calculate_elo BEFORE UPDATE OF status,final_outcome,match_result_status
ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.calculate_elo_on_match_completion();
""")
    boundary = "\nDO $test$\n"
    if s.count(boundary) != 1:
        raise RuntimeError("Cannot separate schema fixture from synthetic assertions")
    return s.split(boundary, 1)[0]


def check_sql(sql: str, label: str) -> None:
    outcome = psql(DB, query=sql)
    if outcome.returncode != 0:
        raise RuntimeError(label + ": " + outcome.stderr[-1800:])


class Session:
    """Interactive psql session with an explicit ready barrier for each actor."""
    def __init__(self, actor: str, name: str):
        self.name = name
        self.lines: queue.Queue[str] = queue.Queue()
        self.output: list[str] = []
        argv = [
            "psql", "-X", "--no-psqlrc", "--host=127.0.0.1",
            "--port=5432", "--username=postgres", "--dbname=" + DB,
            "-v", "ON_ERROR_STOP=1", "-A", "-t", "-q",
        ]
        self.proc = subprocess.Popen(
            argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, env=cleaned_env(),
            text=True, bufsize=1,
        )
        assert self.proc.stdin is not None and self.proc.stdout is not None

        def drain() -> None:
            for line in self.proc.stdout:
                self.output.append(line)
                self.lines.put(line)

        self.reader = threading.Thread(target=drain, daemon=True)
        self.reader.start()
        self.send("BEGIN; SELECT set_config('request.jwt.claim.sub','"
                  + actor + "',true); SELECT '" + name + "_READY';")
        self.wait(name + "_READY")

    def send(self, sql: str) -> None:
        assert self.proc.stdin is not None
        self.proc.stdin.write(sql.strip() + "\n")
        self.proc.stdin.flush()

    def wait(self, marker: str, seconds: float = 12) -> None:
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                item = self.lines.get(timeout=min(.25, max(.001, deadline-time.monotonic())))
                if marker in item:
                    return
            except queue.Empty:
                if self.proc.poll() is not None:
                    break
        raise RuntimeError(self.name + " never returned " + marker
                           + " (recent output redacted): " + repr(self.output[-4:]))

    def close(self) -> None:
        if self.proc.poll() is None:
            self.send("\\q")
        assert self.proc.stdin is not None
        self.proc.stdin.close()
        self.proc.wait(timeout=12)
        if self.proc.returncode:
            raise RuntimeError(self.name + " psql returned nonzero "
                               + str(self.proc.returncode)
                               + " (last output): " + repr(self.output[-4:]))


def race(label: str, holder_actor: str, holder_sql: str,
         follower_actor: str, follower_sql: str) -> None:
    """First actor acquires booking lock; follower attempts while it is held."""
    a = Session(holder_actor, label + "_A")
    b: Session | None = None
    try:
        a.send(holder_sql + "; SELECT '" + label + "_A_HELD';")
        a.wait(label + "_A_HELD")
        b = Session(follower_actor, label + "_B")
        b.send(follower_sql + "; SELECT '" + label + "_B_DONE';")
        # A still holds its transaction and corresponding booking row lock.
        # Force B's request to start before A commits; it must then converge
        # to one valid serialized outcome, never two independent finalizations.
        time.sleep(.20)
        a.send("COMMIT; SELECT '" + label + "_A_COMMITTED';")
        a.wait(label + "_A_COMMITTED")
        b.wait(label + "_B_DONE")
        b.send("COMMIT; SELECT '" + label + "_B_COMMITTED';")
        b.wait(label + "_B_COMMITTED")
    finally:
        try:
            a.close()
        finally:
            if b is not None:
                b.close()


def booking(i: int) -> str:
    if i not in (16, 17, 18):
        raise RuntimeError("Unexpected synthetic booking identifier")
    return "00000000-0000-0000-0000-" + str(i).zfill(12)


def vote(i: int, team: str) -> str:
    return ("SELECT public.submit_challenge_result_atomic('"
            + booking(i) + "','" + team + "','homeWin')")


def report(i: int) -> str:
    return ("SELECT public.owner_report_challenge_not_played_atomic('"
            + booking(i) + "','The booked match did not take place')")


def restore(i: int) -> str:
    return ("SELECT public.review_challenge_non_played_atomic('"
            + booking(i) + "','restore','Independent review confirmed match was played')")


def seed_first(i: int) -> None:
    check_sql("BEGIN; SELECT set_config('request.jwt.claim.sub','"
              + CAPTAIN_HOME + "',true); " + vote(i, HOME) + "; COMMIT;",
              "Seed first independent captain vote")


def assert_rank(points: int, matches: int) -> None:
    check_sql("""
DO $test$ BEGIN
 IF (SELECT points FROM public.teams WHERE id='""" + HOME + """')<>""" + str(points) + """
    OR (SELECT points FROM public.teams WHERE id='""" + AWAY + """')<>0
    OR (SELECT matches_played FROM public.teams WHERE id='""" + HOME + """')<>""" + str(matches) + """
    OR (SELECT matches_played FROM public.teams WHERE id='""" + AWAY + """')<>""" + str(matches) + """ THEN
   RAISE EXCEPTION 'TWO_SESSION_POINTS_OR_MATCH_COUNT_MISMATCH';
 END IF;
END $test$;""", "Rank consistency")


def main() -> int:
    require_isolated(dict(os.environ))
    if DB in ("postgres", "vsp_security_contracts"):
        raise RuntimeError("Disposable database guard invalid")
    created = psql("postgres", query="CREATE DATABASE " + DB)
    if created.returncode != 0:
        raise RuntimeError("Unable to create disposable concurrency database")
    try:
        check_sql(build_fixture(), "Create synthetic project fixtures")
        check_sql("""INSERT INTO public.bookings
          (id,booking_type,status,end_time,player_team_id,opponent_team_id)
          SELECT ('00000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
          'challenge','confirmed',now()-interval '3 hours',
          '""" + HOME + """','""" + AWAY + """'
          FROM generate_series(16,18) AS i;""", "Seed synthetic bookings")

        race("captain_agreement", CAPTAIN_HOME, vote(16, HOME), CAPTAIN_AWAY, vote(16, AWAY))
        assert_rank(3, 1)
        check_sql("""DO $test$ BEGIN
          IF (SELECT match_result_status FROM public.bookings WHERE id='""" + booking(16) + """')<>'confirmed'
          OR (SELECT elo_processed FROM public.bookings WHERE id='""" + booking(16) + """') IS NOT TRUE
          THEN RAISE EXCEPTION 'TWO_CAPTAINS_DID_NOT_FINALIZE'; END IF;
        END $test$;""", "Captain agreement")

        seed_first(17)
        race("report_first", OWNER, report(17), CAPTAIN_AWAY, vote(17, AWAY))
        assert_rank(3, 1)
        check_sql("""DO $test$ BEGIN
          IF (SELECT count(*) FROM public.challenge_captain_result_entries
              WHERE booking_id='""" + booking(17) + """')<>1
             OR (SELECT status FROM public.challenge_non_played_reports
              WHERE booking_id='""" + booking(17) + """')<>'excluded'
          THEN RAISE EXCEPTION 'REPORT_NOT_SERIALIZED_BEFORE_SECOND_VOTE'; END IF;
        END $test$;""", "Report before second captain")

        seed_first(18)
        race("vote_first", CAPTAIN_AWAY, vote(18, AWAY), OWNER, report(18))
        assert_rank(3, 1)
        check_sql("""DO $test$ BEGIN
          IF (SELECT match_result_status FROM public.bookings WHERE id='""" + booking(18) + """')<>'confirmed'
             OR (SELECT ranking_reversed FROM public.challenge_non_played_reports
                WHERE booking_id='""" + booking(18) + """') IS NOT TRUE
          THEN RAISE EXCEPTION 'REPORT_FAILED_TO_REVERSE_CONFIRMED_RANKING'; END IF;
        END $test$;""", "Report after concurrent agreement")

        race("restore_twice", ADMIN, restore(18), ADMIN, restore(18))
        assert_rank(6, 2)
        check_sql("""DO $test$ BEGIN
          IF (SELECT status FROM public.challenge_non_played_reports
             WHERE booking_id='""" + booking(18) + """')<>'restored'
             OR (SELECT count(*) FROM public.challenge_non_played_review_audit
                WHERE booking_id='""" + booking(18) + """' AND event='restore')<>1
             OR EXISTS (SELECT 1 FROM public.bookings WHERE payment_status<>'paid'
                OR is_paid IS DISTINCT FROM true OR payment_reconcile_state<>'settled'
                OR deposit_paid<>50 OR deposit_amount<>100 OR fair_play_score<>100)
          THEN RAISE EXCEPTION 'CONCURRENT_RESTORATION_DOUBLE_CREDIT_OR_FINANCE_CHANGE'; END IF;
        END $test$;""", "Two concurrent admin restores")

        print("PASS: real two-session booking locks, captain agreement, "
              "owner-report races, single ranking reversal, single restore "
              "and untouched payment/fair-play state")
        return 0
    finally:
        dropped = psql("postgres", query="DROP DATABASE IF EXISTS " + DB + " WITH (FORCE)")
        if dropped.returncode != 0:
            raise RuntimeError("Unable to destroy disposable concurrency database")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("CHALLENGE_TWO_SESSION_CONTRACT_FAILED: " + str(exc), file=sys.stderr)
        raise SystemExit(1)
