-- Synthetic fixture only. Runner wraps this in a rollback transaction.
CREATE TABLE public.bookings(id int, booking_type text, match_result_status text,
  pending_outcome text, final_outcome text, status text, is_paid boolean,
  payment_status text, payment_reconcile_state text, updated_at timestamptz);
INSERT INTO public.bookings VALUES
 (1,'challenge','waiting_opponent','homeWin',NULL,'confirmed',true,'paid','settled',now()-interval '48 hours'),
 (2,'challenge','waitingOpponent','awayWin',NULL,'confirmed',false,'unpaid','pending',now()-interval '72 hours'),
 (3,'challenge','confirmed',NULL,'draw','completed',true,'paid','settled',now()-interval '48 hours'),
 (4,'matchup','waitingOpponent','homeWin',NULL,'confirmed',true,'paid','settled',now()-interval '48 hours');
CREATE TABLE public.teams(id int, points int, matches_played int, fair_play_score int);
INSERT INTO public.teams VALUES (1,3,1,100),(2,0,1,95);
CREATE TABLE public.notifications(id int);
CREATE TABLE public.tournament_matches(id int, status text);
INSERT INTO public.tournament_matches VALUES (1,'pending_confirmation');
CREATE FUNCTION public.auto_approve_tournament_matches_24h() RETURNS void
LANGUAGE plpgsql AS $$ BEGIN UPDATE public.tournament_matches SET status='approved'; END $$;
CREATE TEMP TABLE before_bookings AS TABLE public.bookings;
CREATE TEMP TABLE before_teams AS TABLE public.teams;

-- INSTALL_WITHOUT_CRON

-- Simulate pg_cron catalog/unschedule in this isolated database only.
CREATE SCHEMA cron;
CREATE TABLE cron.job(jobid bigint PRIMARY KEY, command text);
INSERT INTO cron.job VALUES
 (1,'SELECT public.auto_approve_challenge_matches_24h();'),
 (2,' select auto_reconcile_single_entry_results ( ) ; '),
 (3,'SELECT public.auto_approve_tournament_matches_24h();'),
 (4,'SELECT public.auto_approve_challenge_matches_24h(); SELECT public.other_maintenance();'),
 (5,'SELECT public.reconcile_cancellation_refund_queue();');
CREATE FUNCTION cron.unschedule(p_jobid bigint) RETURNS boolean LANGUAGE plpgsql
AS $$ BEGIN DELETE FROM cron.job WHERE jobid=p_jobid; RETURN FOUND; END $$;

-- INSTALL_WITH_CRON
-- REPLAY_INSTALL

SET ROLE service_role;
DO $$ DECLARE answer jsonb; BEGIN
  FOR i IN 1..3 LOOP
    answer := public.auto_approve_challenge_matches_24h();
    IF answer->>'resolved_matches_count' <> '0' OR answer->>'disabled' <> 'true' THEN
      RAISE EXCEPTION 'timeout still approves challenges';
    END IF;
    PERFORM public.auto_reconcile_single_entry_results();
  END LOOP;
END $$;
RESET ROLE;

DO $$ BEGIN
  IF EXISTS ((TABLE public.bookings EXCEPT TABLE before_bookings)
       UNION ALL (TABLE before_bookings EXCEPT TABLE public.bookings)) THEN
    RAISE EXCEPTION 'result, settlement or payment mutated';
  END IF;
  IF EXISTS ((TABLE public.teams EXCEPT TABLE before_teams)
       UNION ALL (TABLE before_teams EXCEPT TABLE public.teams)) THEN
    RAISE EXCEPTION 'standings or fair-play mutated';
  END IF;
  IF EXISTS (SELECT FROM public.notifications) THEN RAISE EXCEPTION 'false notification'; END IF;
  IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job) IS DISTINCT FROM ARRAY[3,4,5]::bigint[] THEN
    RAISE EXCEPTION 'unrelated cron job changed or dedicated job remains';
  END IF;
  IF has_function_privilege('anon','public.auto_approve_challenge_matches_24h()','EXECUTE')
    OR has_function_privilege('authenticated','public.auto_approve_challenge_matches_24h()','EXECUTE')
    OR has_function_privilege('anon','public.auto_reconcile_single_entry_results()','EXECUTE')
    OR has_function_privilege('authenticated','public.auto_reconcile_single_entry_results()','EXECUTE') THEN
    RAISE EXCEPTION 'legacy maintenance exposed to clients';
  END IF;
  PERFORM public.auto_approve_tournament_matches_24h();
  IF (SELECT status FROM public.tournament_matches WHERE id=1) <> 'approved' THEN
    RAISE EXCEPTION 'tournament rule broken';
  END IF;
END $$;
