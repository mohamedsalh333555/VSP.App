DROP POLICY IF EXISTS roster_guests_select_participant_owner_admin ON public.championship_roster_guests;
DROP POLICY IF EXISTS roster_guests_manage_policy ON public.championship_roster_guests;

CREATE POLICY roster_guests_manage_policy
ON public.championship_roster_guests
AS PERMISSIVE
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.championship_rosters cr
    JOIN public.teams t ON t.id = cr.team_id
    JOIN public.championships c ON c.id = cr.championship_id
    WHERE cr.id = championship_roster_guests.roster_id
      AND (
        t.captain_id = (SELECT auth.uid())
        OR c.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.users u
          WHERE u.id = (SELECT auth.uid())
            AND u.role IN ('admin','super_admin','cofounder','co_founder')
            AND coalesce(u.is_blocked,false)=false
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.championship_rosters cr
    JOIN public.teams t ON t.id = cr.team_id
    JOIN public.championships c ON c.id = cr.championship_id
    WHERE cr.id = championship_roster_guests.roster_id
      AND (
        t.captain_id = (SELECT auth.uid())
        OR c.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.users u
          WHERE u.id = (SELECT auth.uid())
            AND u.role IN ('admin','super_admin','cofounder','co_founder')
            AND coalesce(u.is_blocked,false)=false
        )
      )
  )
);