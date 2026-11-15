-- RESULT staging metadata preflight. All statements SELECT only; no IDs or PII.
WITH required(table_name,column_name,udt) AS (
  VALUES ('bookings','id','uuid'),('bookings','owner_id','uuid'),
  ('bookings','booking_type','text'),('bookings','status','text'),
  ('bookings','end_time','timestamptz'),('bookings','player_team_id','uuid'),
  ('bookings','opponent_team_id','uuid'),('bookings','pending_outcome','text'),
  ('bookings','match_result_status','text'),('bookings','final_outcome','text'),
  ('bookings','elo_processed','bool'),('bookings','payment_status','text'),
  ('bookings','payment_reconcile_state','text'),('bookings','is_paid','bool'),
  ('bookings','deposit_amount','numeric'),('bookings','deposit_paid','numeric'),
  ('bookings','updated_at','timestamptz'),
  ('teams','id','uuid'),('teams','captain_id','uuid'),
  ('teams','points','int4'),('teams','wins','int4'),('teams','losses','int4'),
  ('teams','draws','int4'),('teams','matches_played','int4'),
  ('users','id','uuid'),('users','role','text')
)
SELECT 'columns' AS section,r.table_name,r.column_name,
  r.udt AS expected_udt,c.udt_name AS actual_udt,
  r.udt=c.udt_name AS type_matches
FROM required r LEFT JOIN information_schema.columns c
  ON c.table_schema='public' AND c.table_name=r.table_name
  AND c.column_name=r.column_name
ORDER BY r.table_name,r.column_name;

SELECT 'legacy_counts' AS section,
  count(*) FILTER (WHERE booking_type='challenge') AS total_challenges,
  count(*) FILTER (WHERE booking_type='challenge'
    AND match_result_status='confirmed' AND final_outcome IS NOT NULL)
    AS legacy_finalized,
  count(*) FILTER (WHERE booking_type='challenge'
    AND match_result_status='waitingOpponent'
    AND (pending_outcome IS NOT NULL OR result_submitted_by_team_id IS NOT NULL))
    AS legacy_single_votes_to_migrate,
  count(*) FILTER (WHERE booking_type='challenge'
    AND match_result_status='confirmed' AND pending_outcome IS NOT NULL)
    AS legacy_confirmed_with_pending_data,
  count(*) FILTER (WHERE booking_type='challenge'
    AND elo_processed IS TRUE AND match_result_status IS DISTINCT FROM 'confirmed')
    AS ranked_without_result
FROM public.bookings;

SELECT 'field_exposure' AS section,
  has_column_privilege('authenticated','public.bookings','pending_outcome','SELECT')
    AS auth_can_read_legacy_outcome,
  has_column_privilege('anon','public.bookings','pending_outcome','SELECT')
    AS anon_can_read_legacy_outcome,
  has_table_privilege('authenticated',
    to_regclass('public.challenge_captain_result_entries'),'SELECT')
    AS auth_can_read_private_votes,
  has_table_privilege('authenticated',
    to_regclass('public.challenge_non_played_reports'),'SELECT')
    AS auth_can_read_private_reports,
  has_table_privilege('authenticated',
    to_regclass('public.challenge_non_played_appeals'),'SELECT')
    AS auth_can_read_private_appeals;

SELECT 'relevant_functions' AS section,p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,p.prosecdef AS definer,
  md5(pg_get_functiondef(p.oid)) AS definition_md5,
  has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') AS auth_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN (
  'submit_challenge_result_atomic',
  'get_my_challenge_result_submission',
  'owner_report_challenge_not_played_atomic',
  'captain_appeal_challenge_non_played_atomic',
  'review_challenge_non_played_atomic',
  'get_my_challenge_non_played_status',
  'calculate_elo_on_match_completion',
  'normalize_booking_pending_fees',
  'sync_booking_public_feed',
  'owner_record_no_show_atomic',
  'auto_reconcile_single_entry_results',
  'auto_approve_challenge_matches_24h')
ORDER BY p.proname;

SELECT 'trigger_inventory' AS section,t.tgname,t.tgenabled,
  t.tgfoid::regprocedure::text AS function
FROM pg_trigger t
WHERE t.tgrelid='public.bookings'::regclass
  AND NOT t.tgisinternal
  AND (t.tgname ILIKE '%elo%' OR t.tgname ILIKE '%fee%'
   OR t.tgname ILIKE '%feed%' OR t.tgname ILIKE '%booking%'
   OR t.tgname ILIKE '%protect%' OR t.tgname ILIKE '%state%')
ORDER BY t.tgname;

SELECT 'related_surfaces' AS section,
  to_regclass('public.booking_public_feed') IS NOT NULL AS public_feed_exists,
  to_regclass('public.challenge_non_played_reports') IS NOT NULL AS report_installed,
  to_regclass('public.challenge_non_played_appeals') IS NOT NULL AS appeal_installed,
  to_regclass('public.challenge_non_played_review_audit') IS NOT NULL AS audit_installed,
  to_regclass('cron.job') IS NOT NULL AS cron_catalog_exists;
