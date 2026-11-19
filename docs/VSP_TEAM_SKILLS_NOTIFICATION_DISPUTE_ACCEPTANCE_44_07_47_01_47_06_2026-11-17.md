# Team Skills Cup — in-app registration notifications and disputed award SQL acceptance

**Date:** 17 November 2026 (Cairo). **Branch:** `uxlp-44-implementation`.
**Accepted only in Team Skills Cup; PostgreSQL-backed in-app notification/award boundary.** This does **not** prove FCM/mobile notification delivery, real multi-account OAuth/JWT sessions, payment refund/payout, or production deployment.

## 47.01 — Registration notification

- Canonical trigger migration `supabase/migrations/20261116095000_team_skills_registration_receipt_notification.sql`: one `notifications` row addressed to `new.captain_id` on initial `pending` or `waitlist` registration INSERT. Metadata identifies the exact cup, registration, team, status and `source='team_skills_cup'`, `event='registration_submitted'`. Approved rows get no false initial pending receipt.
- Review migration `20261116085000_team_skills_registration_status_notifications.sql`: only changed status (`approved`, `rejected`, or `waitlist`) creates a separate captain-only in-app review event.
- The real migrations are injected into the disposable `supabase/tests/team_skills_registration_notify_isolated_contract.sql` by `scripts/test_team_skills_registration_notify_isolated.py`. The extended contract checks initial pending/waitlist receipts, two cups with independent captains, no misrouted recipient, correct cup/team metadata, no duplicate notification on repeated same-status update, and no approved initial receipt.
- Read-only staging catalog verified **both** triggers enabled: `team_skills_registration_submission_notify` is AFTER INSERT and `team_skills_registration_review_notify` is AFTER UPDATE OF status WHEN status actually changes. The existing `notifications_select_owner` RLS restricts normal users to their own rows, with an intentional global admin/cofounder exception.
- [SQL CI success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44009406841). This acceptance covers **database in-app notification rows**, not FCM push/device delivery.

## 47.06 — Notification timing tests

- Initial submit receipt is written with the INSERT transaction for pending/waitlist, not from a later client guess.
- Only an actual server-side status change causes review notification, not re-saving an identical status or repeatedly refreshing the UI. Testing verifies once per actual status transition and exact captain.
- No claim about push scheduling latency, delivery windows, third-party provider retry, full tournament schedule/change notices, or device delivery.

## 44.07 — Disputed award cases (bounded)

- The actual `vsp_skills_private.guard_team_champion_finality` blocks incomplete 12-stage teams and tied highest-point teams. New negative fixture denies a losing team's attempt to claim an otherwise undisputed title, and checks that the denied claim leaves **no award record**.
- The actual `vsp_skills_private.guard_goalkeeper_award` blocks a tied keeper award; after objective tie resolution, the newly lower-ranked goalkeeper's prize claim is denied, with no residual award; the true winner can then receive the title.
- Two real-function SQL fixtures are `supabase/tests/team_skills_champion_finality_isolated_contract.sql` and `supabase/tests/team_skills_bracket_keeper_guards_isolated.sql`, each using source migrations via their runners. [SQL CI pass](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44009406841).
- Read-only staging catalogs earlier verified both title finality/tie triggers enabled. This is **scoring/entitlement dispute guard testing**, not operational dispute investigation, compensation or sponsor payouts.

## Explicitly still open

- 45.* booking/payment notifications; 47.02–47.05, 47.07 competition schedule/change/result/advancement/cancellation notifications; 48.* provider delivery/dedup and 49.* retention; 79.08 real cross-account JWT notification read; 44.04–44.06 and 44.08 money due, refunds, payout ledger, premature withdrawal prevention.
- Tests of mobile FCM/push must be run before claiming actual notification delivery.
- No changes to booking commissions (none are charged), owner subscriptions, cash settlements, production or `main`.

**Exactly 3 existing IDs accepted with this bounded evidence: 44.07, 47.01, 47.06.**
