# VSP — Booking and Team Skills transactional notifications (SQL/Staging acceptance)
**17 November 2026 · 9 task IDs · branch `uxlp-44-implementation` · staging only.**

## 4 implemented source migrations and staging evidence
| Feature | File in `supabase/migrations/` | Staging version |
| --- | --- | --- |
| Confirmed cash booking (INSERT or later status UPDATE) | `20261117060000_cash_booking_confirmed_notification_server_guard.sql` | `20261117035425` |
| Team Skills official phase-score approval | `20261117061000_team_skills_approved_phase_score_notification.sql` | `20261117035855` |
| Team Skills approved knockout winner advancement | `20261117062000_team_skills_knockout_approved_advancement_notification.sql` | `20261117035859` |
| Actual booking cancellation | `20261117063000_booking_cancellation_notification_authoritative.sql` | `20261117035901` |

**Verification:** [all source-injected SQL contracts passed, run 44014089643](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44014089643), including `scripts/test_cash_booking_confirmed_notification_isolated.py`, `scripts/test_team_skills_approved_score_notice_isolated.py`, `scripts/test_team_skills_knockout_advancement_notice_isolated.py`, and `scripts/test_booking_cancellation_notification_isolated.py`. Each script refuses a remote SQL target and runs against a fresh disposable PostgreSQL database. An earlier four-path run also [passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44013809313).

After staging-only application, read-only `pg_trigger` and `pg_proc` checks established that all four triggers are enabled, while anon and authenticated users cannot directly EXECUTE their SECURITY DEFINER functions. No historical booking, payment, score, award, customer message or notification row was migrated or rewritten. No production database was changed.

## Bounded tasks accepted
- **45.01:** On initial INSERT of a **confirmed cash** booking, the stadium owner receives one in-app notice; confirmed cash challenges also notify the actual opponent captain. Not a claim for all payment methods or pending reservations.
- **45.02:** If a cash booking starts `pending` and server status later becomes `confirmed`, one status-transition receipt is created; re-saving `confirmed` cannot resend.
- **45.03:** On transition to `cancelled`, both authoritative stadium owner and `bookings.user_id` receive a private message (one if the same user). No false "refund completed" or payment success claims, and no notice on `expired`.
- **45.05:** Owner recipient comes from `stadiums.owner_id`, *never* a forged booking `owner_id`; challenge captain comes from `teams.captain_id`; cancellation booker from `bookings.user_id`, never the unrelated `created_by_user_id`. Cross-user and nonexistent-stadium negatives were tested.
- **45.06:** Server-inserted in-app Arabic title/body/message and exact booking ID plus source/event metadata are tested in the `notifications` table, with negative pending/cancelled/cross-user cases. Not an external push-provider delivery test.
- **46.05:** Cash-confirmed challenge trigger dedup is tested both by repeated confirmed status updates and by retaining a pre-existing legacy `challenge_confirmed` notice without metadata; neither should resend an opponent-captain notification. Other team-invite delivery paths remain open.
- **47.04:** Only `team_skills_scores` with official `status='approved'`, `approved_by`, `approved_at`, a live cup, and an approved registration create a captain-only approved-score in-app notification. Draft/cancelled cups, pending scores, unapproved flags, other captains and replays are denied.
- **47.05:** The exact preceding round's `approved` winning matchup must have placed the approved team in a next-round knockout slot. Qualification notifications go only to that captain; initial seeding, scheduled matches, losers, draft/cancelled cups and duplicate updates cannot generate false advancement. The backend does not invent kickoff times.
- **48.06:** Replayed same-source confirmation, legacy challenge receipt, cancellation, score approval and knockout advancement produce **one logical in-app notification row per event/recipient**, not a duplicate. Does not prove exactly-once external FCM delivery, multiple simultaneous JWT devices or provider resilience.

The existing Flutter inbox maps `booking_id` messages to a scoped booking-detail lookup and uses RLS-visible Team Skills `cup_id` for competition deep links; this does **not** establish real device E2E validation of the new events.

## Explicitly OPEN and not counted
Payment-success notices **45.04/45.07** still require a trusted Paymob/other provider settlement path and must not be inferred from `is_paid` or `payment_status` alone. Team-invite/rejection and notification deep-link device tests **46.01–46.04/46.06**, competition scheduling/re-scheduling/cancellation **47.02/47.03/47.07**, provider attempts/retries/rate limits **48.02–48.05/48.07**, retention **49.xx**, real multi-account JWT **59.xx/79.xx**, release APK **60.05–60.09** remain open. Zero commission on bookings and venue-owner subscription model remain unchanged. No `main` merge, production writes, FCM/SMS delivery promise or signed APK.

**Acceptance: 9 existing task IDs, from 245/385 to 254/376.**
