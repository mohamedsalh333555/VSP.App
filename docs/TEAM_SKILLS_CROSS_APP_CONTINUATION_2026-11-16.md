# VSP Team Skills Cup — App/Admin continuation (2026-11-16)

## Scope and safety boundary
- Flutter app: `mohamedsalh333555/VSP.App`, branch `uxlp-44-implementation`.
- Admin panel: `mohamedsalh333555/vsp-admin-panel`, branch `feat/team-skills-cup`.
- This is implementation pending consolidated verification, not release approval.
- Do not merge either `main` branch, deploy SQL or production functions,
  authorize payments or build a public APK as part of this checkpoint.
- No rule changes to team count, role authority, hospitality, awards or timing.
- Existing 630-task register remains **211 accepted / 419 open** until
  individual acceptance criteria are satisfied; commits are not closed tasks.

## This continuation
### Admin panel: 9 commits from `a53a4f039d9bb01b708e4639ef15706dfef12ced`
Head: `26f012ac620441194f4313601482cb0ccd2a675f`.

- Cup-scoped score draft; an old tournament's registration cannot be reused
  when a different cup is selected.
- Mutating actions require a confirmed selected-cup detail snapshot; only
  explicit reload and cup creation bypass this prerequisite.
- Phase editor and operations remount per cup to clear old form selections.
- An in-flight RPC does not claim success for a newly selected tournament;
  stale read failures do not override that tournament's notification.
- Synchronous double-submit guard on admin actions.
- Approval preview requires exactly five active distinct players, one actual
  goalkeeper matching the registration, and a selected active 1v1 representative.
  Database approval trigger still rechecks identities and current team status.
- New isolated helper tests and source-level cross-cup guard tests.

### Flutter: 5 commits from `06ead64cf98c4ee4a268b5d0e647c9fd5b248bf4`
Head: `2e119d3a6a8f6f682128d511775a699846320c3c`.

- Enrollment success copy is conditioned on readback of the exact captain/team
  registration (pending, waitlist or approved).
- Withdrawal success copy requires a readback of the same captain's request
  in terminal `withdrawn` status.
- Roster-edit feedback now reflects refreshed admin approval or waitlist
  status rather than assuming the request remains pending.
- Dart tests added for exact registration/captain status and changed copy.

## Evidence and limits
- Repository compare endpoints confirmed 9 admin and 5 app commits without
  branch divergence from their respective prior checkpoints.
- Four Node.js **isolated mirrored-helper checks** passed locally for score
  draft isolation, allowed registration, active-five lineup, keeper and 1v1
  representative. This does **not** mean the full repository test suite passed.
- Flutter analyzer/widget tests, Vite build, full Node test suite, staging
  multi-role device/browser acceptance and production rollout **not run**.
- No claim of current database state, FCM delivery or store release readiness.

## Next safe execution gates
1. Run project-native Node tests and Vite build on admin branch.
2. Run Flutter analyzer and focused Team Skills widget tests.
3. Validate captain/admin/other-member accounts in isolated staging, including
   rapid cup switching, account switching, weak network and double clicks.
4. Compare actual staging migration history with checked-in lineage before
   any SQL deployment; keep explicit safety gates for sensitive operations.

## Follow-up implementation checkpoint — 16 November 2026

### Flutter — branch `uxlp-44-implementation`
Changes from `39a73f4926404106ed1b31f4cf9595c10afcc1c1` through
`2ec126ce67616e69ffdfd639a6c5d0b2e22243da` (six commits):
- Repaired the old withdrawal source assertion so it follows the canonical
  captain withdrawal readback rather than an obsolete widget expression.
- Roster correction now invalidates and clears private form data whenever
  the signed-in identity changes. Asynchronous loading and saving results
  from the old session cannot repopulate the new session's editor.
- Edit preflight rechecks the current cup/registration/captain/team,
  payment/check-in state, and server-stored keeper and representative.
  Stale navigation arguments never authorize a captain edit.
- The edit screen verifies the exact cup/team/status on readback.
- After a successful edit, the parent requests the captain's current
  registration directly rather than trusting a potentially superseded
  periodic refresh. Focused source and repository tests updated.
- 54 focused literal source expectations (tab/screen/repository) inspected
  against the latest checked-in sources: no missing expected snippets.
  **This is not proof of Dart compilation or widget runtime success.**

### Admin — branch `feat/team-skills-cup`
Changes from `26f012ac620441194f4313601482cb0ccd2a675f` through
`d8736fd9d3cf57de721278d5fbd4ca0207c31e31` (three commits):
- A goalkeeper session requires two distinct teams and increasing valid times.
- The admin explicitly selects one scheduled goalkeeper trial before entering
  its measurement, preventing accidental writes to a different trial.
- Saves, shots and conceded values must be nonnegative whole numbers; saves
  cannot exceed shots. Final 1v1 score must be distinct nonnegative whole goals.
- Pure guards include case coverage for invalid inputs. The backend remains
  authoritative for all match and tournament rules.

### Verification and release boundaries
- Admin **project-native GitHub Actions test and build run succeeded** at
  `d8736fd9d3cf57de721278d5fbd4ca0207c31e31`:
  https://github.com/mohamedsalh333555/vsp-admin-panel/actions/runs/43961875672
- Nine direct focused cases exercised against the checked-in admin pure
  guard implementation also passed; do not substitute these for full E2E.
- Flutter CI, Android smoke and security contract workflows were still
  in progress at this checkpoint and must be assessed at the exact tested
  SHA. Do not label pending checks as passing.
- No production migration, payment, release APK, deploy or merge to `main`.
- The accepted core counter remains **211/630 accepted, 419 open**:
  technical commits are not automatically accepted core tasks.
