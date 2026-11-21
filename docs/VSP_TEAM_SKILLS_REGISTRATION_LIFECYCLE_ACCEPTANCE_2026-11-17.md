# Team Skills Cup — bounded acceptance: 38.06 and 39.01

Date: 17 November 2026, Africa/Cairo.
Branch: `uxlp-44-implementation`, not `main`.

## Newly accepted original IDs

- **38.06 — إغلاق التسجيل (Team Skills Cup only):** The actual
  `public.team_skills_set_status` SQL RPC transitions a tournament from
  `draft` to `registration` to `live` using an admin-authorized caller,
  preserves `published_at`, records precisely one status audit for each
  transition and denies a late captain enrollment through the actual latest
  `public.team_skills_register` function. Existing registration, five active
  roster members and three total audit entries are preserved. Denied reopen
  or direct draft-to-live status transition cannot change records.
- **39.01 — تسجيل فريق أو لاعب (Team Skills Cup only):** A real SQL RPC
  execution enrolls a captain-owned team containing exactly five existing
  team members (one goalkeeper, representative from the same roster) and
  returns a pending registration with five persisted roster records and
  one `register_team` audit. A nonadmin captain cannot publish the cup;
  the accepted record survives the transition to live. This is an
  SQL-backed **team enrollment** acceptance, not an independent one-v-one
  player signup or verified end-to-end mobile browser flow.

## Reproducible SQL evidence

- `supabase/tests/team_skills_registration_lifecycle_isolated_contract.sql`
- `scripts/test_team_skills_registration_lifecycle_isolated.py`
- Test runner extracts the canonical current `team_skills_set_status` RPC
  from `20261116030000_team_skills_cup_foundation.sql` and the current
  `team_skills_register` RPC from
  `20261116164000_team_skills_blocked_captain_roster_guard.sql`.
- Only a **fresh disposable localhost PostgreSQL** database is used; no
  Staging or production mutation.
- [Account SQL security contracts — success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44000082213),
  commit `774d896d41bb1919d4f567b98cd1eeb275b044da`.
- Exact CI success line:
  `PASS: admin publishes draft with timestamp and audit; captain enrolls real five-player roster; live status closes enrollment without deleting accepted signup; outsider, reopen and skip state denied`.

## Accounting and exclusions

Baseline: **230 accepted / 400 open / 630 total**.
Exactly two distinct newly accepted IDs: **38.06** and **39.01**.
New target: **232 accepted / 398 open / 630 total (36.83%)**.

The following are **not** claimed closed by this batch:
- 38.01/38.02 creation of private/open tournament variants;
- 38.04/38.05 broad role matrix / public published tournament details;
- 38.07/38.08 full tournament device journeys and cross-role access;
- 39.02 regional eligibility, JWT-separated real users, notifications;
- team challenge result verification group 84; APK/store-ready release.

No production or staging migrations, no `main` merges, no business-model
changes. This is bounded SQL contract acceptance and must never be reported
as completed device E2E or deployed end-user flow.
