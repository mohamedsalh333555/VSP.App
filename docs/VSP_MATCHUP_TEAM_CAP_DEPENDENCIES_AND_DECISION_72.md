# Matchup team-cap RPC: dependencies and product decision (72.02, 72.06)

## 72.02 — Actual function dependencies

Both checked-in files named with migration version `20260926060000` replace the **same function signature**:
`public.add_team_to_matchup_by_code(p_booking_id uuid, p_invite_code text) RETURNS jsonb`, `SECURITY DEFINER`, `search_path=public,pg_temp`.

| Dependency | Why the function uses it |
|---|---|
| `auth.uid()` | authenticated caller identity |
| `public.bookings` | `id`, `created_by_user_id`, `user_id`, `status`, `matchup_closed_at`, `end_time`; row locked with `FOR UPDATE` |
| `public.teams` | `active_invite_code`, `invite_code_expires_at`, `captain_id`, `name`, `logo_url`; invite row locked with `FOR UPDATE` |
| `public.team_members` | requires at least five members on invited team |
| `public.matchup_teams` | rejects duplicate team; counts existing teams; inserts accepted team |
| `public.transactions` | **legacy fee variant only**: paid/completed `type='matchup_extra_teams_fee'` unlocks sixth or later team |
| `authenticated` role | EXECUTE grant; both definitions revoke `anon, public` |

The fee-free variant has **no dependency on `public.transactions`**. It hard-stops at five teams. Both variants consume the invite code by setting `active_invite_code` and `invite_code_expires_at` to null on successful insertion. They both lock the booking and target team; neither contains a live concurrency test in the migration source.

## 72.06 — Recorded product decision

The intended VSP Matchup rule is **maximum five teams and no separate sixth-team / 25 EGP fee**. The checked-in `20260926060000_remove_legacy_matchup_extra_team_fee.sql` documents and implements this rule. The older `20260926060000_fix_matchup_extra_team_fee_column_reference.sql` contradicts it by permitting more teams after a fee.

**Source-only decision:** preserve the five-team, no-fee behavior as the **desired contract**. Do not assume the fee-free function is deployed. The same-version collision means neither alphabetical file order nor the presence of the file proves execution order.

## Required deployment reconciliation (not performed)

1. Query `supabase_migrations.schema_migrations` and inspect `pg_get_functiondef` for the deployed RPC in staging and production.
2. Identify all same-version SQL files and compare applied history before renaming or replaying anything.
3. Confirm no historical extra-team fees or six-plus-team bookings need a separate business/legal remediation.
4. Obtain owner approval before changing deployed function, financial handling or migration history.
5. Run authenticated/anonymous, owner/non-owner, fifth/sixth-team, duplicate invite, concurrency and rollback tests.

**Completion boundary:** 72.02 (source dependency map) and 72.06 (product decision record) are complete. 72.03–72.05 and 72.07 remain open until deployed migration order and rollback are tested. No DB/finance changes made.
