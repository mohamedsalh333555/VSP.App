-- VSP audit remediation: security hardening + FK indexes
-- Safe, additive/permission-tightening migration. No data deletion.

DROP POLICY IF EXISTS "Authenticated upload stadium images" ON storage.objects;
DROP POLICY IF EXISTS "Allow Authenticated Users to Upload Receipts" ON storage.objects;

REVOKE EXECUTE ON FUNCTION public.get_player_match_details(uuid) FROM anon;

REVOKE EXECUTE ON FUNCTION public.sync_player_phone_on_booking_insert() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_player_phone_on_booking_insert() FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_player_phone_on_booking_insert() FROM authenticated;

ALTER VIEW public.owner_subscription_status SET (security_invoker = true);

DROP POLICY IF EXISTS roster_guests_select_policy ON public.championship_roster_guests;

CREATE POLICY roster_guests_select_participant_owner_admin
ON public.championship_roster_guests
FOR SELECT TO authenticated
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
);

CREATE INDEX IF NOT EXISTS idx_cancellation_refund_queue_championship_id ON public.cancellation_refund_queue(championship_id);
CREATE INDEX IF NOT EXISTS idx_cancellation_refund_queue_registration_id ON public.cancellation_refund_queue(registration_id);
CREATE INDEX IF NOT EXISTS idx_championship_registrations_captain_id ON public.championship_registrations(captain_id);
CREATE INDEX IF NOT EXISTS idx_championship_rosters_registration_championship_team ON public.championship_rosters(registration_id, championship_id, team_id);
CREATE INDEX IF NOT EXISTS idx_championships_rejected_by ON public.championships(rejected_by);
CREATE INDEX IF NOT EXISTS idx_championships_stadium_id ON public.championships(stadium_id);
CREATE INDEX IF NOT EXISTS idx_match_score_edits_edited_by ON public.match_score_edits(edited_by);
CREATE INDEX IF NOT EXISTS idx_owner_subscription_orders_plan_code ON public.owner_subscription_orders(plan_code);
CREATE INDEX IF NOT EXISTS idx_support_ticket_messages_sender_id ON public.support_ticket_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_booking_id ON public.support_tickets(booking_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_conversation_id ON public.support_tickets(conversation_id);
CREATE INDEX IF NOT EXISTS idx_team_challenge_codes_used_in_booking_id ON public.team_challenge_codes(used_in_booking_id);
CREATE INDEX IF NOT EXISTS idx_team_league_cancellation_refund_queue_championship_id ON public.team_league_cancellation_refund_queue(championship_id);
CREATE INDEX IF NOT EXISTS idx_team_league_cancellation_refund_queue_payment_id ON public.team_league_cancellation_refund_queue(payment_id);
CREATE INDEX IF NOT EXISTS idx_team_league_cancellation_refund_queue_user_id ON public.team_league_cancellation_refund_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_team_league_match_submissions_submitted_by ON public.team_league_match_submissions(submitted_by);
CREATE INDEX IF NOT EXISTS idx_team_league_payments_user_id ON public.team_league_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_team_league_result_audits_actor_id ON public.team_league_result_audits(actor_id);
CREATE INDEX IF NOT EXISTS idx_team_league_result_audits_championship_id ON public.team_league_result_audits(championship_id);
CREATE INDEX IF NOT EXISTS idx_team_league_result_audits_team_id ON public.team_league_result_audits(team_id);
CREATE INDEX IF NOT EXISTS idx_tournament_matches_dispute_resolved_by ON public.tournament_matches(dispute_resolved_by);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_cancellation_refund_queue_order_id ON public.vsp_1v1_cancellation_refund_queue(order_id);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_cancellation_refund_queue_tournament_id ON public.vsp_1v1_cancellation_refund_queue(tournament_id);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_cancellation_refund_queue_user_id ON public.vsp_1v1_cancellation_refund_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_tournaments_champion_player_id ON public.vsp_1v1_tournaments(champion_player_id);
