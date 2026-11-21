# VSP — Team invitation lifecycle and verified online challenge notifications

**Date:** 17 November 2026. **Branch:** `uxlp-44-implementation`. **Acceptance:** 4 distinct existing task IDs, in-app SQL/Staging only. **Not production.**

## Verified code and staging

| Feature | Source | Staging version |
| --- | --- | --- |
| Captain-to-player team invitation and captain response receipts | `supabase/migrations/20261117160000_team_membership_invitation_status_notifications.sql` | `20261117133431` |
| Deny client-origin fake team invitation notifications | `supabase/migrations/20261117161000_notifications_reserved_team_invitation_events_rls.sql` | `20261117133810` |
| Officially confirmed online team challenge notification | `supabase/migrations/20261117162000_online_challenge_verified_confirmation_notifications.sql` | `20261117134128` |

- **Account SQL security contracts:** [run 44095026083](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44095026083), SUCCESS, runs actual migrations injected into fresh disposable PostgreSQL. Also tested on previous commit [run 44093779870](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44093779870).
- **Staging read-only post-apply catalog:** both invitation triggers active, verified-online-challenge trigger active, private trigger routines not directly executable by `authenticated`, restrictive notification RLS contains `team_membership`, and each source migration has a recorded Staging version. There were zero staged invitation records and six existing notification records; migrations did not modify customer notification contents or bookings.
- **Flutter source:** `lib/features/player/screens/notifications_center_screen.dart` and `lib/core/services/notification/team_invitation_notification_route.dart` add safe account-scoped opening of the actual invitation inbox; corresponding unit and architecture tests are present. **Task 46.06 remains OPEN until full Flutter testing of the route is complete and documented.**

## Bounded acceptance of original IDs

**46.01 — Notify team invitee.** Only an invited player receives one in-app `invitation_received` receipt for an invitation created while `pending`, not expired, with `invited_by` matching the team's authoritative current captain. Reissuing a pending invite just extends its expiry and produces no duplicate.

**46.02 — Notify response to team invite.** Only the team's authoritative captain receives a single `invitation_accepted` or `invitation_declined` receipt after the invitation `pending` → final response transition. Acceptance requires the user's membership actually present; decline requires no membership; expired/cancelled requests and repeated status writes are silent.

**46.03 — Challenge notification, confirmed cash and signed Paymob online scope.** Existing `trg_notify_cash_booking_parties` covers cash-confirmed challenges; the new `trg_verified_online_challenge_notice` covers an online booking `pending`→`confirmed` only when the payment matches a `completed` booking transaction, booking owner, order ID, signed successful Paymob callback, amount and status; both team captains come from the team table. Status/amount fields alone cannot send an online confirmed-match notification, and `booking_confirmed` is already a server-reserved notification type under RLS. Cash/online retries are idempotent. Other invitation/approval modes remain out of scope.

**47.07 — Cancelled match must not announce as confirmed (bounded).** The same negative SQL contract proves an online challenge cancelled from pending is never announced as an active/confirmed match, nor is one with missing HMAC proof. An unplayed or cancelled **competition schedule** outside this booking flow is not yet tested, and task 47.02/47.03 remain OPEN.

## Still OPEN — no false claims

- **46.04** acceptance/rejection of a team challenge: the currently deployed `respond_to_challenge_atomic` expressly disables the old approval flow in favor of code-based booking; no acceptance/rejection event is fabricated.
- **46.06** Flutter invitation notification deep-link to the active account's own invitations list has been implemented and its architecture check passed; full end-to-end destination and account-switch/device verification are not claimed by SQL alone.
- **47.02, 47.03** schedules and rescheduling, **48.02–48.05/48.07** push provider attempts/retries and all notification retention tasks remain open.
- No real Paymob bank capture, FCM/device delivery, signed APK or production database deployment is claimed; only Staging SQL and developer branch changed. No `main` merge and venue owner subscription model remains unchanged.

**Updated bounded counter: 262 accepted + 4 = 266 accepted; 368 - 4 = 364 remaining of 630 unique original IDs (42.22%).**
