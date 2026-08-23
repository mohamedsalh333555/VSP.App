-- ==============================================================================
-- 🚀 VSP PLATFORM — STADIUM ONBOARDING & OWNER DOCUMENT VERIFICATION PATCH (FIXED)
-- Description: Creates Storage Buckets, Storage RLS Policies, and Atomic RPC
--              for Owner Document Verification & Facility Onboarding.
-- Date: 2026-08-23
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ إنشاء وضمان وجود مجلدات التخزين (Supabase Storage Buckets)
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('stadium-images', 'stadium-images', true),
  ('owner_documents', 'owner_documents', false),
  ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;


-- ------------------------------------------------------------------------------
-- 2️⃣ سياسات الأمان لمجلدات التخزين (Storage RLS Policies)
-- ------------------------------------------------------------------------------

-- أ. صور الملاعب (stadium-images) - قراءة عامة للجميع ورفع للمستخدمين الموثقين
DROP POLICY IF EXISTS "Public read stadium images" ON storage.objects;
CREATE POLICY "Public read stadium images" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'stadium-images');

DROP POLICY IF EXISTS "Authenticated upload stadium images" ON storage.objects;
CREATE POLICY "Authenticated upload stadium images" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'stadium-images');

DROP POLICY IF EXISTS "Authenticated update stadium images" ON storage.objects;
CREATE POLICY "Authenticated update stadium images" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'stadium-images');

DROP POLICY IF EXISTS "Authenticated delete stadium images" ON storage.objects;
CREATE POLICY "Authenticated delete stadium images" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'stadium-images');


-- ب. وثائق المالك الرسمية (owner_documents) - خاصة بالمالك والإدارة فقط
DROP POLICY IF EXISTS "Owner upload own documents" ON storage.objects;
CREATE POLICY "Owner upload own documents" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'owner_documents' 
  AND (auth.uid())::text = (storage.foldername(name))[1]
);

DROP POLICY IF EXISTS "Owner access own documents or Admin" ON storage.objects;
CREATE POLICY "Owner access own documents or Admin" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'owner_documents' 
  AND (
    (auth.uid())::text = (storage.foldername(name))[1]
    OR EXISTS (
      SELECT 1 FROM public.users 
      WHERE public.users.id = auth.uid() 
      AND public.users.role IN ('admin', 'co_founder')
    )
  )
);

DROP POLICY IF EXISTS "Owner update own documents" ON storage.objects;
CREATE POLICY "Owner update own documents" ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id = 'owner_documents' 
  AND (auth.uid())::text = (storage.foldername(name))[1]
);


-- ج. الصور الشخصية (profile-pictures)
DROP POLICY IF EXISTS "Public read profile pictures" ON storage.objects;
CREATE POLICY "Public read profile pictures" ON storage.objects
FOR SELECT TO public
USING (bucket_id = 'profile-pictures');

DROP POLICY IF EXISTS "Authenticated upload profile pictures" ON storage.objects;
CREATE POLICY "Authenticated upload profile pictures" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'profile-pictures');


-- ------------------------------------------------------------------------------
-- 3️⃣ حذف التوقيع القديم للدالة لتجنب تعارض نوع الإرجاع (DROP OLD FUNCTION)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_owner_verification(UUID, JSONB);
DROP FUNCTION IF EXISTS public.submit_owner_verification(UUID);


-- ------------------------------------------------------------------------------
-- 4️⃣ دالة تقديم وثائق المالك وتأكيد اكتمال الملعب الأول (submit_owner_verification RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_owner_verification(
    p_owner_id UUID,
    p_additional_data JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := COALESCE(p_owner_id, auth.uid());
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner ID required');
    END IF;

    UPDATE public.users
    SET 
        verification_status = 'pending',
        is_registration_complete = true,
        has_stadium = true,
        additional_data = COALESCE(additional_data, '{}'::jsonb) || p_additional_data,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Owner verification submitted successfully'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5️⃣ منح الصلاحيات (Grant Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.submit_owner_verification(UUID, JSONB) TO authenticated, service_role;

COMMIT;
