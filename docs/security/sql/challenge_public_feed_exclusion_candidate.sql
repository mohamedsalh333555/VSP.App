-- Non-deployable candidate: hide excluded challenges in the public feed
-- without touching bookings, finance triggers, or stored final outcome.
-- Must be installed after non-played report tables. Real consumer E2E
-- and authorization review remain mandatory before staging rollout.
CREATE SCHEMA IF NOT EXISTS vsp_private;
REVOKE ALL ON SCHEMA vsp_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA vsp_private TO authenticated,service_role;

CREATE OR REPLACE FUNCTION vsp_private.is_challenge_result_excluded(
    p_booking_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $function$
 SELECT EXISTS(
   SELECT 1 FROM public.challenge_non_played_reports r
   WHERE r.booking_id=p_booking_id AND r.status='excluded'
 );
$function$;

REVOKE ALL ON FUNCTION vsp_private.is_challenge_result_excluded(uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION vsp_private.is_challenge_result_excluded(uuid)
  TO authenticated,service_role;

-- RESTRICTIVE policies are AND-ed with the existing permissive SELECT
-- policies. Do NOT add a permissive policy here: OR would leak exclusions.
CREATE POLICY booking_public_feed_exclude_non_played_challenges
ON public.booking_public_feed AS RESTRICTIVE
FOR SELECT TO authenticated
USING (NOT vsp_private.is_challenge_result_excluded(id));
