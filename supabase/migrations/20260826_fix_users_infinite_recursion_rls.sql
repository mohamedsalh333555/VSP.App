-- Fix: 20260826_fix_users_infinite_recursion_rls.sql
-- Drop ALL conflicting and recursive policies on public.users

DROP POLICY IF EXISTS "Admins full access" ON public.users;
DROP POLICY IF EXISTS "users_admin_manage" ON public.users;
DROP POLICY IF EXISTS "users_select_anon" ON public.users;
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
DROP POLICY IF EXISTS "users_insert_policy" ON public.users;
DROP POLICY IF EXISTS "users_update_policy" ON public.users;
DROP POLICY IF EXISTS "users_delete_policy" ON public.users;

-- 1. SELECT: Public/Authenticated can read non-blocked users (and user can always read own profile)
CREATE POLICY "users_select_policy" ON public.users 
FOR SELECT 
USING (
  auth.uid() = id 
  OR is_blocked = false 
  OR auth.role() = 'service_role'
);

-- 2. INSERT: Users can insert their own profile upon registration
CREATE POLICY "users_insert_policy" ON public.users 
FOR INSERT 
WITH CHECK (
  auth.uid() = id 
  OR auth.role() = 'anon'
  OR auth.role() = 'service_role'
);

-- 3. UPDATE: Users can update their own profile (Trigger protect_user_sensitive_fields guards role/blocked/plans)
CREATE POLICY "users_update_policy" ON public.users 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = id) 
WITH CHECK (auth.uid() = id);

-- 4. DELETE: Users can delete their own profile
CREATE POLICY "users_delete_policy" ON public.users 
FOR DELETE 
TO authenticated 
USING (auth.uid() = id);
