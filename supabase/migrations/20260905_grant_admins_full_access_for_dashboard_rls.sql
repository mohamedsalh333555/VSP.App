-- ==============================================================================
-- Migration: 20260905_grant_admins_full_access_for_dashboard_rls.sql
-- Description: Grant Admins and Co-Founders full management access via RLS
--              using the recursion-proof SECURITY DEFINER function public.is_admin_or_cofounder()
-- Note: owner_subscription_status is a VIEW, so RLS policies do not apply to it.
-- ==============================================================================

-- 1. Table: public.users
DROP POLICY IF EXISTS "users_admin_manage_all" ON public.users;
DROP POLICY IF EXISTS "users_admin_manage" ON public.users;
DROP POLICY IF EXISTS "Admins full access" ON public.users;

CREATE POLICY "users_admin_manage_all" ON public.users
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 2. Table: public.vsp_1v1_tournaments
ALTER TABLE public.vsp_1v1_tournaments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins full access" ON public.vsp_1v1_tournaments;
DROP POLICY IF EXISTS "vsp_1v1_tournaments_admin_all" ON public.vsp_1v1_tournaments;

CREATE POLICY "Admins full access" ON public.vsp_1v1_tournaments
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 3. Table: public.vsp_1v1_tournament_players
ALTER TABLE public.vsp_1v1_tournament_players ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins full access" ON public.vsp_1v1_tournament_players;
DROP POLICY IF EXISTS "vsp_1v1_tournament_players_admin_all" ON public.vsp_1v1_tournament_players;

CREATE POLICY "Admins full access" ON public.vsp_1v1_tournament_players
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));


-- 4. Table: public.reviews
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins full access" ON public.reviews;
DROP POLICY IF EXISTS "reviews_admin_all" ON public.reviews;

CREATE POLICY "Admins full access" ON public.reviews
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));
