# VSP — verified last-five team matches: source and release gate
**18 November 2026 · Phase 10 task 86.03 · Source audit only / OPEN**

## Staging findings (read-only)
Project: Staging `vtwgqyxglevcsxwdmhop`; production `mktqkddbcddrxjxabdua` untouched.

- `matchup_results` stores `id, booking_id, team_a_id, team_b_id, outcome, recorded_by, created_at`, with outcomes `team_a_win / team_b_win / draw`. It does **not** itself carry a two-captain approval flag.
- Staging `record_matchup_result_atomic` permits the booking creator to record a matchup outcome **after the booked match ends**, verifies participating teams, and disallows a second result for duo mode. It does **not** by itself prove the opponent approved the outcome.
- Separately, `bookings.match_result_status` supports `noResult, waitingOpponent, confirmed, disputed` and `bookings.final_outcome` supports `homeWin, draw, awayWin`. `bookings.is_official_match`, the booking team IDs and result participant scope are distinct source fields.
- Booking rows are privately scoped under authenticated RLS to booking participants, creators, venue owners or admins; `matchup_results` has an authenticated SELECT policy. This difference means a client join could silently omit otherwise existing matches. An empty private read must not be presented as a verified empty public team history.
- Existing `team_head_to_head` provides **aggregate** wins/draws/losses without per-fixture dates. It cannot be inverted to fabricate the last five matches or official rank movement.

## Source contract for future implementation
Before a "Last five verified matches" card can be shown in Team Profile:

1. Establish one canonical **consented, officially confirmed** result source, with two-team challenge agreement or the equivalent server-verified finality; accept only `confirmed` and `is_official_match=true` when those flags are authoritative for that match class. Reject `waitingOpponent`, `disputed`, `noResult`, canceled bookings and inconsistent participants/outcomes.
2. Provide a privacy-reviewed server projection returning only public-safe team identities, match ID, confirmed outcome and verified date. Avoid booking creator/owner/players/payment details. Define the authorized team viewer and policy before any new RLS grant.
3. Deduplicate by canonical fixture ID; exclude conflicting copies, invalid dates, future/unconfirmed fixtures and stale/partially paged reads. Sort by confirmed timestamp and limit to five after verification.
4. Compute any rank delta only within the same competition and approved scoring/tiebreaker rules; missing before/after snapshots must display **unknown**, never a fabricated rank improvement.
5. Test with two separate authenticated accounts, dispute/withdraw/correction, guest reads, role changes, partial network failures and AR/EN/RTL before marking task 86.03 accepted.

**Decision:** no public results query, SQL grant, RLS change, fake match rows or invented ranking UI in this batch. Task 86.03 stays OPEN. No merge to `main` or production deployment.
