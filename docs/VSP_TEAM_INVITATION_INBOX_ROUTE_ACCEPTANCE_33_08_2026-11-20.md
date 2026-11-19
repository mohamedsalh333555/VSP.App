# 33.08 — Team invitation inbox is reachable from the real Teams UI (bounded)

Date: 20 November 2026. Branch: `uxlp-44-implementation`, Draft PR #35.

## Scope and proof

The `TeamDashboardScreen` already had an invitation icon. To verify actual reachability rather than a textual claim, its unchanged visible entry point has been extracted into `lib/features/player/widgets/team_invitations_action.dart`. It still opens the same `TeamInvitationsSheet` in a safe-area modal, forwards the authenticated player's ID and the membership refresh callback, and keeps its Arabic/English tooltip. No new navigation screen or product surface was added.

- `test/features/player/team_invitations_action_test.dart` mounts the real action in a Flutter widget tree, taps its local-language icon, confirms the inbox and received team appear, and submits the **Accept** action exactly once in both Arabic and English.
- `test/features/player/team_invitations_sheet_test.dart` exercises actual inbox loading, decline, retry, pending-operation de-duplication, account-switch privacy, old async reply invalidation and 320dp/2x long copy.
- `test/team_invitation_inbox_contract_test.dart` asserts the real Teams dashboard references the shared action, and that action opens the intended inbox.
- [Focused CI 44641310054 — 17/17 PASS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44641310054), commit `ff0dad19`, includes static analyze and widget tests. This proves the Flutter UI route, **not** external network delivery.

**Acceptance boundary:** task **33.08** is closed at Flutter widget/route scope. Real two-account Supabase tests (33.09, 33.10, 33.11, 33.12), authenticated Android invitation E2E (33.14), 17.07, staging and cross-account RLS security remain unresolved. No database change, payment change, production deploy, main merge or APK.
