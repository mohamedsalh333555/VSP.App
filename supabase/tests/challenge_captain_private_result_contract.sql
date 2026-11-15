-- Never run on hosted Supabase. Synthetic fixture executed inside a disposable DB.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA auth;
CREATE TABLE public.users (id uuid PRIMARY KEY, role text NOT NULL);
INSERT INTO public.users(id,role) VALUES
('00000000-0000-0000-0000-000000000505','admin'),
('00000000-0000-0000-0000-000000000606','player');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
CREATE TABLE public.teams (
 id uuid PRIMARY KEY, captain_id uuid NOT NULL,
 points integer DEFAULT 0, matches_played integer DEFAULT 0,
 wins integer DEFAULT 0, draws integer DEFAULT 0, losses integer DEFAULT 0,
 updated_at timestamptz DEFAULT now()
);
INSERT INTO public.teams(id,captain_id) VALUES
 ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000202');
CREATE TABLE public.bookings (
 id uuid PRIMARY KEY,
 booking_type text NOT NULL, status text NOT NULL,
 end_time timestamptz NOT NULL,
 owner_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000404',
 player_team_id uuid REFERENCES public.teams(id),
 opponent_team_id uuid REFERENCES public.teams(id),
 match_result_status text NOT NULL DEFAULT 'noResult',
 final_outcome text, pending_outcome text,
 result_submitted_by_team_id uuid,
 requires_admin_intervention boolean DEFAULT false,
 updated_at timestamptz DEFAULT now(),
 payment_status text DEFAULT 'paid',
 payment_reconcile_state text DEFAULT 'settled',
 is_paid boolean DEFAULT true,
 deposit_amount numeric DEFAULT 100,
 deposit_paid numeric DEFAULT 50,
 fair_play_score integer DEFAULT 100,
 elo_processed boolean DEFAULT false
);
INSERT INTO public.bookings(id,booking_type,status,end_time,player_team_id,opponent_team_id)
SELECT ('00000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,
 'challenge','confirmed',now()-interval '2 hours',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000022'
FROM generate_series(1,14) AS i;
UPDATE public.bookings SET end_time=now()+interval '2 hours'
 WHERE id='00000000-0000-0000-0000-000000000004';
UPDATE public.bookings SET status='pending'
 WHERE id='00000000-0000-0000-0000-000000000005';

-- Synthetic installed booking guard: ordinary result writes are prohibited.
CREATE FUNCTION public.vsp_test_result_write_guard() RETURNS trigger
LANGUAGE plpgsql AS $guard$
BEGIN
 IF (OLD.status IS DISTINCT FROM NEW.status
     OR OLD.match_result_status IS DISTINCT FROM NEW.match_result_status
     OR OLD.final_outcome IS DISTINCT FROM NEW.final_outcome
     OR OLD.pending_outcome IS DISTINCT FROM NEW.pending_outcome
     OR OLD.result_submitted_by_team_id IS DISTINCT FROM NEW.result_submitted_by_team_id)
    AND coalesce(current_setting('vsp.system_override',true),'') <> 'true' THEN
   RAISE EXCEPTION 'DIRECT_RESULT_WRITE_DENIED';
 END IF;
 RETURN NEW;
END;
$guard$;
CREATE TRIGGER vsp_result_write_guard BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.vsp_test_result_write_guard();

-- Synthetic public booking feed with the same default permissive SELECT
-- shape as staging; only the extra restrictive policy should filter it.
CREATE TABLE public.booking_public_feed (
 id uuid PRIMARY KEY REFERENCES public.bookings(id) ON DELETE CASCADE,
 booking_type text NOT NULL DEFAULT 'challenge',
 match_result_status text NOT NULL DEFAULT 'confirmed'
);
ALTER TABLE public.booking_public_feed ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.booking_public_feed TO authenticated;
CREATE POLICY booking_public_feed_select ON public.booking_public_feed
  FOR SELECT TO authenticated USING (true);

-- INSTALL_CHALLENGE_RANKING_TRIGGER

-- INSTALL_NOT_PLAYED_REPORT_CANDIDATE
-- INSTALL_PRIVATE_RESULTS_CANDIDATE
-- INSTALL_NOT_PLAYED_REVIEW_CANDIDATE
-- INSTALL_NON_PLAYED_FEED_RLS_CANDIDATE
-- INSTALL_ELIGIBLE_CHALLENGE_HEAD_TO_HEAD_CANDIDATE

DO $test$
DECLARE r jsonb; v_id uuid; n int;
BEGIN
 v_id:='00000000-0000-0000-0000-000000000001';
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000011','homeWin');
 IF r->>'state'<>'waitingOpponent' OR r->>'finalized'<>'false'
    OR r::text ILIKE '%homeWin%' THEN
   RAISE EXCEPTION 'First captain submission disclosed outcome or finalized'; END IF;
 IF (SELECT count(*) FROM public.challenge_captain_result_entries WHERE booking_id=v_id)<>1 THEN
   RAISE EXCEPTION 'Missing first independent vote'; END IF;
 IF (SELECT pending_outcome FROM public.bookings WHERE id=v_id) IS NOT NULL THEN
   RAISE EXCEPTION 'Public booking leaks private vote'; END IF;
 IF coalesce(current_setting('vsp.system_override',true),'') <> '' THEN
   RAISE EXCEPTION 'Scoped internal booking override leaked to caller'; END IF;
 -- Retries cannot increment revision or add duplicate audit entries.
 r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000011','homeWin');
 IF (SELECT revision FROM public.challenge_captain_result_entries
     WHERE booking_id=v_id AND team_id='00000000-0000-0000-0000-000000000011')<>1 THEN
   RAISE EXCEPTION 'Idempotent vote replay changed revision'; END IF;

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000022','awayWin');
 IF r->>'state'<>'mismatch' OR r::text ILIKE '%homeWin%' OR r::text ILIKE '%awayWin%' THEN
   RAISE EXCEPTION 'Mismatch finalized or leaked choices'; END IF;
 IF (SELECT match_result_status FROM public.bookings WHERE id=v_id)<>'disputed'
    OR (SELECT final_outcome FROM public.bookings WHERE id=v_id) IS NOT NULL THEN
   RAISE EXCEPTION 'Mismatch changed final result'; END IF;
 IF (SELECT count(DISTINCT outcome) FROM public.challenge_captain_result_entries WHERE booking_id=v_id)<>2 THEN
   RAISE EXCEPTION 'Mismatch overwrote rival vote'; END IF;
 r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000022','homeWin');
 IF r->>'state'<>'confirmed' OR r->>'finalized'<>'true' THEN
   RAISE EXCEPTION 'Agreement did not finalize immediately'; END IF;
 IF (SELECT final_outcome FROM public.bookings WHERE id=v_id)<>'homeWin'
    OR (SELECT status FROM public.bookings WHERE id=v_id)<>'completed' THEN
   RAISE EXCEPTION 'Final outcome not persisted'; END IF;
 IF coalesce(current_setting('vsp.system_override',true),'') <> '' THEN
   RAISE EXCEPTION 'Finalization override leaked to caller'; END IF;
 IF (SELECT revision FROM public.challenge_captain_result_entries
       WHERE booking_id=v_id AND team_id='00000000-0000-0000-0000-000000000022')<>2 THEN
   RAISE EXCEPTION 'Edited vote lost revision'; END IF;
 IF (SELECT count(*) FROM public.challenge_captain_result_audit WHERE booking_id=v_id)<>3 THEN
   RAISE EXCEPTION 'Missing immutable submission audit'; END IF;
 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>3
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>0
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>1
    OR (SELECT elo_processed FROM public.bookings WHERE id=v_id) IS NOT TRUE THEN
   RAISE EXCEPTION 'Rank points not processed exactly once on agreement'; END IF;
 r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000022','homeWin');
 IF r->>'error'<>'RESULT_ALREADY_FINALIZED' THEN
   RAISE EXCEPTION 'Finalization not idempotently protected'; END IF;
 -- All three agreements (home win, draw, away win) and all 6 mismatches.
 FOR n IN 1..9 LOOP
   v_id:=('00000000-0000-0000-0000-' || lpad((n+5)::text,12,'0'))::uuid;
   PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
   r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000011',
     (ARRAY['homeWin','draw','awayWin'])[((n-1)/3)+1]);
   PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
   r:=public.submit_challenge_result_atomic(v_id,'00000000-0000-0000-0000-000000000022',
     (ARRAY['homeWin','draw','awayWin'])[((n-1)%3)+1]);
   IF ((n-1)/3)=((n-1)%3) THEN
     IF r->>'state'<>'confirmed' THEN RAISE EXCEPTION 'Valid agreement failed at %',n; END IF;
   ELSE
     IF r->>'state'<>'mismatch' THEN RAISE EXCEPTION 'Mismatch passed at %',n; END IF;
   END IF;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.submit_challenge_result_atomic('00000000-0000-0000-0000-000000000004',
 '00000000-0000-0000-0000-000000000022','draw');
 IF r->>'error'<>'MATCH_NOT_FINISHED' THEN RAISE EXCEPTION 'Early result accepted'; END IF;
 r:=public.submit_challenge_result_atomic('00000000-0000-0000-0000-000000000005',
 '00000000-0000-0000-0000-000000000022','draw');
 IF r->>'error'<>'BOOKING_NOT_ELIGIBLE' THEN RAISE EXCEPTION 'Unconfirmed booking accepted'; END IF;
 r:=public.submit_challenge_result_atomic('00000000-0000-0000-0000-000000000003',
 '00000000-0000-0000-0000-000000000011','draw');
 IF r->>'error'<>'CAPTAIN_ONLY' THEN RAISE EXCEPTION 'Captain impersonation accepted'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 r:=public.submit_challenge_result_atomic('00000000-0000-0000-0000-000000000003',
 '00000000-0000-0000-0000-000000000011','draw');
 IF r->>'error'<>'AUTHENTICATION_REQUIRED' THEN RAISE EXCEPTION 'Anonymous result accepted'; END IF;
 -- Three finalized fixtures should each award points once: home win 3/0,
 -- draw 1/1, away win 0/3. Booking 1 already awarded 3/0.
 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>7
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>4
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>4
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>4
    OR (SELECT count(*) FROM public.bookings WHERE elo_processed)<>4 THEN
   RAISE EXCEPTION 'Mismatch/finalization corrupted standings or double counted'; END IF;
 IF EXISTS(SELECT 1 FROM public.bookings WHERE pending_outcome IS NOT NULL) THEN
   RAISE EXCEPTION 'Public booking outcome leak'; END IF;
 IF EXISTS(SELECT 1 FROM public.bookings WHERE fair_play_score<>100 OR payment_status<>'paid') THEN
   RAISE EXCEPTION 'Financial or fair-play fields mutated'; END IF;
 IF has_table_privilege('authenticated','public.challenge_captain_result_entries','SELECT')
    OR has_table_privilege('anon','public.challenge_captain_result_entries','SELECT')
    OR has_table_privilege('authenticated','public.challenge_captain_result_audit','SELECT') THEN
   RAISE EXCEPTION 'Private votes exposed to Data API roles'; END IF;
END;
$test$;

-- Private read contract: one captain can read their own vote and cannot read
-- or infer the other vote from this RPC. Audit rows remain hidden to clients.
DO $private_read$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'submitted'<>'false' OR r ? 'my_outcome' THEN
   RAISE EXCEPTION 'Captain received a vote before making a submission'; END IF;
 PERFORM public.submit_challenge_result_atomic(
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000011','awayWin');
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'my_outcome'<>'awayWin' OR r->>'my_revision'<>'1' THEN
   RAISE EXCEPTION 'Own private vote cannot be read correctly'; END IF;

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'submitted'<>'false' OR r ? 'my_outcome' OR r::text ILIKE '%awayWin%' THEN
   RAISE EXCEPTION 'Opponent choice leaked via private read'; END IF;
 PERFORM public.submit_challenge_result_atomic(
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000022','homeWin');
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'my_outcome'<>'homeWin' OR r::text ILIKE '%awayWin%' THEN
   RAISE EXCEPTION 'Read RPC included other captain outcome on mismatch'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'error'<>'NOT_AUTHORIZED' OR r ? 'my_outcome' THEN
   RAISE EXCEPTION 'Unrelated captain read a private submission'; END IF;
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000099');
 IF r->>'error'<>'NOT_AUTHORIZED' THEN
   RAISE EXCEPTION 'Unknown booking exposes existence or submission'; END IF;

 PERFORM set_config('request.jwt.claim.sub','',true);
 r:=public.get_my_challenge_result_submission(
    '00000000-0000-0000-0000-000000000002');
 IF r->>'error'<>'AUTHENTICATION_REQUIRED' THEN
   RAISE EXCEPTION 'Anonymous private read was accepted'; END IF;
 IF has_function_privilege('anon',
    'public.get_my_challenge_result_submission(uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'Anonymous role has EXECUTE on private read'; END IF;
 IF NOT has_function_privilege('authenticated',
    'public.get_my_challenge_result_submission(uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'Authenticated captain cannot execute private read'; END IF;
END;
$private_read$;

-- One account must not impersonate two team captains in the same challenge.
INSERT INTO public.teams(id,captain_id) VALUES
 ('00000000-0000-0000-0000-000000000033',
  '00000000-0000-0000-0000-000000000101');
INSERT INTO public.bookings(id,booking_type,status,end_time,player_team_id,opponent_team_id)
VALUES ('00000000-0000-0000-0000-000000000015',
 'challenge','confirmed',now()-interval '2 hours',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000033');
DO $captain_independence$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.submit_challenge_result_atomic(
   '00000000-0000-0000-0000-000000000015',
   '00000000-0000-0000-0000-000000000011','homeWin');
 IF r->>'error'<>'INDEPENDENT_CAPTAINS_REQUIRED' THEN
   RAISE EXCEPTION 'Shared captain was allowed to submit a self-confirmed result'; END IF;
 r:=public.get_my_challenge_result_submission(
   '00000000-0000-0000-0000-000000000015');
 IF r->>'error'<>'NOT_AUTHORIZED' THEN
   RAISE EXCEPTION 'Shared captain private read should not be available'; END IF;
 IF EXISTS(SELECT 1 FROM public.challenge_captain_result_entries
   WHERE booking_id='00000000-0000-0000-0000-000000000015') THEN
   RAISE EXCEPTION 'Invalid challenge changed private result rows'; END IF;
END;
$captain_independence$;

-- Check the reader with actual PostgreSQL authenticated privileges as well
-- as the isolated auth.uid fixture. This does not represent a real GoTrue JWT.
SET ROLE authenticated;
DO $actual_role$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.get_my_challenge_result_submission(
   '00000000-0000-0000-0000-000000000002');
 IF r->>'my_outcome'<>'awayWin' THEN
   RAISE EXCEPTION 'Authenticated role cannot read its own result'; END IF;
 IF has_table_privilege(current_user,
    'public.challenge_captain_result_entries','SELECT') THEN
   RAISE EXCEPTION 'Authenticated role can read private raw entries'; END IF;
END;
$actual_role$;
RESET ROLE;

-- A booking owner can report a match not played without changing its payment
-- or fair-play state. Reporting a finalized match reverses ranking deltas once.
DO $non_played$
DECLARE r jsonb; points_before integer; away_before integer;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000001','The booked match was not played');
 IF r->>'error'<>'NOT_AUTHORIZED' THEN
   RAISE EXCEPTION 'Non-owner was allowed to report'; END IF;

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000404',true);
 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000004','The booked match was not played');
 IF r->>'error'<>'MATCH_NOT_FINISHED' THEN
   RAISE EXCEPTION 'Early non-played report accepted'; END IF;
 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000005','The booked match was not played');
 IF r->>'error'<>'BOOKING_NOT_ELIGIBLE' THEN
   RAISE EXCEPTION 'Pending booking non-played report accepted'; END IF;

 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>7
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>4 THEN
   RAISE EXCEPTION 'Unexpected baseline points before report'; END IF;
 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000001','The booked match was not played');
 IF r->>'state'<>'excluded' OR r->>'ranking_reversed'<>'true' THEN
   RAISE EXCEPTION 'Confirmed match not excluded from rankings'; END IF;
 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>4
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>4
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>3
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>3
    OR (SELECT elo_processed FROM public.bookings WHERE id='00000000-0000-0000-0000-000000000001') IS NOT TRUE THEN
   RAISE EXCEPTION 'Ranking rollback incorrect or not idempotent'; END IF;

 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000001','Repeated report must not alter counters');
 IF r->>'already_reported'<>'true' OR r->>'ranking_reversed'<>'true'
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>4 THEN
   RAISE EXCEPTION 'Duplicate report reversed ranking again'; END IF;

 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000003','Match did not take place at venue');
 IF r->>'ranking_reversed'<>'false' THEN
   RAISE EXCEPTION 'Never-scored match unexpectedly changed ranking'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.submit_challenge_result_atomic(
   '00000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000011','homeWin');
 IF r->>'error'<>'MATCH_EXCLUDED_NON_PLAYED' THEN
   RAISE EXCEPTION 'Captain finalized already reported non-played match'; END IF;
 -- A mismatch with two saved, private choices must remain available for
 -- authorized review, but cannot be accepted while excluded.
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000404',true);
 r:=public.owner_report_challenge_not_played_atomic(
   '00000000-0000-0000-0000-000000000002','The scheduled challenge did not happen');
 IF r->>'ranking_reversed'<>'false'
    OR (SELECT count(*) FROM public.challenge_captain_result_entries
        WHERE booking_id='00000000-0000-0000-0000-000000000002')<>2 THEN
   RAISE EXCEPTION 'Unapproved mismatched selections lost during exclusion'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.submit_challenge_result_atomic(
   '00000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000011','homeWin');
 IF r->>'error'<>'MATCH_EXCLUDED_NON_PLAYED' THEN
   RAISE EXCEPTION 'Excluded mismatched result could be finalized'; END IF;
 IF (SELECT count(*) FROM public.challenge_non_played_reports)<>3 THEN
   RAISE EXCEPTION 'Report audit missing or duplicated'; END IF;
 IF EXISTS(SELECT 1 FROM public.bookings WHERE fair_play_score<>100
    OR payment_status<>'paid' OR payment_reconcile_state<>'settled'
    OR is_paid IS DISTINCT FROM true
    OR deposit_amount<>100 OR deposit_paid<>50) THEN
   RAISE EXCEPTION 'Non-played reporting changed payment or fair-play'; END IF;
 IF has_table_privilege('authenticated',
    'public.challenge_non_played_reports','SELECT')
    OR has_table_privilege('anon',
    'public.challenge_non_played_reports','SELECT') THEN
   RAISE EXCEPTION 'Private non-played report exposed'; END IF;
END;
$non_played$;

-- Challenge appeal/review/restore, without changing booking finance.
DO $appeal_restore$
DECLARE r jsonb; n integer; before_points integer;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','We did play and the result was agreed');
 IF r->>'state'<>'under_review' OR r->>'revision'<>'1' THEN
   RAISE EXCEPTION 'First captain appeal failed'; END IF;
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','We did play and the result was agreed');
 IF r->>'already_submitted'<>'true'
    OR (SELECT count(*) FROM public.challenge_non_played_review_audit
        WHERE booking_id='00000000-0000-0000-0000-000000000001')<>1 THEN
   RAISE EXCEPTION 'Appeal replay not idempotent'; END IF;
 r:=public.get_my_challenge_non_played_status(
 '00000000-0000-0000-0000-000000000001');
 IF r->>'state'<>'excluded' OR r->>'under_review'<>'true'
    OR r->>'my_appeal_submitted'<>'true' THEN
   RAISE EXCEPTION 'Excluded appeal status not visible to captain'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.get_my_challenge_non_played_status(
 '00000000-0000-0000-0000-000000000001');
 IF r->>'my_appeal_submitted'<>'false' OR r ? 'reason' THEN
   RAISE EXCEPTION 'Opponent appeal reason leaked'; END IF;
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','We attended the stadium as scheduled');
 IF r->>'revision'<>'1' THEN
   RAISE EXCEPTION 'Second captain appeal was rejected'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000303',true);
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','This stranger should not appeal');
 IF r->>'error'<>'CAPTAIN_ONLY' THEN
   RAISE EXCEPTION 'Unrelated player appeal accepted'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000404',true);
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','restore','Owner cannot review the claim');
 IF r->>'error'<>'NOT_AUTHORIZED' THEN
   RAISE EXCEPTION 'Owner adjudicated own report'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000606',true);
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','restore','Ordinary player is not an admin');
 IF r->>'error'<>'NOT_AUTHORIZED' THEN
   RAISE EXCEPTION 'Ordinary player adjudicated a report'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000505',true);
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000002','uphold','Match evidence does not support the objection');
 IF r->>'state'<>'excluded' THEN
   RAISE EXCEPTION 'Review upheld report but unexcluded booking'; END IF;
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000002','uphold','Same decision replay should be idempotent');
 IF r->>'already_reviewed'<>'true' THEN
   RAISE EXCEPTION 'Repeated uphold inserted new review decision'; END IF;

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000002','I dispute the venue owner report');
 IF r->>'state'<>'under_review' THEN
   RAISE EXCEPTION 'Appeal after uphold was not accepted'; END IF;
 r:=public.get_my_challenge_non_played_status(
 '00000000-0000-0000-0000-000000000002');
 IF r->>'under_review'<>'true' THEN
   RAISE EXCEPTION 'New appeal after uphold was not pending review'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000505',true);
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000002','uphold','Re-reviewed the newly submitted appeal');
 IF r->>'already_reviewed'<>'false' THEN
   RAISE EXCEPTION 'New appeal did not allow re-review'; END IF;

 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','restore','Verified actual match evidence and both outcomes');
 IF r->>'state'<>'restored' OR r->>'ranking_restored'<>'true' THEN
   RAISE EXCEPTION 'Confirmed challenge ranking not restored'; END IF;
 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>7
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>4
    OR (SELECT status FROM public.challenge_non_played_reports
       WHERE booking_id='00000000-0000-0000-0000-000000000001')<>'restored' THEN
   RAISE EXCEPTION 'Rank totals after authorized restoration invalid'; END IF;
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','restore','Repeat replay must not add extra standings');
 IF r->>'already_reviewed'<>'true'
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>7 THEN
   RAISE EXCEPTION 'Repeat restoration credited points twice'; END IF;
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','uphold','Do not revert a restored decision');
 IF r->>'error'<>'REPORT_ALREADY_RESTORED' THEN
   RAISE EXCEPTION 'Already restored report could be contradicted'; END IF;

 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000404',true);
 r:=public.owner_report_challenge_not_played_atomic(
 '00000000-0000-0000-0000-000000000001','Repeat owner report cannot exclude restored booking');
 IF r->>'state'<>'restored' OR r->>'already_reported'<>'true' THEN
   RAISE EXCEPTION 'Repeated owner report re-excluded restored booking'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.captain_appeal_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000001','Appeal after final restoration is no longer open');
 IF r->>'error'<>'REPORT_NOT_OPEN' THEN
   RAISE EXCEPTION 'Restored report accepted additional appeal'; END IF;
 r:=public.get_my_challenge_non_played_status(
 '00000000-0000-0000-0000-000000000001');
 IF r->>'state'<>'restored' OR r->>'under_review'<>'false' THEN
   RAISE EXCEPTION 'Captain does not see safe restored state'; END IF;

 -- The initially unscored and excluded challenge can resume captain agreement
 -- only after an authorized restore; the ranking trigger must then run once.
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000505',true);
 r:=public.review_challenge_non_played_atomic(
 '00000000-0000-0000-0000-000000000003','restore','The scheduled challenge was played after review');
 IF r->>'ranking_restored'<>'false' THEN
   RAISE EXCEPTION 'Restored unscored challenge unexpectedly credited points'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.submit_challenge_result_atomic(
 '00000000-0000-0000-0000-000000000003',
 '00000000-0000-0000-0000-000000000011','homeWin');
 IF r->>'state'<>'waitingOpponent' THEN
   RAISE EXCEPTION 'Captain could not submit after restored exclusion'; END IF;
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000202',true);
 r:=public.submit_challenge_result_atomic(
 '00000000-0000-0000-0000-000000000003',
 '00000000-0000-0000-0000-000000000022','homeWin');
 IF r->>'state'<>'confirmed' THEN
   RAISE EXCEPTION 'Both captains could not agree after restoration'; END IF;
 IF (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>10
    OR (SELECT points FROM public.teams WHERE id='00000000-0000-0000-0000-000000000022')<>4
    OR (SELECT matches_played FROM public.teams WHERE id='00000000-0000-0000-0000-000000000011')<>5 THEN
   RAISE EXCEPTION 'Corrected challenge points missing or double counted'; END IF;

 IF (SELECT count(*) FROM public.challenge_non_played_review_audit
    WHERE booking_id='00000000-0000-0000-0000-000000000001')<>3 THEN
   RAISE EXCEPTION 'Review or appeals audit count differs'; END IF;
 IF EXISTS (SELECT 1 FROM public.bookings WHERE payment_status<>'paid'
    OR payment_reconcile_state<>'settled' OR is_paid IS DISTINCT FROM true
    OR deposit_amount<>100 OR deposit_paid<>50 OR fair_play_score<>100) THEN
   RAISE EXCEPTION 'Appeal or restoration changed financial or fair-play fields'; END IF;
 IF has_table_privilege('authenticated','public.challenge_non_played_appeals','SELECT')
    OR has_table_privilege('anon','public.challenge_non_played_review_audit','SELECT')
    OR has_table_privilege('authenticated','public.challenge_non_played_review_audit','SELECT') THEN
   RAISE EXCEPTION 'Confidential appeal/review data exposed to clients'; END IF;
END;
$appeal_restore$;

-- Account-deletion compatibility: booking/team row deletion must not be
-- blocked by report/appeal/audit history FKs. Actual retention obligations
-- still require a separate compliance policy before any staged rollout.
DO $deletion_compat$
DECLARE v_booking uuid:='00000000-0000-0000-0000-000000000001';
BEGIN
 IF (SELECT count(*) FROM public.challenge_non_played_reports WHERE booking_id=v_booking)<>1
    OR (SELECT count(*) FROM public.challenge_non_played_appeals WHERE booking_id=v_booking)<>2
    OR (SELECT count(*) FROM public.challenge_non_played_review_audit WHERE booking_id=v_booking)<>3 THEN
   RAISE EXCEPTION 'Missing report/appeal/audit fixture before deletion'; END IF;
 DELETE FROM public.bookings WHERE id=v_booking;
 IF EXISTS(SELECT 1 FROM public.challenge_non_played_reports WHERE booking_id=v_booking)
    OR EXISTS(SELECT 1 FROM public.challenge_non_played_appeals WHERE booking_id=v_booking)
    OR EXISTS(SELECT 1 FROM public.challenge_non_played_review_audit WHERE booking_id=v_booking)
    OR EXISTS(SELECT 1 FROM public.challenge_captain_result_entries WHERE booking_id=v_booking)
    OR EXISTS(SELECT 1 FROM public.challenge_captain_result_audit WHERE booking_id=v_booking) THEN
   RAISE EXCEPTION 'Booking deletion left orphaned challenge-result private data'; END IF;
END;
$deletion_compat$;

-- Exclusion should be enforced at the database query layer, even when
-- the stored booking_public_feed row still contains a confirmed result.
INSERT INTO public.booking_public_feed (id,booking_type,match_result_status)
VALUES
 ('00000000-0000-0000-0000-000000000002','challenge','disputed'),
 ('00000000-0000-0000-0000-000000000003','challenge','confirmed'),
 ('00000000-0000-0000-0000-000000000006','challenge','confirmed');
SET ROLE authenticated;
DO $public_feed_restriction$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM public.booking_public_feed;
 IF n<>2 THEN
   RAISE EXCEPTION 'Excluded match exposed to public feed, count %',n; END IF;
 IF EXISTS(SELECT 1 FROM public.booking_public_feed
           WHERE id='00000000-0000-0000-0000-000000000002') THEN
   RAISE EXCEPTION 'Private non-played report not enforced by RLS'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.booking_public_feed
    WHERE id='00000000-0000-0000-0000-000000000003') THEN
   RAISE EXCEPTION 'Restored public match did not reappear in feed'; END IF;
 IF has_schema_privilege('anon','vsp_private','USAGE') THEN
   RAISE EXCEPTION 'Anonymous role can use internal feed-filter schema'; END IF;
 IF has_function_privilege('anon',
     'vsp_private.is_challenge_result_excluded(uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'Anonymous role can execute internal report filter'; END IF;
END;
$public_feed_restriction$;
RESET ROLE;

-- Head-to-head aggregate must ignore excluded *confirmed* old outcomes,
-- pending entries, unprocessed results and other booking types.
INSERT INTO public.bookings
  (id,booking_type,status,end_time,player_team_id,opponent_team_id,
   match_result_status,final_outcome,elo_processed)
VALUES
 ('00000000-0000-0000-0000-000000000019',
 'matchup','completed',now()-interval '2 hours',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000022',
 'confirmed','homeWin',true),
 ('00000000-0000-0000-0000-000000000020',
 'challenge','completed',now()-interval '2 hours',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000022',
 'confirmed','homeWin',false),
 ('00000000-0000-0000-0000-000000000021',
 'challenge','completed',now()-interval '2 hours',
 '00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000022',
 'confirmed','homeWin',true);
INSERT INTO public.challenge_non_played_reports
(booking_id,reported_by_owner_id,reason,original_outcome,ranking_reversed)
VALUES
 ('00000000-0000-0000-0000-000000000021',
  '00000000-0000-0000-0000-000000000404',
  'Match was not played','homeWin',true);

-- Synthetic SELECT scope is intentionally broad. In hosted Supabase the
-- existing bookings_select_private_scope must be used, not this fixture policy.
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.bookings TO authenticated;
CREATE POLICY synthetic_bookings_select ON public.bookings
 FOR SELECT TO authenticated USING (true);
SET ROLE authenticated;
DO $eligible_h2h$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
 r:=public.get_eligible_challenge_head_to_head_stats(
  '00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000022');
 IF r->>'success'<>'true' OR (r->>'teamAWins')::int<>2
    OR (r->>'teamBWins')::int<>1 OR (r->>'draws')::int<>1
    OR (r->>'totalMatches')::int<>4 THEN
   RAISE EXCEPTION 'Eligible head-to-head counted excluded, unprocessed or matchup rows: %',r;
 END IF;
 r:=public.get_eligible_challenge_head_to_head_stats(
  '00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000011');
 IF (r->>'teamAWins')::int<>1 OR (r->>'teamBWins')::int<>2 THEN
   RAISE EXCEPTION 'Head-to-head orientation swapped incorrectly'; END IF;
 r:=public.get_eligible_challenge_head_to_head_stats(
  '00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000011');
 IF r->>'error'<>'INVALID_TEAM_PAIR' THEN
   RAISE EXCEPTION 'Same team pair accepted'; END IF;
 PERFORM set_config('request.jwt.claim.sub','',true);
 r:=public.get_eligible_challenge_head_to_head_stats(
  '00000000-0000-0000-0000-000000000011',
  '00000000-0000-0000-0000-000000000022');
 IF r->>'error'<>'AUTHENTICATION_REQUIRED' THEN
   RAISE EXCEPTION 'Anonymous match history accepted'; END IF;
END;
$eligible_h2h$;
RESET ROLE;
