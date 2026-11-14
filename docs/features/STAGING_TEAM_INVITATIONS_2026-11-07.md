# Team invitation lifecycle — staging partial implementation

Staging project `vtwgqyxglevcsxwdmhop`, migration `add_secure_team_invitation_lifecycle_staging`, 2026-11-07.

Created `public.team_invitations` with team/user FK, unique team-user, status pending/accepted/rejected/cancelled, timestamps and RLS. Authenticated users may SELECT only their invitations or team captain's invitations; anon has no table access. Created SECURITY DEFINER RPCs `invite_team_player(uuid,uuid)` (captain-only) and `respond_team_invitation(uuid,boolean)` (invitee-only); revoked PUBLIC/anon execute, granted authenticated.

Negative tests with `SET LOCAL ROLE authenticated` and no JWT returned `AUTH_REQUIRED` from both RPCs; rolled back. **Limitations:** accepted invitation is recorded but does NOT yet atomically add membership, check geography, or resolve invitations to other teams. No Flutter invitation inbox/sending UI or real-JWT two-account E2E. This is partial #33 only; do not expose as finished user-facing invitation flow. Production and main unchanged.

## Correction: duplicate removed (2026-11-07)

Further schema inspection revealed pre-existing `public.team_membership_invitations` with `invite_team_member(uuid,uuid)` and `respond_team_membership_invitation(uuid,boolean)` RPCs. The existing acceptance RPC **already inserts `team_members` atomically** and enforces governorate and membership limits. The new parallel `team_invitations` design above was redundant and **has been removed on staging** via migration `remove_duplicate_invitation_lifecycle_use_existing_membership_rpcs` after verifying both invitation tables had zero rows. Its two new RPCs were dropped; the original table/RPCs remain intact. No user invitation data lost. Both original RPCs returned `Authentication required` in no-JWT negative tests. Do not use the obsolete RPC names above. Next: inspect Flutter integration and test with real JWTs.

## Flutter repository integration verified by source inspection

`lib/core/repositories/team_repository.dart` already exposes `inviteTeamMember`, `respondToTeamInvitation`, and `getPendingTeamInvitations`, wired to the original `invite_team_member` and `respond_team_membership_invitation` RPCs and `team_membership_invitations` table. Staging permissions verified: `authenticated` can SELECT invitations and EXECUTE both RPCs; `anon` cannot execute either RPC. This is source/permission inspection, not a full UI or real-JWT E2E pass. Do not count #33 complete until tested.
