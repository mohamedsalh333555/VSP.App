-- Proposed SQL for VSP Phase 1.4; deliberately NOT in supabase/migrations yet.
-- Preconditions:
-- 1) Verify the verification-documents bucket is absent (production read-only audit did so).
-- 2) Confirm no Flutter, Edge Function, or external client writes/reads this bucket.
-- 3) Disable/delete the deployed one-off function owner_documents_bucket_hardening_once first;
--    it must not be able to recreate these policies after they are removed.
-- 4) Review and approve this SQL before moving it into supabase/migrations.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM storage.buckets WHERE name = 'verification-documents') THEN
    RAISE EXCEPTION
      'Refusing to remove orphaned policies: verification-documents bucket now exists; re-audit first';
  END IF;
END;
$$;

DROP POLICY IF EXISTS "verification_documents_owner_insert" ON storage.objects;
DROP POLICY IF EXISTS "verification_documents_owner_admin_read" ON storage.objects;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname IN (
        'verification_documents_owner_insert',
        'verification_documents_owner_admin_read'
      )
  ) THEN
    RAISE EXCEPTION 'Verification documents orphaned storage policies still exist';
  END IF;
END;
$$;
