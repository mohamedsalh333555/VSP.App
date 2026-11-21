#!/usr/bin/env python3
"""Read-only source contract for the defined challenge-result submission time.

Checks checked-in SQL, not a hosted Supabase deployment.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
sql_path = root / "supabase/migrations/20261003193000_challenge_mutual_result_agreement_and_points.sql"
source = sql_path.read_text(encoding="utf-8")
match = re.search(
    r"CREATE OR REPLACE FUNCTION public\.submit_challenge_result_atomic\("
    r".*?\$function\$;",
    source, flags=re.I | re.S,
)
assert match, "Expected the challenge-only result RPC in the recorded migration"
rpc = match.group()
assert "auth.uid()" in rpc, "Must read the invoking identity"
assert re.search(r"v_now\s+timestamptz\s*:=\s*timezone\('utc',\s*now\(\)\)", rpc, re.I), "Submission time must be read from DB server"
assert "v_booking.end_time>v_now" in rpc.replace(" ", ""), "Server end time must block early submission"
assert "'MATCH_NOT_FINISHED'" in rpc, "Expected explicit early-result rejection"
assert "v_booking.booking_type<>'challenge'" in rpc.replace(" ", ""), "Nonchallenge entries must use their own policies"
assert "'BOOKING_CANCELLED'" in rpc, "Cancelled booking must fail"
assert "'RESULT_ALREADY_FINALIZED'" in rpc, "Already confirmed result must not be re-entered"
cutoff = rpc.index("v_booking.end_time>v_now")
first_update = rpc.index("UPDATE public.bookings")
assert cutoff < first_update, "Time check must occur before changing the booking"
assert "FOR UPDATE" in rpc[:cutoff], "The read must hold a lock before eligibility check"
assert "GRANT EXECUTE" in source, "Authenticated caller grant must be explicit"
print("PASS challenge result timing source contract: server end-time guard before writes")
