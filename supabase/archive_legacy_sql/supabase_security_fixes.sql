-- ========================================================
-- 1. تصحيح صلاحيات جدول إعدادات التطبيق (app_settings)
-- ========================================================
DROP POLICY IF EXISTS "app_settings_manage" ON public.app_settings;

-- السماح فقط للأدمن بتعديل إعدادات الدفع وأرقام الدعم
CREATE POLICY "app_settings_admin_manage" ON public.app_settings
FOR ALL 
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )
);

-- ========================================================
-- 2. إغلاق ثغرة قراءة جميع بيانات المستخدمين (إزالة OR true)
-- ========================================================
DROP POLICY IF EXISTS "users_select_public" ON public.users;

-- السماح للمستخدم برؤية بياناته كاملة، وللأدمن بالاطلاع على الجميع
-- ول للمستخدمين الآخرين برؤية الحسابات غير المحظورة (لعرض الفرق والبحث)
CREATE POLICY "users_select_authenticated" ON public.users
FOR SELECT
TO authenticated
USING (
  (auth.uid() = id) OR 
  (EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )) OR
  (is_blocked = false)
);

-- ========================================================
-- 3. تأمين مساحات التخزين للمستندات والإيصالات (Storage Buckets)
-- ========================================================

-- جعل مستندات المالكين خاصة وليست عامة
UPDATE storage.buckets
SET public = false
WHERE id IN ('owner_documents', 'verification-documents', 'deposit-receipts');

-- حذف السياسات القديمة المفتوحة للعامة
DROP POLICY IF EXISTS "Allow public read access on VSP buckets" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes on VSP buckets" ON storage.objects;
DROP POLICY IF EXISTS "Public Read verification documents" ON storage.objects;
DROP POLICY IF EXISTS "Public Read deposit receipts" ON storage.objects;

-- سياسة قراءة خاصة: المالك والأدمن فقط يستعرضون وثائق الهوية
CREATE POLICY "secure_owner_docs_read" ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'owner_documents' AND (
    (auth.uid())::text = (storage.foldername(name))[1] OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder'))
  )
);

-- سياسة قراءة خاصة: صاحب الحجز والمالك والأدمن فقط يستعرضون إيصالات الدفع
CREATE POLICY "secure_deposit_receipts_read" ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'deposit-receipts' AND (
    (auth.uid())::text = (storage.foldername(name))[1] OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder'))
  )
);

-- إبقاء صور الملاعب وصور البروفايل متاحة للعرض العام
CREATE POLICY "public_images_read" ON storage.objects
FOR SELECT
TO public
USING (bucket_id IN ('stadium-images', 'profile-pictures'));
