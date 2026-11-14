# Team invitation and active challenge-team acceptance — 2026-11-14

## Accepted checklist items

| Item | Accepted behavior | Evidence |
|---|---|---|
| 17.01 | A signed-in recipient sees pending invitations and a retryable load error. | `team_invitations_sheet_test.dart` load and retry widget scenarios. |
| 17.02 | The recipient can accept an invitation once. | Widget acceptance test plus isolated RPC acceptance contract. |
| 17.03 | The recipient can decline without becoming a member. | Widget decline test plus isolated SQL membership assertion. |
| 17.04 | A successful acceptance requests a parent membership refresh. | Direct widget assertion on `onMembershipChanged`. |
| 17.05 | Repeated taps/responses do not add a second membership. | Busy-action widget test and repeated RPC response assertion. |
| 17.06 | Captain, recipient, authentication, governorate and expiry rules are enforced. | Disposable PostgreSQL contract and guarded runner. |
| 17.08 | An expired invitation or an invitation belonging to another account cannot be accepted. | Negative SQL assertions under separate authenticated identities. |
| 18.04 | Team/challenge checkout uses the account-scoped active verified membership. | `ActiveTeamService` unit coverage and booking checkout architecture regression. |

## Implementation and verification

- `TeamInvitationsSheet` keeps production repository defaults while exposing narrow callback seams for direct widget interaction tests.
- The widget tests cover load, accept, decline, parent refresh, duplicate-tap locking and retry after failure.
- `scripts/test_team_invitation_isolated.py` refuses every non-loopback/non-ephemeral database target and strips libpq redirect variables before invoking `psql`.
- `supabase/tests/team_invitation_isolated_contract.sql` runs only in a disposable CI database. It asserts captain-only invitation, recipient-only response, anonymous rejection, same-governorate enforcement, expiry rejection, decline behavior and repeated-response safety.
- `BookingConfirmationScreen` now resolves `getUserTeamsStrict(userId)` through `ActiveTeamService.resolve(...)`; it no longer chooses an arbitrary first membership for a team or challenge checkout.
- Account SQL security run [43589094157](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43589094157) passed all steps, including the new target guard and invitation contract.
- Flutter CI run [43589094180](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43589094180) passed analyzer, privacy/deletion, architecture, Cairo date checks and the full Flutter suite: **1,394 passed / 11 skipped**. The four invitation widget scenarios and the active-team checkout regression all passed explicitly in the job log.

## Boundaries left open

- **17.07 remains open:** this batch uses separate synthetic authenticated identities in isolated PostgreSQL and direct widget interactions, not two real Supabase Auth accounts on two devices/sessions.
- **18.01 remains open:** the UI and checkout use the strict multi-membership repository path, but this acceptance does not claim a live cross-account Supabase membership query.
- No hosted Supabase schema, RLS policy, Auth account, production/staging row, payment setting, price or permission was changed.
- No APK, `main` merge or release action was performed.
