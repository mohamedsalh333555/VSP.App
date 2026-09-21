-- =============================================================================
-- Migration: 20260918000004_lockdown_payout_settlements_rls.sql
-- Description:
--   1. Revoke all privileges on payout_settlements from anon.
--   2. Drop vulnerable payout_settlements_insert_policy (which allowed clients to bypass atomic RPC).
--   3. Drop unrestricted payout_settlements_update_policy.
--   4. Restrict direct INSERT, UPDATE, DELETE strictly to admins.
--   5. Maintain SELECT for owners on their own records, and full SELECT for admins.
--   6. All client payout requests must go through request_owner_payout_settlement_atomic (SECURITY DEFINER).
-- =============================================================================

BEGIN;

-- 1. طرد anon تماماً من جدول التسويات المالية
REVOKE ALL ON public.payout_settlements FROM anon;

-- 2. حذف السياسات القديمة المعيبة (خاصة التي كانت تسمح للمالك بالإدخال المباشر وتجاوز الدالة الذرية)
DROP POLICY IF EXISTS "payout_settlements_insert_policy" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_update_policy" ON public.payout_settlements;
DROP POLICY IF EXISTS "Admins full access" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_admin_manage" ON public.payout_settlements;
DROP POLICY IF EXISTS "payout_settlements_select_policy" ON public.payout_settlements;

-- 3. سياسة إدارة كاملة (INSERT, UPDATE, DELETE) للأدمن ومؤسسي التطبيق فقط
CREATE POLICY "payout_settlements_admin_manage" ON public.payout_settlements
AS PERMISSIVE FOR ALL TO authenticated
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

-- 4. سياسة القراءة فقط (SELECT): المالك يرى طلباته الخاصة، والأدمن يرى الكل
CREATE POLICY "payout_settlements_select_policy" ON public.payout_settlements
AS PERMISSIVE FOR SELECT TO authenticated
USING (
  owner_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.id = auth.uid() 
      AND users.role IN ('admin', 'co_founder', 'super_admin')
  )
);

COMMIT;
