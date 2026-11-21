-- Restore the minimal Storage contract used by owner onboarding and profiles.
-- Uploads remain scoped to the authenticated user's top-level folder.

INSERT INTO storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
VALUES
  (
    'stadium-images', 'stadium-images', true, 10485760,
    ARRAY['image/jpeg','image/png','image/webp']
  ),
  (
    'profile-pictures', 'profile-pictures', true, 10485760,
    ARRAY['image/jpeg','image/png','image/webp']
  ),
  (
    'owner_documents', 'owner_documents', false, 10485760,
    ARRAY['image/jpeg','image/png','application/pdf']
  )
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS public_buckets_read ON storage.objects;
CREATE POLICY public_buckets_read
ON storage.objects FOR SELECT TO public
USING (bucket_id IN ('stadium-images', 'profile-pictures'));

DROP POLICY IF EXISTS stadium_images_owner_upload ON storage.objects;
CREATE POLICY stadium_images_owner_upload
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'stadium-images'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS profile_pictures_owner_upload ON storage.objects;
CREATE POLICY profile_pictures_owner_upload
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'profile-pictures'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
CREATE POLICY "Users can update their own files"
ON storage.objects FOR UPDATE TO authenticated
USING (auth.uid() = owner)
WITH CHECK (auth.uid() = owner);

DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
CREATE POLICY "Users can delete their own files"
ON storage.objects FOR DELETE TO authenticated
USING (auth.uid() = owner);

DROP POLICY IF EXISTS owner_documents_owner_manage ON storage.objects;
CREATE POLICY owner_documents_owner_manage
ON storage.objects FOR ALL TO authenticated
USING (
  bucket_id = 'owner_documents'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR public.is_admin_or_cofounder(auth.uid())
  )
)
WITH CHECK (
  bucket_id = 'owner_documents'
  AND (
    (storage.foldername(name))[1] = auth.uid()::text
    OR public.is_admin_or_cofounder(auth.uid())
  )
);

