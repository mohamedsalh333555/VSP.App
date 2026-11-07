# Team invitation lifecycle — staging partial implementation

Staging project `vtwgqyxglevcsxwdmhop`, migration `add_secure_team_invitation_lifecycle_staging`, 2026-11-07.

Created `public.team_invitations` with team/user FK, unique team-user, status pending/accepted/rejected/cancelled, timestamps and RLS. Authenticated users may SELECT only their invitations or team captain's invitations; anon has no table access. Created SECURITY DEFINER RPCs `invite_team_player(uuid,uuid)` (captain-only) and `respond_team_invitation(uuid,boolean)` (invitee-only); revoked PUBLIC/anon execute, granted authenticated.

Negative tests with `SET LOCAL ROLE authenticated` and no JWT returned `AUTH_REQUIRED` from both RPCs; rolled back. **Limitations:** accepted invitation is recorded but does NOT yet atomically add membership, check geography, or resolve invitations to other teams. No Flutter invitation inbox/sending UI or real-JWT two-account E2E. This is partial #33 only; do not expose as finished user-facing invitation flow. Production and main unchanged.
