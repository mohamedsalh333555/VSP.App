# VSP Team Skills Cup — bounded acceptance of 42.01 + 42.04

Date: 2026-11-17 (Africa/Cairo). Active branch pair:
- Flutter / SQL: `VSP.App/uxlp-44-implementation`.
- Admin UI: `vsp-admin-panel/feat/team-skills-cup`.

Previously accepted: **226 of 630**. Two new, unique bounded acceptances:
**42.01** and **42.04**. Result: **228 accepted / 402 open**.

## 42.01 — عرض النتائج المعلقة للمشرف

**Accepted for the Team Skills Admin scores screen only.** The UI now
defaults to the pending-only review queue (the existing pending rows
continue to offer approval). A pending count is shown and the reviewer can
toggle a full history including approved/rejected rows.

Evidence:
- `src/services/teamSkillsScoreReview.js` provides a non-mutating review
  selection/count; malformed inputs fail safely.
- `src/pages/TeamSkillsCupPage.jsx`: queue is scoped to the currently
  verified cup detail. Action controls still require `detailIsCurrent`
  and a live cup before any privileged RPC is sent.
- `test/teamSkillsScoreReview.test.js` checks pending filtering, all-results
  toggle, preserving input and fail-closed behavior.
- [Admin Panel CI — 127/127 Node tests, production build success](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43994557087)
  on SHA `f25682f50d957c506a06d3c212b8e0ad0966eee1`.
  Admin Dashboard CI and the second Admin Panel CI run also succeeded on
  that exact commit.

Exclusions: signed-in reviewer session, real network readback in browser,
notifications and user-facing mobile views.

## 42.04 — رفض النتيجة وإعادتها

**Accepted for Team Skills admin reject → admin correction → reapproval
workflow**, not a separate judge resubmission product flow.

- New migration `20261117020000_team_skills_reject_score_audited.sql`
  adds `public.team_skills_reject_score(uuid,text)`, an authenticated-only
  `SECURITY DEFINER` RPC with an admin predicate.
- Checks server-side: pending only, reason trimmed length 10–1000,
  cup live, no existing knockout bracket, same advisory lock used
  when generating finals. Writes status `rejected` while retaining
  raw/points, with immutable audit evidence of actor, reason and prior value.
  Existing admin `team_skills_correct_score` returns a rejected score
  to `pending`, and `team_skills_approve_score` then reapproves it.
- New local contract
  `scripts/test_team_skills_score_rejection_isolated.py` plus
  `supabase/tests/team_skills_score_rejection_isolated_contract.sql`
  uses canonical production-source score calculator/approve/correct RPC
  together with the new reject RPC in a **fresh disposable local PostgreSQL**.
  It proves: outsider blocked; short reason blocked; pending rejected with
  exactly one audit; rejection of already approved, unknown or duplicate
  score blocked; correction recalculates points and preserves old rejected
  status in its audit; admin reapproval succeeds; post-seeding and cancelled
  cups denied without new audit.
- [Account SQL security CI — Success](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43994454128),
  SHA `28ad48d1daafe6131f58bdc2bf40634e321cf080`.
- Staging-only migration `team_skills_reject_score_audited_20261117`
  **applied successfully** and recorded by staging under version
  **`20261117011700`**; verified afterwards by SELECT-only metadata:
  `SECURITY DEFINER=true`, `anon EXECUTE=false`,
  `authenticated EXECUTE=true`, admin check, advisory lock and audit
  write all present. Source-to-staging version provenance is recorded in
  `docs/team_skills_staging_migration_lineage.json` (35 entries).
  No production migrations were run.
- Admin `teamSkillsService.rejectScore` invokes only the RPC; scores UI
  requires a documented reason, scopes draft text to the selected cup/score
  and allows rejection only before finals. Rejected status instructs
  using the existing audited correction editor.
- [Admin Panel CI — 127 tests and build](https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43994557087),
  including the new `test/teamSkillsScoreRejection.test.js`.

### Not yet accepted, and never implied by this limited closure

- Authenticated staging *signed-in* accounts with distinct JWTs and
  actual manager/judge browser journeys remain to be exercised.
  The isolated SQL role-claim fixture is not an equivalent JWT E2E.
- **40.05** genuine tied-knockout adjudication and **40.06** safe *regeneration*
  workflow still open; the current RPC rejects ties without awarding a winner
  and refuses re-generation.
- **42.08**, **47.***, **59.***, **77.06**, **78.04–78.05**, **79.*** and
  **84.*** remain as their original broader integration/security requirements.
- No `main` merges, production DB changes or APK/store readiness claim.

**Counting rule:** IDs are promoted once each based on the bounded receipts;
code commits and tests are not themselves task units. The authoritative
630-ID checklist, unified plan, delivery ledger and current counter must
agree via the existing task-accounting GitHub workflow.
