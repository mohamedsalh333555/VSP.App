-- Migration: 202609050004_phase3_optimize_rls_auth_uid_subqueries.sql
-- Description: Optimize RLS policies by replacing auth.uid() with (select auth.uid()) for query performance.

DROP POLICY IF EXISTS "Admins full access" ON public."app_config";
CREATE POLICY "Admins full access" ON public."app_config" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "admin_manage_app_config" ON public."app_config";
CREATE POLICY "admin_manage_app_config" ON public."app_config" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Admins full access" ON public."app_settings";
CREATE POLICY "Admins full access" ON public."app_settings" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "app_settings_admin_manage" ON public."app_settings";
CREATE POLICY "app_settings_admin_manage" ON public."app_settings" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Admins have full access to banners" ON public."banners";
CREATE POLICY "Admins have full access to banners" ON public."banners" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'cofounder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'cofounder'::text]))))));

DROP POLICY IF EXISTS "booking_players_select_policy" ON public."booking_players";
CREATE POLICY "booking_players_select_policy" ON public."booking_players" AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = booking_players.booking_id) AND ((b.owner_id = (select auth.uid())) OR (b.created_by_user_id = (select auth.uid())) OR ((select auth.uid()) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."bookings";
CREATE POLICY "Admins full access" ON public."bookings" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "bookings_delete_secure" ON public."bookings";
CREATE POLICY "bookings_delete_secure" ON public."bookings" AS PERMISSIVE FOR DELETE TO authenticated USING ((((status = 'pending'::text) AND (((select auth.uid()) = created_by_user_id) OR ((select auth.uid()) = owner_id))) OR ((payment_transaction_id ~~ 'MANUAL%'::text) AND ((select auth.uid()) = owner_id)) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "bookings_insert_secure" ON public."bookings";
CREATE POLICY "bookings_insert_secure" ON public."bookings" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((((select auth.uid()) = created_by_user_id) OR ((select auth.uid()) = owner_id)) AND ((is_paid = false) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))));

DROP POLICY IF EXISTS "bookings_select_unified" ON public."bookings";
CREATE POLICY "bookings_select_unified" ON public."bookings" AS PERMISSIVE FOR SELECT TO public USING ((((select auth.uid()) = user_id) OR ((select auth.uid()) = owner_id) OR ((select auth.uid()) = created_by_user_id) OR (is_private = false) OR ((select auth.uid()) = ANY (COALESCE(joined_user_ids, ARRAY[]::uuid[])))));

DROP POLICY IF EXISTS "bookings_update_secure" ON public."bookings";
CREATE POLICY "bookings_update_secure" ON public."bookings" AS PERMISSIVE FOR UPDATE TO authenticated USING ((((select auth.uid()) = user_id) OR ((select auth.uid()) = owner_id) OR ((select auth.uid()) = created_by_user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK ((((select auth.uid()) = user_id) OR ((select auth.uid()) = owner_id) OR ((select auth.uid()) = created_by_user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "challenge_results_insert" ON public."challenge_results";
CREATE POLICY "challenge_results_insert" ON public."challenge_results" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((((select auth.uid())::text = submitted_by) AND (confirmed_by IS NULL) AND (status = 'pending'::text)));

DROP POLICY IF EXISTS "challenge_results_update" ON public."challenge_results";
CREATE POLICY "challenge_results_update" ON public."challenge_results" AS PERMISSIVE FOR UPDATE TO authenticated USING (((((select auth.uid())::text = submitted_by) AND (status = 'pending'::text)) OR ((status = 'pending'::text) AND (confirmed_by IS NULL) AND ((select auth.uid())::text <> submitted_by)) OR ((select auth.uid())::text = confirmed_by))) WITH CHECK ((((status = 'confirmed'::text) AND ((select auth.uid())::text = confirmed_by) AND ((select auth.uid())::text <> submitted_by)) OR ((status = 'pending'::text) AND ((select auth.uid())::text = submitted_by))));

DROP POLICY IF EXISTS "roster_guests_manage_policy" ON public."championship_roster_guests";
CREATE POLICY "roster_guests_manage_policy" ON public."championship_roster_guests" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = (select auth.uid())) OR (c.owner_id = (select auth.uid())) OR (( SELECT users.role
           FROM users
          WHERE (users.id = (select auth.uid()))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_guests.roster_id) AND ((t.captain_id = (select auth.uid())) OR (c.owner_id = (select auth.uid())) OR (( SELECT users.role
           FROM users
          WHERE (users.id = (select auth.uid()))) = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "roster_players_manage_policy" ON public."championship_roster_players";
CREATE POLICY "roster_players_manage_policy" ON public."championship_roster_players" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = (select auth.uid())) OR (c.owner_id = (select auth.uid())) OR (( SELECT users.role
           FROM users
          WHERE (users.id = (select auth.uid()))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((championship_rosters cr
     JOIN teams t ON ((t.id = cr.team_id)))
     JOIN championships c ON ((c.id = cr.championship_id)))
  WHERE ((cr.id = championship_roster_players.roster_id) AND ((t.captain_id = (select auth.uid())) OR (c.owner_id = (select auth.uid())) OR (( SELECT users.role
           FROM users
          WHERE (users.id = (select auth.uid()))) = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "championship_rosters_manage_secure" ON public."championship_rosters";
CREATE POLICY "championship_rosters_manage_secure" ON public."championship_rosters" AS PERMISSIVE FOR ALL TO authenticated USING (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM teams t
  WHERE ((t.id = championship_rosters.team_id) AND (t.captain_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = championship_rosters.championship_id) AND (c.owner_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."championships";
CREATE POLICY "Admins full access" ON public."championships" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "championships_admin_manage" ON public."championships";
CREATE POLICY "championships_admin_manage" ON public."championships" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "championships_insert" ON public."championships";
CREATE POLICY "championships_insert" ON public."championships" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "championships_update_own" ON public."championships";
CREATE POLICY "championships_update_own" ON public."championships" AS PERMISSIVE FOR UPDATE TO authenticated USING (((select auth.uid()) = owner_id)) WITH CHECK (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "chat_messages_insert" ON public."chat_messages";
CREATE POLICY "chat_messages_insert" ON public."chat_messages" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((((select auth.uid()) = sender_id) AND ((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND (((select auth.uid()) = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = (select auth.uid())) OR (b.owner_id = (select auth.uid())) OR (b.created_by_user_id = (select auth.uid())) OR ((select auth.uid()) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))))));

DROP POLICY IF EXISTS "chat_messages_select" ON public."chat_messages";
CREATE POLICY "chat_messages_select" ON public."chat_messages" AS PERMISSIVE FOR SELECT TO authenticated USING (((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND (((select auth.uid()) = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = (select auth.uid())) OR (b.owner_id = (select auth.uid())) OR (b.created_by_user_id = (select auth.uid())) OR ((select auth.uid()) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))))))));

DROP POLICY IF EXISTS "conversations_modify_unified" ON public."conversations";
CREATE POLICY "conversations_modify_unified" ON public."conversations" AS PERMISSIVE FOR ALL TO authenticated USING ((((select auth.uid()) = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR ((select auth.uid()) = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id))))) WITH CHECK ((((select auth.uid()) = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR ((select auth.uid()) = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id)))));

DROP POLICY IF EXISTS "conversations_select_unified" ON public."conversations";
CREATE POLICY "conversations_select_unified" ON public."conversations" AS PERMISSIVE FOR SELECT TO authenticated USING ((((select auth.uid()) = ANY (participant_ids)) OR ((type = 'support'::text) AND (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) OR ((select auth.uid()) = ( SELECT b.owner_id
   FROM bookings b
  WHERE (b.id = conversations.booking_id)))));

DROP POLICY IF EXISTS "financial_logs_admin_all" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_admin_all" ON public."financial_audit_logs" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "financial_logs_owner_select" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_owner_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((owner_id = (select auth.uid())));

DROP POLICY IF EXISTS "financial_logs_user_select" ON public."financial_audit_logs";
CREATE POLICY "financial_logs_user_select" ON public."financial_audit_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = (select auth.uid())));

DROP POLICY IF EXISTS "Server and booking host can manage matchup teams" ON public."matchup_teams";
CREATE POLICY "Server and booking host can manage matchup teams" ON public."matchup_teams" AS PERMISSIVE FOR ALL TO authenticated USING ((((select auth.uid()) = added_by_user_id) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = matchup_teams.booking_id) AND ((b.created_by_user_id = (select auth.uid())) OR (b.user_id = (select auth.uid()))))))));

DROP POLICY IF EXISTS "Admins full access" ON public."notifications";
CREATE POLICY "Admins full access" ON public."notifications" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "notifications_delete" ON public."notifications";
CREATE POLICY "notifications_delete" ON public."notifications" AS PERMISSIVE FOR DELETE TO authenticated USING (((select auth.uid()) = user_id));

DROP POLICY IF EXISTS "notifications_insert_secure" ON public."notifications";
CREATE POLICY "notifications_insert_secure" ON public."notifications" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))) OR (user_id = (select auth.uid())) OR ((booking_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = notifications.booking_id) AND ((b.user_id = (select auth.uid())) OR (b.owner_id = (select auth.uid())) OR (b.created_by_user_id = (select auth.uid())) OR ((select auth.uid()) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))))));

DROP POLICY IF EXISTS "notifications_select_own" ON public."notifications";
CREATE POLICY "notifications_select_own" ON public."notifications" AS PERMISSIVE FOR SELECT TO authenticated USING (((select auth.uid()) = user_id));

DROP POLICY IF EXISTS "Admins full access" ON public."payout_settlements";
CREATE POLICY "Admins full access" ON public."payout_settlements" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "payout_settlements_insert_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_insert_policy" ON public."payout_settlements" AS PERMISSIVE FOR INSERT TO public WITH CHECK (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "payout_settlements_select_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_select_policy" ON public."payout_settlements" AS PERMISSIVE FOR SELECT TO public USING ((((select auth.uid()) = owner_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "payout_settlements_update_policy" ON public."payout_settlements";
CREATE POLICY "payout_settlements_update_policy" ON public."payout_settlements" AS PERMISSIVE FOR UPDATE TO public USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "promotions_admin_manage" ON public."promotions";
CREATE POLICY "promotions_admin_manage" ON public."promotions" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Admins full access" ON public."reports";
CREATE POLICY "Admins full access" ON public."reports" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_admin_delete" ON public."reports";
CREATE POLICY "reports_admin_delete" ON public."reports" AS PERMISSIVE FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_admin_select" ON public."reports";
CREATE POLICY "reports_admin_select" ON public."reports" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "reports_insert_auth" ON public."reports";
CREATE POLICY "reports_insert_auth" ON public."reports" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((select auth.uid()) = reporter_id));

DROP POLICY IF EXISTS "reviews_insert" ON public."reviews";
CREATE POLICY "reviews_insert" ON public."reviews" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((((select auth.uid()) = user_id) AND ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.stadium_id = reviews.stadium_id) AND ((b.user_id = (select auth.uid())) OR (b.created_by_user_id = (select auth.uid()))) AND (b.status = 'confirmed'::text)))))));

DROP POLICY IF EXISTS "stadium_custom_rates_manage_own" ON public."stadium_custom_rates";
CREATE POLICY "stadium_custom_rates_manage_own" ON public."stadium_custom_rates" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM stadiums
  WHERE ((stadiums.id = stadium_custom_rates.stadium_id) AND ((stadiums.owner_id = (select auth.uid())) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM stadiums
  WHERE ((stadiums.id = stadium_custom_rates.stadium_id) AND ((stadiums.owner_id = (select auth.uid())) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

DROP POLICY IF EXISTS "Admins full access" ON public."stadiums";
CREATE POLICY "Admins full access" ON public."stadiums" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "stadiums_delete_own" ON public."stadiums";
CREATE POLICY "stadiums_delete_own" ON public."stadiums" AS PERMISSIVE FOR DELETE TO authenticated USING (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "stadiums_insert_own" ON public."stadiums";
CREATE POLICY "stadiums_insert_own" ON public."stadiums" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "stadiums_select_public" ON public."stadiums";
CREATE POLICY "stadiums_select_public" ON public."stadiums" AS PERMISSIVE FOR SELECT TO public USING ((((is_verified = true) AND (is_blocked = false) AND (is_deleted_by_owner = false)) OR ((select auth.uid()) = owner_id)));

DROP POLICY IF EXISTS "stadiums_update_own" ON public."stadiums";
CREATE POLICY "stadiums_update_own" ON public."stadiums" AS PERMISSIVE FOR UPDATE TO authenticated USING (((select auth.uid()) = owner_id)) WITH CHECK (((select auth.uid()) = owner_id));

DROP POLICY IF EXISTS "team_members_delete" ON public."team_members";
CREATE POLICY "team_members_delete" ON public."team_members" AS PERMISSIVE FOR DELETE TO authenticated USING (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = (select auth.uid())))))));

DROP POLICY IF EXISTS "team_members_insert" ON public."team_members";
CREATE POLICY "team_members_insert" ON public."team_members" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM teams
  WHERE ((teams.id = team_members.team_id) AND (teams.captain_id = (select auth.uid()))))));

DROP POLICY IF EXISTS "teams_delete_own" ON public."teams";
CREATE POLICY "teams_delete_own" ON public."teams" AS PERMISSIVE FOR DELETE TO authenticated USING (((select auth.uid()) = captain_id));

DROP POLICY IF EXISTS "teams_insert" ON public."teams";
CREATE POLICY "teams_insert" ON public."teams" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((select auth.uid()) = captain_id));

DROP POLICY IF EXISTS "teams_update_own" ON public."teams";
CREATE POLICY "teams_update_own" ON public."teams" AS PERMISSIVE FOR UPDATE TO authenticated USING (((select auth.uid()) = captain_id)) WITH CHECK (((select auth.uid()) = captain_id));

DROP POLICY IF EXISTS "Admins full access" ON public."tournament_matches";
CREATE POLICY "Admins full access" ON public."tournament_matches" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "tournament_matches_insert" ON public."tournament_matches";
CREATE POLICY "tournament_matches_insert" ON public."tournament_matches" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_matches.championship_id) AND ((c.owner_id = (select auth.uid())) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

DROP POLICY IF EXISTS "tournament_orders_insert_policy" ON public."tournament_orders";
CREATE POLICY "tournament_orders_insert_policy" ON public."tournament_orders" AS PERMISSIVE FOR INSERT TO public WITH CHECK (((select auth.uid()) = captain_user_id));

DROP POLICY IF EXISTS "tournament_orders_select_policy" ON public."tournament_orders";
CREATE POLICY "tournament_orders_select_policy" ON public."tournament_orders" AS PERMISSIVE FOR SELECT TO public USING ((((select auth.uid()) = captain_user_id) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_orders.championship_id) AND (c.owner_id = (select auth.uid()))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "Admins full access" ON public."transactions";
CREATE POLICY "Admins full access" ON public."transactions" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Admins have full access to transactions" ON public."transactions";
CREATE POLICY "Admins have full access to transactions" ON public."transactions" AS PERMISSIVE FOR ALL TO public USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "Users can view own transactions" ON public."transactions";
CREATE POLICY "Users can view own transactions" ON public."transactions" AS PERMISSIVE FOR SELECT TO public USING (((select auth.uid()) = user_id));

DROP POLICY IF EXISTS "transactions_insert_policy" ON public."transactions";
CREATE POLICY "transactions_insert_policy" ON public."transactions" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((((select auth.uid()) = user_id) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

DROP POLICY IF EXISTS "transactions_select_policy" ON public."transactions";
CREATE POLICY "transactions_select_policy" ON public."transactions" AS PERMISSIVE FOR SELECT TO authenticated USING (((user_id = (select auth.uid())) OR (EXISTS ( SELECT 1
   FROM (stadiums s
     JOIN bookings b ON ((b.stadium_id = s.id)))
  WHERE ((b.id = transactions.booking_id) AND (s.owner_id = (select auth.uid()))))) OR (( SELECT users.role
   FROM users
  WHERE (users.id = (select auth.uid()))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))));

DROP POLICY IF EXISTS "users_delete_policy" ON public."users";
CREATE POLICY "users_delete_policy" ON public."users" AS PERMISSIVE FOR DELETE TO authenticated USING (((select auth.uid()) = id));

DROP POLICY IF EXISTS "users_insert_policy" ON public."users";
CREATE POLICY "users_insert_policy" ON public."users" AS PERMISSIVE FOR INSERT TO public WITH CHECK ((((select auth.uid()) = id) OR (auth.role() = 'anon'::text) OR (auth.role() = 'service_role'::text)));

DROP POLICY IF EXISTS "users_select_policy" ON public."users";
CREATE POLICY "users_select_policy" ON public."users" AS PERMISSIVE FOR SELECT TO public USING (((auth.role() = 'service_role'::text) OR (((select auth.uid()) IS NOT NULL) AND ((select auth.uid()) = id)) OR (((select auth.uid()) IS NOT NULL) AND (is_blocked = false))));

DROP POLICY IF EXISTS "users_update_policy" ON public."users";
CREATE POLICY "users_update_policy" ON public."users" AS PERMISSIVE FOR UPDATE TO authenticated USING (((select auth.uid()) = id)) WITH CHECK (((select auth.uid()) = id));

DROP POLICY IF EXISTS "Admins full access" ON public."vsp_1v1_registrations";
CREATE POLICY "Admins full access" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "vsp_1v1_registrations_insert" ON public."vsp_1v1_registrations";
CREATE POLICY "vsp_1v1_registrations_insert" ON public."vsp_1v1_registrations" AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((select auth.uid()) = user_id));

DROP POLICY IF EXISTS "Admins full access" ON public."vsp_1vs1_players";
CREATE POLICY "Admins full access" ON public."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "admin_manage_1v1_players" ON public."vsp_1vs1_players";
CREATE POLICY "admin_manage_1v1_players" ON public."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "webhook_logs_admin_only" ON public."webhook_logs";
CREATE POLICY "webhook_logs_admin_only" ON public."webhook_logs" AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = (select auth.uid())) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

DROP POLICY IF EXISTS "webhook_logs_admin_select" ON public."webhook_logs";
CREATE POLICY "webhook_logs_admin_select" ON public."webhook_logs" AS PERMISSIVE FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = (select auth.uid())) AND (u.role = 'admin'::text)))));
