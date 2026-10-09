# VSP Security Hardening — execution gates

Repository: mohamedsalh333555/VSP.App  
Production Supabase project: mktqkddbcddrxjxabdua  
Staging project: vtwgqyxglevcsxwdmhop

## Current verified baseline (read-only)

- Production project status: ACTIVE_HEALTHY.
- Staging project status: INACTIVE.
- TRUNCATE is granted to anon on 57 public relations and to authenticated on 59.
- Default privileges for objects created by both postgres and supabase_admin grant TRUNCATE to anon and authenticated.
- RLS is enabled on 66 public tables, but RLS does not block TRUNCATE.
- teams has a public SELECT policy USING (true). It contains captain_phone and active_invite_code; current Flutter code uses .select() and queries captain_phone directly.
- team_members has team_id uuid, user_id uuid, and joined_at timestamptz.
- The verification-documents bucket is absent; two storage policies still reference it. Flutter storage service uses the private owner_documents bucket.
- test_deploy_check_mcp and owner_documents_bucket_hardening_once are still deployed. The latter must be disabled/deleted before removing policies it may recreate.
- Security Advisor currently reports 195 signed-in-callable SECURITY DEFINER functions and leaked-password protection disabled.
- Staging cannot be tested until it is restored to an active state and its schema/functions are verified.

## Execution order

1. Owner confirms the production backup exists and that no other agent is writing to production.
2. Apply Phase 1.1 migration 20261010030000_revoke_truncate_from_api_roles.sql; verify the embedded assertion and query grants again.
3. Disable/delete the one-off Edge Function owner_documents_bucket_hardening_once; only then move the orphan-policy SQL proposal into migrations and apply it with approval.
4. Enable Leaked Password Protection in Supabase Auth settings and verify the setting manually.
5. Stage and review all Edge Function/auth changes. Do not blindly set verify_jwt=true on webhooks or pre-signup checkout endpoints: these have different caller contracts and must preserve HMAC/internal-credential gates.
6. Teams privacy is a separate staged rollout. Do not remove public table read access yet: current Flutter reads teams via .select(), stream, and a phone query. The safe public surface must replace those reads first; invite-code and captain-phone access must be moved to protected RPCs and tested.
7. Review SECURITY DEFINER functions individually, group by caller contract, then propose narrow grants/revokes. Do not mass-revoke functions merely because Advisor flags them.
8. Restore staging, apply schema in migration order, deploy test functions, and run the concurrency test only there. Never use the production URL in the test.
9. After release and staging verification, apply the separate teams lockdown migration.
10. Run final advisor, RLS, TRUNCATE, edge-function, storage, and log checks.

## Phase 1.1 rollback

Only if explicitly approved after assessing the risk, restore the prior explicit/default grants by granting TRUNCATE back to API roles. Re-granting this privilege reinstates the security issue and should not be done as a routine rollback.

## Phase 1.4 SQL proposal

The orphaned storage-policy SQL is in docs/sql-proposals/drop_orphaned_verification_document_policies.sql; it is deliberately not a migration file because the one-off Edge Function can recreate those policies.
