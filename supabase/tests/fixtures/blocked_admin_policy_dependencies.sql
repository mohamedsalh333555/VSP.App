-- TEST ONLY: metadata-based dependency fixture; not production schema/replay.

CREATE SCHEMA storage;

GRANT USAGE ON SCHEMA storage TO anon,authenticated,service_role;

CREATE TABLE "public"."ai_copilot_audit_events" ("id" uuid,
"request_id" uuid,
"conversation_id" uuid,
"user_id" uuid,
"user_role" text,
"event_type" text,
"capability_id" text,
"tool_name" text,
"action_type" text,
"status" text,
"verified" boolean,
"verification_source" text,
"error_code" text,
"request_hash" text,
"latency_ms" integer,
"metadata" jsonb,
"created_at" timestamp with time zone);

CREATE TABLE "public"."app_config" ("id" integer,
"is_maintenance" boolean,
"min_version" text,
"created_at" timestamp with time zone,
"vsp_1v1_is_open" boolean,
"vsp_1v1_link" text);

CREATE TABLE "public"."app_settings" ("id" uuid,
"support_phone" text,
"whatsapp_number" text,
"support_email" text,
"vodafone_cash_number" text,
"instapay_handle" text,
"cash_booking_enabled" boolean,
"online_payment_enabled" boolean,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone);

CREATE TABLE "public"."league_settings" ("id" uuid,
"setting_key" text,
"setting_value" text,
"description" text,
"updated_at" timestamp with time zone);

CREATE TABLE "public"."match_score_edits" ("id" uuid,
"match_id" uuid,
"championship_id" uuid,
"old_score_home" integer,
"old_score_away" integer,
"old_penalties_home" integer,
"old_penalties_away" integer,
"new_score_home" integer,
"new_score_away" integer,
"new_penalties_home" integer,
"new_penalties_away" integer,
"edited_by" uuid,
"edit_reason" text,
"created_at" timestamp with time zone);

CREATE TABLE "public"."owner_documents" ("id" uuid,
"owner_id" uuid,
"document_type" text,
"file_url" text,
"storage_path" text,
"status" text,
"rejection_reason" text,
"metadata" jsonb,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone);

CREATE TABLE "public"."platform_business_rules" ("id" bigint,
"booking_min_duration_minutes" integer,
"booking_max_duration_hours" numeric(6,2),
"manual_booking_max_duration_hours" numeric(6,2),
"payment_lock_minutes" integer,
"booking_past_grace_minutes" integer,
"cash_no_show_limit" integer,
"default_cash_debt_limit" numeric(12,2),
"player_cancellation_grace_minutes" integer,
"player_cancellation_cutoff_hours" numeric(6,2),
"late_cancellation_cutoff_hours" numeric(6,2),
"updated_at" timestamp with time zone);

CREATE TABLE "public"."rate_limit_logs" ("id" uuid,
"user_id" uuid,
"action" text,
"created_at" timestamp with time zone);

CREATE TABLE "public"."tournament_matches" ("id" uuid,
"championship_id" uuid,
"round_index" integer,
"match_index" integer,
"home_team_id" uuid,
"home_team_name" text,
"away_team_id" uuid,
"away_team_name" text,
"home_score" integer,
"away_score" integer,
"winner_id" uuid,
"next_match_id" uuid,
"scheduled_time" timestamp with time zone,
"goal_details" jsonb,
"clean_sheets" jsonb,
"mvp_player" text,
"status" text,
"is_completed" boolean,
"winner_name" text,
"group_name" text,
"week_number" integer,
"stage" text,
"home_penalties" integer,
"away_penalties" integer,
"submitted_at" timestamp with time zone,
"updated_at" timestamp with time zone,
"booking_id" uuid,
"stadium_name" text,
"is_forfeit" boolean,
"forfeit_team_id" uuid,
"result_status" text,
"result_confirmed_at" timestamp with time zone,
"result_locked_at" timestamp with time zone,
"dispute_created_at" timestamp with time zone,
"dispute_resolved_at" timestamp with time zone,
"dispute_resolved_by" uuid,
"confirmed_outcome" text,
"match_day" date);

CREATE TABLE "public"."vsp_1v1_registrations" ("id" uuid,
"user_id" uuid,
"status" text,
"created_at" timestamp with time zone);

CREATE TABLE "public"."vsp_1v1_tournament_players" ("id" uuid,
"tournament_id" uuid,
"user_id" uuid,
"player_name" text,
"avatar_url" text,
"tackles" integer,
"goals" integer,
"skills" integer,
"total_points" integer,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone,
"registered_at" timestamp with time zone,
"payment_status" text,
"payment_order_id" uuid,
"paid_amount" numeric(10,2),
"rounds_played" integer);

CREATE TABLE "public"."vsp_1vs1_players" ("id" uuid,
"name" text,
"avatar_url" text,
"total_points" integer,
"skill_points" integer,
"goals" integer,
"tackles" integer,
"titles" integer,
"trend" text,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone,
"round_reached" text);

CREATE TABLE "public"."webhook_logs" ("id" uuid,
"provider" text,
"event_type" text,
"txn_id" text,
"order_id" text,
"booking_id" uuid,
"payload" jsonb,
"signature_verified" boolean,
"status" text,
"error_message" text,
"created_at" timestamp with time zone);

CREATE TABLE "storage"."objects" ("id" uuid,
"bucket_id" text,
"name" text,
"owner" uuid,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone,
"last_accessed_at" timestamp with time zone,
"metadata" jsonb,
"path_tokens" text[],
"version" text,
"owner_id" text,
"user_metadata" jsonb,
"archived_at" timestamp with time zone,
"is_delete_marker" boolean,
"is_versioned" boolean);

CREATE FUNCTION storage.foldername(name text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $$ SELECT (string_to_array(name,'/'))[1:array_length(string_to_array(name,'/'),1)-1]; $$;

CREATE OR REPLACE FUNCTION public.are_users_blocked(p_user_a uuid, p_user_b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select exists (
    select 1 from public.user_blocks ub
    where (ub.blocker_id=p_user_a and ub.blocked_user_id=p_user_b)
       or (ub.blocker_id=p_user_b and ub.blocked_user_id=p_user_a)
  )
  and auth.uid() is not null
  and (auth.uid()=p_user_a or auth.uid()=p_user_b);
$function$;

REVOKE ALL ON FUNCTION public.are_users_blocked(uuid,uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.are_users_blocked(uuid,uuid) TO authenticated,service_role;

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "owner_documents_owner_manage" ON "storage"."objects" AS PERMISSIVE FOR ALL TO "authenticated" USING (((bucket_id = 'owner_documents'::text) AND (((auth.uid())::text = (storage.foldername(name))[1]) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])))))))) WITH CHECK (((bucket_id = 'owner_documents'::text) AND (((auth.uid())::text = (storage.foldername(name))[1]) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Owner access own documents or Admin" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'owner_documents'::text) AND (((auth.uid())::text = (storage.foldername(name))[1]) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Admin Upload Access for Banner Images" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((bucket_id = 'banners'::text) AND (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))));

ALTER TABLE "public"."chat_messages" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."chat_messages" TO authenticated;

CREATE POLICY "chat_messages_select" ON "public"."chat_messages" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((((EXISTS ( SELECT 1
   FROM conversations c
  WHERE ((c.id = chat_messages.conversation_id) AND ((( SELECT ( SELECT auth.uid() AS uid) AS uid) = ANY (c.participant_ids)) OR ((c.type = 'support'::text) AND (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))))))) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = chat_messages.booking_id) AND ((b.user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (b.owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (b.created_by_user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT ( SELECT auth.uid() AS uid) AS uid) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[])))))))) AND (NOT (EXISTS ( SELECT 1
   FROM (conversations c
     CROSS JOIN LATERAL unnest(COALESCE(c.participant_ids, ARRAY[]::uuid[])) partner_id(partner_id))
  WHERE ((c.id = chat_messages.conversation_id) AND (partner_id.partner_id <> ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND are_users_blocked(( SELECT ( SELECT auth.uid() AS uid) AS uid), partner_id.partner_id)))))));

ALTER TABLE "public"."owner_documents" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."owner_documents" TO authenticated;

CREATE POLICY "owner_documents_owner_insert" ON "public"."owner_documents" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))));

ALTER TABLE "public"."owner_documents" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."owner_documents" TO authenticated;

CREATE POLICY "owner_documents_owner_select" ON "public"."owner_documents" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((owner_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) OR (( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Admin Modify Access for Banner Images" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((bucket_id = 'banners'::text) AND (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Admin Delete Access for Banner Images" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((bucket_id = 'banners'::text) AND (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Owner delete own stadium images" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((bucket_id = 'stadium-images'::text) AND ((auth.uid() = owner) OR ((storage.foldername(name))[1] = (auth.uid())::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))))))));

ALTER TABLE "public"."vsp_1v1_tournaments" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_tournaments" TO authenticated;

CREATE POLICY "Admins manage tournaments" ON "public"."vsp_1v1_tournaments" AS PERMISSIVE FOR ALL TO PUBLIC USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text])));

ALTER TABLE "public"."owner_documents" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."owner_documents" TO authenticated;

CREATE POLICY "owner_documents_admin_update" ON "public"."owner_documents" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

ALTER TABLE "public"."owner_documents" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."owner_documents" TO authenticated;

CREATE POLICY "owner_documents_admin_delete" ON "public"."owner_documents" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "secure_owner_docs_read" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'owner_documents'::text) AND (((auth.uid())::text = (storage.foldername(name))[1]) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "secure_deposit_receipts_read" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'deposit-receipts'::text) AND (((auth.uid())::text = (storage.foldername(name))[1]) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))));

ALTER TABLE "public"."match_score_edits" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."match_score_edits" TO authenticated;

CREATE POLICY "owner_can_read_own_edits" ON "public"."match_score_edits" AS PERMISSIVE FOR SELECT TO PUBLIC USING (((championship_id IN ( SELECT championships.id
   FROM championships
  WHERE (championships.owner_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))));

ALTER TABLE "public"."league_settings" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."league_settings" TO authenticated;

CREATE POLICY "Allow admins to manage league_settings" ON "public"."league_settings" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))))));

ALTER TABLE "public"."vsp_1v1_tournament_orders" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_tournament_orders" TO authenticated;

CREATE POLICY "Service role and atomic functions manage 1v1 orders" ON "public"."vsp_1v1_tournament_orders" AS PERMISSIVE FOR ALL TO "authenticated","service_role" USING (((COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))) WITH CHECK (((COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

ALTER TABLE "public"."vsp_1v1_tournament_orders" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_tournament_orders" TO authenticated;

CREATE POLICY "Users and admins can view 1v1 orders" ON "public"."vsp_1v1_tournament_orders" AS PERMISSIVE FOR SELECT TO "authenticated","service_role" USING (((( SELECT ( SELECT auth.uid() AS uid) AS uid) = user_id) OR (COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

ALTER TABLE "public"."webhook_logs" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."webhook_logs" TO authenticated;

CREATE POLICY "webhook_logs_admin_select" ON "public"."webhook_logs" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = 'admin'::text)))));

ALTER TABLE "public"."vsp_1v1_tournament_players" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_tournament_players" TO authenticated;

CREATE POLICY "Anyone can view tournament players" ON "public"."vsp_1v1_tournament_players" AS PERMISSIVE FOR SELECT TO "anon","authenticated" USING (((payment_status = 'paid'::text) OR ((( SELECT ( SELECT auth.uid() AS uid) AS uid) IS NOT NULL) AND (user_id = ( SELECT ( SELECT auth.uid() AS uid) AS uid))) OR (COALESCE(( SELECT ( SELECT auth.role() AS role) AS role), ''::text) = 'service_role'::text) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

ALTER TABLE "public"."championships" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."championships" TO authenticated;

CREATE POLICY "championships_insert" ON "public"."championships" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = owner_id) AND (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['owner'::text, 'admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))))) AND ((is_approved IS NOT TRUE) OR (EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))))))));

ALTER TABLE "public"."ai_copilot_audit_events" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."ai_copilot_audit_events" TO authenticated;

CREATE POLICY "Admins can view AI Copilot audit" ON "public"."ai_copilot_audit_events" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."championships" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."championships" TO authenticated;

CREATE POLICY "championships_admin_manage_all" ON "public"."championships" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))))));

ALTER TABLE "public"."vsp_1v1_tournament_players" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_tournament_players" TO authenticated;

CREATE POLICY "Admins manage tournament players" ON "public"."vsp_1v1_tournament_players" AS PERMISSIVE FOR ALL TO PUBLIC USING ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text]))) WITH CHECK ((( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))) = ANY (ARRAY['admin'::text, 'co_founder'::text])));

ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."app_settings" TO authenticated;

CREATE POLICY "app_settings_admin_manage" ON "public"."app_settings" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."app_config" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."app_config" TO authenticated;

CREATE POLICY "admin_manage_app_config" ON "public"."app_config" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."rate_limit_logs" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."rate_limit_logs" TO authenticated;

CREATE POLICY "rate_limit_admin_manage" ON "public"."rate_limit_logs" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT auth.uid() AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."booking_players" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."booking_players" TO authenticated;

CREATE POLICY "booking_players_select_policy" ON "public"."booking_players" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (EXISTS ( SELECT 1
   FROM bookings b
  WHERE ((b.id = booking_players.booking_id) AND ((b.owner_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (b.created_by_user_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid) = ANY (COALESCE(b.joined_user_ids, ARRAY[]::uuid[]))))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))));

ALTER TABLE "public"."platform_business_rules" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."platform_business_rules" TO authenticated;

CREATE POLICY "platform_business_rules_admin_write" ON "public"."platform_business_rules" AS PERMISSIVE FOR ALL TO "authenticated" USING ((COALESCE(( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))), ''::text) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))) WITH CHECK ((COALESCE(( SELECT users.role
   FROM users
  WHERE (users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid))), ''::text) = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])));

ALTER TABLE "public"."tournament_orders" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."tournament_orders" TO authenticated;

CREATE POLICY "tournament_orders_owner_select" ON "public"."tournament_orders" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((captain_user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_orders.championship_id) AND (c.owner_id = ( SELECT auth.uid() AS uid))))) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])))))));

ALTER TABLE "storage"."objects" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "storage"."objects" TO authenticated;

CREATE POLICY "Owner update own stadium images" ON "storage"."objects" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((bucket_id = 'stadium-images'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (owner = auth.uid()) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text])))))))) WITH CHECK (((bucket_id = 'stadium-images'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (owner = auth.uid()) OR (EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = auth.uid()) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'cofounder'::text, 'super_admin'::text]))))))));

ALTER TABLE "public"."tournament_matches" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."tournament_matches" TO authenticated;

CREATE POLICY "Admins full access" ON "public"."tournament_matches" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."tournament_matches" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."tournament_matches" TO authenticated;

CREATE POLICY "tournament_matches_insert" ON "public"."tournament_matches" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM championships c
  WHERE ((c.id = tournament_matches.championship_id) AND ((c.owner_id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) OR (EXISTS ( SELECT 1
           FROM users u
          WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))))))));

ALTER TABLE "public"."vsp_1v1_registrations" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1v1_registrations" TO authenticated;

CREATE POLICY "Admins full access" ON "public"."vsp_1v1_registrations" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."webhook_logs" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."webhook_logs" TO authenticated;

CREATE POLICY "webhook_logs_admin_only" ON "public"."webhook_logs" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."vsp_1vs1_players" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."vsp_1vs1_players" TO authenticated;

CREATE POLICY "admin_manage_1v1_players" ON "public"."vsp_1vs1_players" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text])))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM users u
  WHERE ((u.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (u.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

ALTER TABLE "public"."reports" ENABLE ROW LEVEL SECURITY;

GRANT SELECT,INSERT,UPDATE,DELETE ON "public"."reports" TO authenticated;

CREATE POLICY "Admins full access" ON "public"."reports" AS PERMISSIVE FOR ALL TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM users
  WHERE ((users.id = ( SELECT ( SELECT ( SELECT auth.uid() AS uid) AS uid) AS uid)) AND (users.role = ANY (ARRAY['admin'::text, 'co_founder'::text]))))));

GRANT SELECT ON public.bookings,public.championships,public.conversations,public.user_blocks TO authenticated;
