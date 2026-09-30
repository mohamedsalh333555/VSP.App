-- ==============================================================================
-- Migration: 20261001010000_vsp_championship_master_v3_6_definitive_freeze_and_worker_secret.sql
-- Description: V3.6 Definitive Closure:
--   1. Dedicated 'refund_worker' secret in internal_function_secrets (decoupled from FCM)
--   2. Hardened trigger_cancellation_refund_worker using refund_worker secret
--   3. Hardened reconcile_cancellation_refund_queue using refund_worker secret
--   4. Hardened crown_tournament_champion_atomic:
--      - Server team name is SSOT (client override rejected)
--      - Frozen roster is strictly required (FROZEN_ROSTER_REQUIRED error on missing/empty roster)
--      - No team_members fallback
-- ==============================================================================

-- 1. Ensure dedicated 'refund_worker' secret exists
INSERT INTO public.internal_function_secrets (name, secret, created_at, updated_at)
VALUES ('refund_worker', encode(gen_random_bytes(32), 'hex'), timezone('utc', now()), timezone('utc', now()))
ON CONFLICT (name) DO NOTHING;

-- 2. Hardened trigger_cancellation_refund_worker using dedicated refund_worker secret
CREATE OR REPLACE FUNCTION public.trigger_cancellation_refund_worker()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
BEGIN
  -- Obtain dedicated internal refund_worker secret safely
  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name = 'refund_worker'
  LIMIT 1;

  IF coalesce(v_secret, '') = '' THEN
    -- Fallback to service_role if dedicated secret is not yet set
    SELECT secret INTO v_secret
    FROM public.internal_function_secrets
    WHERE name = 'service_role'
    LIMIT 1;
  END IF;

  IF coalesce(v_secret, '') = '' THEN
    RAISE WARNING 'Internal refund worker secret is missing; refund worker push skipped safely.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('action', 'process_queue')
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Refund worker trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$$;

-- 3. Hardened reconcile_cancellation_refund_queue using dedicated refund_worker secret
CREATE OR REPLACE FUNCTION public.reconcile_cancellation_refund_queue()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
  v_has_pending BOOLEAN := false;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM public.cancellation_refund_queue
    WHERE status = 'pending'
       OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
       OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ) INTO v_has_pending;

  IF NOT v_has_pending THEN
    RETURN;
  END IF;

  -- Strictly use dedicated refund_worker secret or service_role fallback
  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name = 'refund_worker'
  LIMIT 1;

  IF coalesce(v_secret, '') = '' THEN
    SELECT secret INTO v_secret
    FROM public.internal_function_secrets
    WHERE name = 'service_role'
    LIMIT 1;
  END IF;

  IF coalesce(v_secret, '') <> '' THEN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body := jsonb_build_object('action', 'process_queue')
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'reconcile_cancellation_refund_queue error: %', SQLERRM;
END;
$$;

-- 4. Hardened crown_tournament_champion_atomic (Server Team Name & Strict Frozen Roster Only)
CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(
  p_championship_id UUID,
  p_champion_team_id UUID,
  p_champion_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_role TEXT;
  v_team_name TEXT;
  v_prize NUMERIC;
  v_trophy_title TEXT;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_member RECORD;
  v_roster_id UUID;
  v_awarded INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 1. Immutable Champion Check: Once completed, champion CANNOT be changed
  IF v_champ.status = 'completed' THEN
    IF v_champ.champion_team_id = p_champion_team_id THEN
      RETURN jsonb_build_object('success', true, 'already_crowned', true, 'champion_team_id', p_champion_team_id);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'championship_already_completed_with_different_champion');
    END IF;
  END IF;

  IF v_champ.status != 'ongoing' THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_ongoing');
  END IF;

  -- 2. Team Must Be Confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.championship_registrations
    WHERE championship_id = p_championship_id
      AND team_id = p_champion_team_id
      AND registration_status = 'confirmed'
  ) AND NOT (p_champion_team_id::TEXT = ANY(coalesce(v_champ.paid_teams, ARRAY[]::TEXT[]))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'champion_team_not_confirmed');
  END IF;

  -- 3. Server Team Name is SSOT (Server Value Always Wins)
  SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  v_prize := coalesce(nullif(v_champ.prize_pool, 0), v_champ.grand_prize, 0);
  v_trophy_title := 'بطل بطولة ' || coalesce(v_champ.name, 'VSP');

  -- 4. Award Player Trophies Strictly to the Frozen Championship Roster (NO team_members fallback)
  SELECT id INTO v_roster_id
  FROM public.championship_rosters
  WHERE championship_id = p_championship_id AND team_id = p_champion_team_id;

  IF v_roster_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.championship_roster_players WHERE roster_id = v_roster_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FROZEN_ROSTER_REQUIRED');
  END IF;

  -- 5. Atomically Complete Championship
  UPDATE public.championships
  SET status = 'completed',
      champion_team_id = p_champion_team_id,
      champion_team_name = v_team_name,
      winner_team_id = p_champion_team_id,
      winner_team_name = v_team_name,
      updated_at = v_now
  WHERE id = p_championship_id;

  -- 6. Atomically Increment Wins, Points, and Award 'cup_winner' Badge
  UPDATE public.teams
  SET championships_won = coalesce(championships_won, 0) + 1,
      points = coalesce(points, 0) + 100,
      unlocked_badges = CASE
        WHEN 'cup_winner' = ANY(coalesce(unlocked_badges, ARRAY[]::TEXT[])) THEN unlocked_badges
        ELSE array_append(coalesce(unlocked_badges, ARRAY[]::TEXT[]), 'cup_winner')
      END,
      updated_at = v_now
  WHERE id = p_champion_team_id;

  -- 7. Distribute trophies to frozen roster players
  FOR v_member IN 
    SELECT player_id AS user_id FROM public.championship_roster_players WHERE roster_id = v_roster_id
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.player_trophies 
      WHERE user_id = v_member.user_id AND championship_id = p_championship_id
    ) THEN
      INSERT INTO public.player_trophies(id, user_id, championship_id, title, prize_won, created_at)
      VALUES (gen_random_uuid(), v_member.user_id, p_championship_id, v_trophy_title, v_prize, v_now);
      v_awarded := v_awarded + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'champion_team_id', p_champion_team_id,
    'championship_id', p_championship_id,
    'champion_team_name', v_team_name,
    'trophies_awarded', v_awarded,
    'prize_awarded', v_prize
  );
END;
$$;

-- 5. Permissions
REVOKE ALL ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated, service_role;
