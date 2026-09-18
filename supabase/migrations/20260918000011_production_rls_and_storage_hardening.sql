-- ==============================================================================
-- 🛡️ VSP PRODUCTION RLS & STORAGE HARDENING (2026-09-18)
-- 1. Lockdown direct client writes on public.transactions (RPC/Webhook only)
-- 2. Lockdown direct client writes on public.payout_settlements (RPC only)
-- 3. Deduplicate and consolidate admin manage policies across core tables
-- ==============================================================================

BEGIN;

-- 1️⃣ LOCKDOWN public.transactions (FINANCIAL INTEGRITY)
-- إلغاء الإدخال المباشر من العملاء وحصره بالـ Webhook والدوال الذرية
DROP POLICY IF EXISTS "Admins full access" ON public.transactions;
DROP POLICY IF EXISTS "Admins have full access to transactions" ON public.transactions;
DROP POLICY IF EXISTS "transactions_insert_policy" ON public.transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
DROP POLICY IF EXISTS "transactions_admin_select" ON public.transactions;
DROP POLICY IF EXISTS "transactions_user_select_own" ON public.transactions;

CREATE POLICY "transactions_admin_select" ON public.transactions
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  );

CREATE POLICY "transactions_user_select_own" ON public.transactions
  FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);


-- 2️⃣ LOCKDOWN public.payout_settlements (PREVENT FORGED PAYOUT REQUESTS)
DROP POLICY IF EXISTS "payout_settlements_insert_policy" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_update_policy" ON public.payout_settlements;
DROP POLICY IF EXISTS "Admins full access" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_admin_manage" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_select_policy" ON public.payout_settlements;

CREATE POLICY "payout_settlements_admin_manage" ON public.payout_settlements
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  );

CREATE POLICY "payout_settlements_select_policy" ON public.payout_settlements
  FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  );


-- 3️⃣ CONSOLIDATE & SECURE public.stadiums & public.championships ADMIN POLICIES
DROP POLICY IF EXISTS "Admins full access" ON public.stadiums;
DROP POLICY IF EXISTS "stadiums_admin_manage_all" ON public.stadiums;

CREATE POLICY "stadiums_admin_manage_all" ON public.stadiums
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  );

DROP POLICY IF EXISTS "Admins full access" ON public.championships;
DROP POLICY IF EXISTS "championships_admin_manage" ON public.championships;
DROP POLICY IF EXISTS "championships_admin_manage_all" ON public.championships;

CREATE POLICY "championships_admin_manage_all" ON public.championships
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users 
      WHERE users.id = auth.uid() 
        AND users.role IN ('admin', 'co_founder', 'super_admin')
    )
  );

COMMIT;
