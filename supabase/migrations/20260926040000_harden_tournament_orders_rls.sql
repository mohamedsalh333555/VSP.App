REVOKE ALL ON TABLE public.tournament_orders FROM anon, authenticated;
DROP POLICY IF EXISTS "tournament_orders_insert_policy" ON public.tournament_orders;
DROP POLICY IF EXISTS "tournament_orders_select_policy" ON public.tournament_orders;
ALTER TABLE public.tournament_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tournament_orders_owner_select" ON public.tournament_orders
FOR SELECT TO authenticated
USING (
  captain_user_id=(SELECT auth.uid())
  OR EXISTS(SELECT 1 FROM public.championships c WHERE c.id=tournament_orders.championship_id AND c.owner_id=(SELECT auth.uid()))
  OR EXISTS(SELECT 1 FROM public.users u WHERE u.id=(SELECT auth.uid()) AND u.role IN ('admin','co_founder','cofounder','super_admin'))
);
GRANT SELECT ON public.tournament_orders TO authenticated;
