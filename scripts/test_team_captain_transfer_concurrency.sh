#!/usr/bin/env bash
set -euo pipefail
# Run ONLY in an ephemeral local GitHub Actions PostgreSQL database.
test "${PGHOST:-}" = "127.0.0.1"
test "${PGPORT:-}" = "5432"
test "${PGDATABASE:-}" = "vsp_captain_transfer_isolated"
test "${PGUSER:-}" = "postgres"
test "$(psql -X -At -v ON_ERROR_STOP=1 -c 'SELECT current_database()')" = "vsp_captain_transfer_isolated"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

# Session A transfers captaincy but deliberately holds its row lock until commit.
psql -X -At -v ON_ERROR_STOP=1 -c "
BEGIN;
SET LOCAL request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
SELECT (public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000002')->>'success');
SELECT pg_sleep(2);
COMMIT;
" > "$dir/first" 2>&1 &
pid1=$!
sleep 0.3
# Session B starts with the OLD captain's JWT while A holds the team row.
psql -X -At -v ON_ERROR_STOP=1 -c "
BEGIN;
SET LOCAL request.jwt.claim.sub='00000000-0000-4000-8000-000000000001';
SELECT (public.transfer_team_captaincy_atomic('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000003')->>'success');
COMMIT;
" > "$dir/second" 2>&1 &
pid2=$!
wait "$pid1"
wait "$pid2"
grep -Fx 'true' "$dir/first" >/dev/null
grep -Fx 'false' "$dir/second" >/dev/null
test "$(psql -X -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM public.teams WHERE id='00000000-0000-4000-8000-000000000010' AND captain_id='00000000-0000-4000-8000-000000000002';")" = "1"
test "$(psql -X -At -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM public.notifications WHERE type='team_transfer';")" = "1"
echo "PASS: two sessions serialized, one captain won, stale captain denied"
