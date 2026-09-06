-- ==============================================================================
-- Migration: 20260906_harden_1v1_players_rls_paid_only.sql
-- Defense-in-depth: Strictly enforce payment_status = 'paid' on RLS SELECT
-- ==============================================================================

-- Drop wide/unrestricted SELECT policies on vsp_1v1_tournament_players
DROP POLICY IF EXISTS "Anyone can view tournament players" ON public.vsp_1v1_tournament_players;
DROP POLICY IF EXISTS "Anyone can view players of published tournaments" ON public.vsp_1v1_tournament_players;

-- Create hardened SELECT policy: only paid players are visible to anon/authenticated users
CREATE POLICY "Anyone can view tournament players"
ON public.vsp_1v1_tournament_players
FOR SELECT
TO anon, authenticated
USING (
    (payment_status = 'paid') OR
    (COALESCE(auth.role(), '') = 'service_role') OR
    (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')))
);
