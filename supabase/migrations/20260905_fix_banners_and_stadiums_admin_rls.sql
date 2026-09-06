-- ==============================================================================
-- Migration: 20260905_fix_banners_and_stadiums_admin_rls.sql
-- Description: Fix banners policy (replace legacy typo cofounder with unified is_admin_or_cofounder)
--              and grant admins full access to stadiums for verification and audits.
-- ==============================================================================

-- 1. Fix banners policy
DROP POLICY IF EXISTS "Admins have full access to banners" ON public.banners;
CREATE POLICY "Admins have full access to banners" ON public.banners
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

-- 2. Grant admins manage access on stadiums
DROP POLICY IF EXISTS "stadiums_admin_manage_all" ON public.stadiums;
CREATE POLICY "stadiums_admin_manage_all" ON public.stadiums
FOR ALL TO authenticated
USING (public.is_admin_or_cofounder(auth.uid()))
WITH CHECK (public.is_admin_or_cofounder(auth.uid()));
