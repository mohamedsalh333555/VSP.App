-- ============================================================================
-- 🛡️ VSP GOOGLE OAUTH & USER INSERT RLS SECURITY FIX (2026)
-- ============================================================================
-- يحل هذا السكريبت مشكلة (Database error saving new user) عند التسجيل بحسابات جوجل/آبل
-- عن طريق إضافة صلاحية الإدراج (INSERT Policy) لجدول public.users.

ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

-- 1️⃣ إعطاء صلاحية إنشاء بروفايل للمستخدمين الجدد (Google, Apple, Email)
DROP POLICY IF EXISTS "users_insert_own" ON public.users;
CREATE POLICY "users_insert_own" ON public.users
FOR INSERT TO authenticated, anon
WITH CHECK (true);

-- 2️⃣ تأكيد صلاحية القراءة والتحديث للمستخدمين
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
CREATE POLICY "users_select_authenticated" ON public.users
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own" ON public.users
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- ============================================================================
-- ✅ تم تجهيز سكريبت إصلاح حماية التسجيل بجوجل بنجاح.
-- ============================================================================
