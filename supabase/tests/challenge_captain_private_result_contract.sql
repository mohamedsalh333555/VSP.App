-- Never run on hosted Supabase. Synthetic fixture executed inside a disposable DB.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
CREATE TABLE public.teams (
 id uuid PRIMARY KEY, captain_id uuid NOT NULL,
 points integer DEFAULT 0, matches_played integer DEFAULT 0
);
INSERT INTO public.teams(id,captain_id) VALUES
 ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000202');
CREATE TABLE public.bookings (
 id uuid PRIMARY KEY,
 booking_type text NOT NULL, status text NOT NULL,
 end_time timestamptz NOT NULL,
 player_team_id uuid REFERENCES public.teams(id),
 opponent_team_id uuid REFERENCES public.teams(id),
 match_result_status text NOT NULL DEFAULT 'noResult',
 final_outcome text, pending_outcome text,
 result_submitted_by_team_id uuid,
 requires_admin_intervention boolean DEFAULT false,
 updated_at timestamptz DEFAULT now(),
 payment_status text DEFAULT 'paid',
 fair_play_score integer DEFAULT 100
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

-- INSTALL_PRIVATE_RESULTS_CANDIDATE

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
 IF (SELECT revision FROM public.challenge_captain_result_entries
       WHERE booking_id=v_id AND team_id='00000000-0000-0000-0000-000000000022')<>2 THEN
   RAISE EXCEPTION 'Edited vote lost revision'; END IF;
 IF (SELECT count(*) FROM public.challenge_captain_result_audit WHERE booking_id=v_id)<>3 THEN
   RAISE EXCEPTION 'Missing immutable submission audit'; END IF;
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
