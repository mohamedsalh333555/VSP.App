-- ==============================================================================
-- 🚀 VSP SUPABASE RLS INFINITE RECURSION FIX (إصلاح التكرار اللانهائي في سياسة جدول users)
-- Description: Fixes 42P17 error where users_select_authenticated queried public.users
--              recursively within its USING clause. Uses a SECURITY DEFINER function
--              to safely evaluate admin role without triggering RLS recursion.
-- Date: 2026-08-24
-- ==============================================================================

-- 1️⃣ دالة فحص صلاحية الأدمن بمعزل عن RLS لتجنب التكرار اللانهائي
CREATE OR REPLACE FUNCTION public.is_admin_or_cofounder(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND role IN ('admin', 'co_founder')
  );
$$;

-- 2️⃣ إعادة كتابة وتثبيت سياسة users_select_authenticated بدون استعلام فرعي متكرر
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
DROP POLICY IF EXISTS users_select_authenticated ON public.users;

CREATE POLICY "users_select_authenticated" ON public.users
FOR SELECT TO authenticated
USING (
  (auth.uid() = id) OR 
  (is_blocked = false) OR 
  public.is_admin_or_cofounder(auth.uid())
);

-- 3️⃣ ضمان تفعيل سياسة users_select_anon
DROP POLICY IF EXISTS "users_select_anon" ON public.users;
DROP POLICY IF EXISTS users_select_anon ON public.users;

CREATE POLICY "users_select_anon" ON public.users
FOR SELECT TO anon
USING (
  is_blocked = false AND 
  is_registration_complete = true
);
