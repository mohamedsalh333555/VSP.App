# VSP — Team challenge consent code contract (82.01)

Status: **product/engineering specification only**, not a deployed feature.

## Separation of concerns
- Team membership invitations invite a **player** to join a team. They do not grant consent to a match.
- A team challenge code authorizes initiating a **specific team-vs-team match challenge**. It does not enroll players, book a pitch, submit scores, or authorize a loss.
- Only the team's current captain (or an explicitly authorized role, if supported later) can view/share the active code. Server checks captain identity on all mutations.

## Lifecycle
1. A team has exactly one current challenge-consent code. It remains stable across profile views, copying, sharing, invalid attempts, and pending requests.
2. Opponent supplies code with explicit match parameters (both team IDs, proposed venue, date/time, and a unique challenge request ID). A valid code is **not** a general permission to play or change the team's results.
3. Challenge confirmation requires affirmative approval by both teams, including the code owner's captain, for those specific parameters. Until confirmation the code stays unchanged. Confirmation must check team eligibility, participant identities, schedule conflicts, and venue booking rules server-side.
4. In the **same database transaction** that confirms the challenge, consume the current code and generate a new unpredictable code. Old code can never authorize another challenge.
5. Concurrent confirmations for the same code must be serialized (e.g., row lock + version/consumed-state check); at most one can succeed. Retried requests use idempotency keys and return the original confirmation, not consume a second code.
6. Rejection, cancellation before confirmation, expired challenge requests, and sharing a code **do not** rotate the code. A confirmed match later cancelled does not restore the consumed code.
7. Match results have an independent approval/dispute lifecycle. Possession of the code cannot mark the team absent, losing, or otherwise update standings.

## Security and UI acceptance
- Proposed 8-digit code is not sufficient security alone: enforce per-account/team/IP throttling, anti-enumeration responses, server-side authorization, short-lived request tokens, and audit logs. Store only a server-verifiable digest when practical.
- Do not return active code in publicly readable team cards, public queries, logs, or analytics. Show copy/share control only to authorized captain.
- Pending requests must clearly show opponent, match date/time, venue and acceptance state; no silent acceptance.
- Explicitly distinguish challenge-consent code from existing `generate_team_invite_code` RPC: current RPC behavior is described as regenerating a one-hour invite and **must not be reused as-is**, since it rotates on generation rather than confirmed match.
- Verify with two real staging accounts: copy stability, pending/rejection stability, one confirmed rotation, stale code rejection, two concurrent confirmations, replay, wrong team, throttling, and independent score approval.

## Open implementation dependencies
- Locate and consolidate existing invite-code RPCs/migrations and identify authoritative challenge/booking schema.
- Decide where approved matches are persisted and whether venue booking occurs before or after challenge confirmation.
- Implement backend transaction and UI; test on staging and Android. Do not mark 82.02–82.09 complete based on this specification.
