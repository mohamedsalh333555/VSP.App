-- ==============================================================================
-- Migration: 20260918000008_stage4_consolidate_duplicate_rls_policies.sql
-- Stage: 4 (Policy Deduplication & SSOT Consolidation - Priority Item 7)
-- Description:
--   Deduplicate overlapping legacy policies across core tables.
--   Preserve all legitimate owner/user policies (championships, stadiums, etc.).
--   Consolidate admin management into single SSOT policies using is_admin_or_cofounder().
-- ==============================================================================

BEGIN;

-- 1️⃣ public.app_config
DROP POLICY IF EXISTS "Admins full access" ON public.app_config;
DROP POLICY IF EXISTS "admin_manage_app_config" ON public.app_config;
DROP POLICY IF EXISTS "Anyone can view app config" ON public.app_config;
DROP POLICY IF EXISTS "app_config_select_public" ON public.app_config;
DROP POLICY IF EXISTS "app_config_admin_manage" ON public.app_config;

CREATE POLICY "app_config_select_public" ON public.app_config
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "app_config_admin_manage" ON public.app_config
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 2️⃣ public.app_settings
DROP POLICY IF EXISTS "Admins full access" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_admin_manage" ON public.app_settings;
DROP POLICY IF EXISTS "Anyone can view app settings" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_public_read" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_select_public" ON public.app_settings;

CREATE POLICY "app_settings_select_public" ON public.app_settings
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "app_settings_admin_manage" ON public.app_settings
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 3️⃣ public.championships
-- حذف السياسة الإدارية القديمة المكررة فقط دون المساس بسياسات المالك أو المستخدمين (insert, select, update_own)
DROP POLICY IF EXISTS "Admins full access" ON public.championships;
DROP POLICY IF EXISTS "championships_admin_manage" ON public.championships;
DROP POLICY IF EXISTS "championships_admin_manage_all" ON public.championships;

CREATE POLICY "championships_admin_manage_all" ON public.championships
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 4️⃣ public.stadiums
-- حذف السياسة القديمة المكررة التي كانت تفتقر لـ WITH CHECK، والإبقاء على stadiums_admin_manage_all وسياسات الملاك
DROP POLICY IF EXISTS "Admins full access" ON public.stadiums;
DROP POLICY IF EXISTS "stadiums_admin_manage_all" ON public.stadiums;

CREATE POLICY "stadiums_admin_manage_all" ON public.stadiums
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 5️⃣ public.transactions
-- إزالة التكرار المزدوج الخطير ومنع الإدخال المباشر من العملاء
DROP POLICY IF EXISTS "Admins full access" ON public.transactions;
DROP POLICY IF EXISTS "Admins have full access to transactions" ON public.transactions;
DROP POLICY IF EXISTS "transactions_insert_policy" ON public.transactions;
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
DROP POLICY IF EXISTS "transactions_admin_select" ON public.transactions;
DROP POLICY IF EXISTS "transactions_user_select_own" ON public.transactions;

CREATE POLICY "transactions_admin_select" ON public.transactions
  FOR SELECT TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()));

CREATE POLICY "transactions_user_select_own" ON public.transactions
  FOR SELECT TO authenticated
  USING ((select auth.uid()) = user_id);


-- 6️⃣ public.vsp_1v1_tournaments
-- توحيد السياسات الإدارية وسياسات العرض العام
DROP POLICY IF EXISTS "Admins full access" ON public.vsp_1v1_tournaments;
DROP POLICY IF EXISTS "Admins manage tournaments" ON public.vsp_1v1_tournaments;
DROP POLICY IF EXISTS "vsp_1v1_tournaments_admin_all" ON public.vsp_1v1_tournaments;
DROP POLICY IF EXISTS "Anyone can view active or completed 1v1 tournaments" ON public.vsp_1v1_tournaments;
DROP POLICY IF EXISTS "vsp_1v1_tournaments_select_public" ON public.vsp_1v1_tournaments;

CREATE POLICY "vsp_1v1_tournaments_select_public" ON public.vsp_1v1_tournaments
  FOR SELECT TO anon, authenticated
  USING (true);

CREATE POLICY "vsp_1v1_tournaments_admin_all" ON public.vsp_1v1_tournaments
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 7️⃣ public.vsp_1v1_tournament_players
DROP POLICY IF EXISTS "Admins full access" ON public.vsp_1v1_tournament_players;
DROP POLICY IF EXISTS "Admins manage tournament players" ON public.vsp_1v1_tournament_players;
DROP POLICY IF EXISTS "vsp_1v1_tournament_players_admin_all" ON public.vsp_1v1_tournament_players;

CREATE POLICY "vsp_1v1_tournament_players_admin_all" ON public.vsp_1v1_tournament_players
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 8️⃣ public.reviews
DROP POLICY IF EXISTS "Admins full access" ON public.reviews;
DROP POLICY IF EXISTS "reviews_admin_all" ON public.reviews;

CREATE POLICY "reviews_admin_all" ON public.reviews
  FOR ALL TO authenticated
  USING (public.is_admin_or_cofounder(auth.uid()))
  WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

COMMIT;
