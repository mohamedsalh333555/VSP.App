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
