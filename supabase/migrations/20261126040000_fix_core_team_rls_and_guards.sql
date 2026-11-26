-- =============================================================
-- VSP Phase 2A: Core Team Schema, Limits (8 players / 3 teams),
-- Broken RPC Fixes, and Security Hardening
-- Migration: 20261126040000_fix_core_team_rls_and_guards.sql
-- =============================================================
BEGIN;

-- 1. Align public.teams missing legacy/core columns & add Season/Shield display columns
ALTER TABLE public.teams
  ADD COLUMN IF NOT EXISTS elo_rating               INTEGER        DEFAULT 1000,
  ADD COLUMN IF NOT EXISTS fair_play_score          INTEGER        DEFAULT 100,
  ADD COLUMN IF NOT EXISTS preferred_formation      TEXT           DEFAULT '2-2-1',
  ADD COLUMN IF NOT EXISTS is_active                BOOLEAN        DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_blocked               BOOLEAN        DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_verified              BOOLEAN        DEFAULT false,
  ADD COLUMN IF NOT EXISTS lifetime_xp              NUMERIC(12,2)  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_season_xp        NUMERIC(12,2)  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_shield           TEXT           DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS highest_historical_shield TEXT          DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS previous_season_shield   TEXT           DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS immortal_count           INTEGER        DEFAULT 0;

-- Ensure bookings has JSONB column for match completion gamification summary
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS gamification_summary     JSONB,
  ADD COLUMN IF NOT EXISTS gamification_processed   BOOLEAN        DEFAULT false;

-- 2. Fix reset_fair_play_score_annually to use Africa/Cairo timezone
CREATE OR REPLACE FUNCTION public.reset_fair_play_score_annually()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_current_year INT := EXTRACT(YEAR FROM (now() AT TIME ZONE 'Africa/Cairo'));
BEGIN
  IF NEW.last_reset_year IS NULL OR v_current_year > NEW.last_reset_year THEN
    NEW.fair_play_score := 100;
    NEW.last_reset_year := v_current_year;
  END IF;
  RETURN NEW;
END;
$function$;

-- 3. Enforce approved Team & Member limits in Backend:
--    Max 8 players per team, max 3 teams per player (owned + joined total).
--    Existing memberships above limits are preserved gracefully; only new additions are capped.
CREATE OR REPLACE FUNCTION public.check_team_and_member_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_count int;
  v_player_total_teams int;
BEGIN
  SELECT count(*) INTO v_team_count
  FROM public.team_members
  WHERE team_id = NEW.team_id AND user_id <> NEW.user_id;

  IF v_team_count >= 8 THEN
    RAISE EXCEPTION 'TEAM_CAPACITY_REACHED: Maximum 8 players allowed per team.';
  END IF;

  SELECT count(*) INTO v_player_total_teams
  FROM public.team_members
  WHERE user_id = NEW.user_id AND team_id <> NEW.team_id;

  IF v_player_total_teams >= 3 THEN
    RAISE EXCEPTION 'PLAYER_TEAM_LIMIT_REACHED: A player can join at most 3 teams.';
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_team_atomic(
  p_data jsonb,
  p_member_uids uuid[] DEFAULT ARRAY[]::uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_team_id uuid;
  v_caller uuid := auth.uid();
  v_count int;
  v_name text;
  v_captain_governorate text;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  v_count := coalesce(array_length(p_member_uids, 1), 0);
  v_name := trim(coalesce(p_data->>'name', ''));

  IF v_count < 1 OR v_count > 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team members must be between 1 and 8');
  END IF;

  IF cardinality(ARRAY(SELECT DISTINCT x FROM unnest(p_member_uids) x)) <> v_count THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duplicate team member');
  END IF;

  IF p_member_uids[1] <> v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the captain can create the team');
  END IF;

  IF v_name = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name is required');
  END IF;

  SELECT governorate
    INTO v_captain_governorate
  FROM public.users
  WHERE id = v_caller;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CAPTAIN_GOVERNORATE_REQUIRED',
      'message', 'يجب تحديد محافظة الكابتن قبل إنشاء الفريق.'
    );
  END IF;

  IF (SELECT count(*) FROM public.users WHERE id = ANY(p_member_uids)) <> v_count THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'INVALID_TEAM_MEMBER',
      'message', 'أحد اللاعبين غير موجود في النظام.'
    );
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.users u
    WHERE u.id = ANY(p_member_uids)
      AND (
        u.governorate IS NULL
        OR btrim(u.governorate) = ''
        OR lower(btrim(u.governorate)) <> lower(btrim(v_captain_governorate))
      )
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'TEAM_GOVERNORATE_MISMATCH',
      'message', 'لا يمكن إنشاء الفريق لأن جميع اللاعبين يجب أن يكونوا من نفس محافظة الكابتن.'
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.teams
    WHERE lower(trim(name)) = lower(v_name)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team name already exists');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.team_members
    WHERE user_id = ANY(p_member_uids)
    GROUP BY user_id
    HAVING count(*) >= 3
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'A player has reached the maximum of 3 teams');
  END IF;

  INSERT INTO public.teams(
    name, bio, captain_id, logo_url, primary_color, secondary_color,
    governorate, preferred_formation, elo_rating, points, wins, draws, losses,
    matches_played, current_winning_streak, championships_won, is_active,
    is_blocked, is_verified, lifetime_xp, current_season_xp, current_shield,
    highest_historical_shield, previous_season_shield, immortal_count
  )
  VALUES(
    v_name,
    coalesce(p_data->>'bio', ''),
    v_caller,
    p_data->>'logo_url',
    coalesce(p_data->>'primary_color', '#FFFFFF'),
    coalesce(p_data->>'secondary_color', '#000000'),
    v_captain_governorate,
    coalesce(p_data->>'preferred_formation', '2-2-1'),
    1000, 0, 0, 0, 0, 0, 0, 0, true, false, false, 0, 0, 'none', 'none', 'none', 0
  )
  RETURNING id INTO v_team_id;

  INSERT INTO public.team_members(team_id, user_id)
  SELECT v_team_id, x
  FROM unnest(p_member_uids) x;

  RETURN jsonb_build_object(
    'success', true,
    'team_id', v_team_id,
    'governorate', v_captain_governorate
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_team_member_atomic(p_team_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_exists boolean;
  v_captain_governorate text;
  v_player_governorate text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid()
           OR v_role IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  PERFORM 1 FROM public.teams WHERE id = p_team_id FOR UPDATE;

  SELECT u.governorate
    INTO v_captain_governorate
  FROM public.teams t
  JOIN public.users u ON u.id = t.captain_id
  WHERE t.id = p_team_id;

  SELECT governorate INTO v_player_governorate
  FROM public.users
  WHERE id = p_user_id;

  IF v_captain_governorate IS NULL OR btrim(v_captain_governorate) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_GOVERNORATE_REQUIRED', 'message', 'محافظة الكابتن غير محددة.');
  END IF;

  IF v_player_governorate IS NULL OR btrim(v_player_governorate) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_GOVERNORATE_REQUIRED', 'message', 'لا يمكن إضافة لاعب بدون محافظة محددة.');
  END IF;

  IF lower(btrim(v_player_governorate)) <> lower(btrim(v_captain_governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_GOVERNORATE_MISMATCH', 'message', 'لا يمكن إضافة اللاعب لأن محافظته مختلفة عن محافظة كابتن الفريق.');
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.team_members
    WHERE team_id = p_team_id AND user_id = p_user_id
  ) INTO v_exists;

  IF v_exists THEN
    RETURN jsonb_build_object('success', true, 'already_member', true);
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE team_id = p_team_id) >= 8 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team is full (max 8 players)');
  END IF;

  IF (SELECT count(*) FROM public.team_members WHERE user_id = p_user_id) >= 3 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player reached maximum 3 teams');
  END IF;

  INSERT INTO public.team_members(team_id, user_id)
  VALUES(p_team_id, p_user_id);

  RETURN jsonb_build_object('success', true);
END;
$function$;

-- 4. Fix text[] vs uuid[] crashes in delete_team_atomic & remove_team_member_atomic
CREATE OR REPLACE FUNCTION public.delete_team_atomic(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();

  IF NOT EXISTS (
    SELECT 1 FROM public.teams
    WHERE id = p_team_id
      AND (captain_id = auth.uid() OR coalesce(v_role,'') IN ('admin','co_founder','cofounder','super_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status = 'confirmed'
      AND (player_team_id = p_team_id OR opponent_team_id = p_team_id)
      AND end_time > now()
  ) OR EXISTS (
    SELECT 1 FROM public.championships
    WHERE status IN ('open', 'ongoing')
      AND p_team_id::text = ANY(coalesce(joined_teams, ARRAY[]::text[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'active_match_or_tournament_error');
  END IF;

  DELETE FROM public.team_members WHERE team_id = p_team_id;
  DELETE FROM public.teams WHERE id = p_team_id;
  RETURN jsonb_build_object('success', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.remove_team_member_atomic(p_team_id uuid, p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_cap uuid;
  v_next uuid;
  v_team_disbanded boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  SELECT captain_id INTO v_cap FROM public.teams WHERE id = p_team_id FOR UPDATE;

  IF v_cap IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Team not found');
  END IF;

  IF auth.uid() <> p_user_id AND v_cap <> auth.uid() AND COALESCE(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: فقط الكابتن أو العضو نفسه يمكنه إتمام المغادرة.');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE status = 'confirmed'
      AND (player_team_id = p_team_id OR opponent_team_id = p_team_id)
      AND end_time > now()
  ) OR EXISTS (
    SELECT 1 FROM public.championships
    WHERE status IN ('open', 'ongoing')
      AND p_team_id::text = ANY(COALESCE(joined_teams, ARRAY[]::text[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'active_match_or_tournament_error');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = p_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Player is not a member of this team');
  END IF;

  DELETE FROM public.team_members WHERE team_id = p_team_id AND user_id = p_user_id;

  IF v_cap = p_user_id THEN
    SELECT user_id INTO v_next
    FROM public.team_members
    WHERE team_id = p_team_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_next IS NOT NULL THEN
      UPDATE public.teams t
      SET captain_id = v_next,
          captain_name = u.name,
          captain_phone = u.phone,
          captain_image_url = u.profile_image_url,
          updated_at = now()
      FROM public.users u
      WHERE t.id = p_team_id AND u.id = v_next;
    ELSE
      DELETE FROM public.teams WHERE id = p_team_id;
      v_team_disbanded := true;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'captain_transferred', (v_cap = p_user_id AND v_next IS NOT NULL),
    'new_captain_id', v_next,
    'team_disbanded', v_team_disbanded
  );
END;
$function$;

-- 5. Fix join_championship_atomic: users.name instead of non-existent users.full_name
CREATE OR REPLACE FUNCTION public.join_championship_atomic(
  p_championship_id uuid,
  p_team_id uuid,
  p_player_ids uuid[] DEFAULT ARRAY[]::uuid[],
  p_guest_names text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_reg_id UUID;
  v_roster_id UUID;
  v_joined_count INT;
  v_player_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  v_phase := public.calculate_championship_effective_phase(p_championship_id);
  IF v_phase != 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'current_phase', v_phase);
  END IF;

  IF coalesce(v_champ.entry_fee, 0) > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_REQUIRED_USE_ORDER');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id AND registration_status = 'confirmed';

  IF v_joined_count >= v_champ.max_teams THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_FULL');
  END IF;

  IF coalesce(array_length(p_player_ids, 1), 0) > 0 THEN
    IF (SELECT count(DISTINCT pid) FROM unnest(p_player_ids) pid) <> array_length(p_player_ids, 1) THEN
      RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS_IN_ROSTER');
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_members tm WHERE tm.team_id = p_team_id AND tm.user_id = pid
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TEAM_PLAYER_NOT_MEMBER');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.championship_roster_players crp
    JOIN public.championship_rosters cr ON cr.id = crp.roster_id
    WHERE cr.championship_id = p_championship_id
      AND cr.team_id <> p_team_id
      AND crp.player_id = ANY(coalesce(p_player_ids, ARRAY[]::UUID[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_ALREADY_IN_ANOTHER_TEAM');
  END IF;

  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_TOO_LARGE', 'max_allowed', v_champ.max_players_per_team);
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_INCOMPLETE', 'min_required', v_champ.min_players_per_team);
  END IF;

  SELECT id, name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency,
    created_at, updated_at
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.name, 'phone', v_captain.phone),
    'confirmed', 'exempt', 0.00, 0.00, coalesce(v_champ.currency, 'EGP'),
    now(), now()
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = 'confirmed',
    payment_status = 'exempt',
    updated_at = now()
  RETURNING id INTO v_reg_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_reg_id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      updated_at = now()
  WHERE id = p_championship_id
    AND NOT (p_team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg_id,
    'roster_id', v_roster_id,
    'payment_status', 'exempt',
    'registration_status', 'confirmed',
    'player_count', v_player_count
  );
END;
$function$;

-- 6. Fix admin_resolve_dispute_atomic to normalize outcome strings to bookings_final_outcome_check
CREATE OR REPLACE FUNCTION public.admin_resolve_dispute_atomic(
  p_booking_id uuid,
  p_final_outcome text,
  p_home_score integer DEFAULT NULL::integer,
  p_away_score integer DEFAULT NULL::integer,
  p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking RECORD;
  v_actor_id uuid := auth.uid();
  v_actor_role TEXT;
  v_actor_is_blocked boolean;
  v_norm_outcome text;
  v_now timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF v_actor_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;
    SELECT role, coalesce(is_blocked, false) INTO v_actor_role, v_actor_is_blocked FROM public.users WHERE id = v_actor_id;
    IF v_actor_is_blocked THEN
      RETURN jsonb_build_object('success', false, 'error', 'Actor account is blocked');
    END IF;
    IF COALESCE(v_actor_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin authorization required');
    END IF;
  ELSE
    v_actor_role := 'service_role';
  END IF;

  v_norm_outcome := CASE p_final_outcome
    WHEN 'home_win' THEN 'homeWin'
    WHEN 'away_win' THEN 'awayWin'
    WHEN 'homeWin'  THEN 'homeWin'
    WHEN 'awayWin'  THEN 'awayWin'
    WHEN 'draw'     THEN 'draw'
    WHEN 'cancelled' THEN 'cancelled'
    ELSE NULL
  END;

  IF v_norm_outcome IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_OUTCOME', 'message', 'النتيجة غير صالحة.');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
  END IF;

  UPDATE public.bookings
  SET status = CASE WHEN v_norm_outcome = 'cancelled' THEN 'cancelled' ELSE 'completed' END,
      final_outcome = CASE WHEN v_norm_outcome = 'cancelled' THEN NULL ELSE v_norm_outcome END,
      match_result_status = CASE WHEN v_norm_outcome = 'cancelled' THEN 'cancelled' ELSE 'confirmed' END,
      pending_outcome = NULL,
      requires_admin_intervention = false,
      home_team_score = COALESCE(p_home_score, home_team_score),
      away_team_score = COALESCE(p_away_score, away_team_score),
      host_score = COALESCE(p_home_score, host_score),
      away_score = COALESCE(p_away_score, away_score),
      dispute_notes = COALESCE(p_notes, dispute_notes),
      cancelled_at = CASE WHEN v_norm_outcome = 'cancelled' THEN v_now ELSE cancelled_at END,
      cancellation_reason = CASE WHEN v_norm_outcome = 'cancelled' THEN COALESCE('ملغي بقرار فض النزاع: ' || COALESCE(p_notes, ''), 'ملغي بقرار إدارة المنظومة') ELSE cancellation_reason END,
      updated_at = v_now
  WHERE id = p_booking_id;

  IF v_booking.player_team_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, type, created_at)
    SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية: ' || v_norm_outcome, 'result_confirmation', v_now
    FROM public.teams WHERE id = v_booking.player_team_id;
  END IF;

  IF v_booking.opponent_team_id IS NOT NULL THEN
    INSERT INTO public.notifications(user_id, title, body, type, created_at)
    SELECT captain_id, 'تم فض نزاع المباراة من إدارة VSP ⚖️', 'تم اعتماد النتيجة النهائية: ' || v_norm_outcome, 'result_confirmation', v_now
    FROM public.teams WHERE id = v_booking.opponent_team_id;
  END IF;

  INSERT INTO public.system_audit_logs(
    action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at
  ) VALUES (
    'admin_resolve_dispute', 'bookings', p_booking_id,
    jsonb_build_object('status', v_booking.status, 'final_outcome', v_booking.final_outcome),
    jsonb_build_object('final_outcome', v_norm_outcome, 'home_score', p_home_score, 'away_score', p_away_score, 'notes', p_notes),
    v_actor_id, v_actor_role, v_now
  );

  RETURN jsonb_build_object('success', true, 'outcome', v_norm_outcome, 'server_time', v_now);
END;
$function$;

-- 7. Column-level privilege hardening: prevent direct client REST mutations on authoritative fields
REVOKE UPDATE (
  points, wins, draws, losses, matches_played, current_winning_streak, championships_won,
  elo_rating, fair_play_score, attendance_score, verified_badge, is_official, is_verified,
  is_blocked, has_1v1_champion, beaten_opponents, played_opponents, unlocked_badges,
  last_reset_year, captain_id, lifetime_xp, current_season_xp, current_shield,
  highest_historical_shield, previous_season_shield, immortal_count
) ON public.teams FROM anon, authenticated;

REVOKE UPDATE (
  is_approved, champion_team_id, winner_team_id, champion_user_id, paid_teams, joined_teams,
  prize_pool, creation_fee_paid, creation_payment_id, prize_delivered, prize_delivered_at,
  prize_delivered_by, prize_delivery_notes, registration_locked_at
) ON public.championships FROM anon, authenticated;

REVOKE INSERT, UPDATE, DELETE ON public.system_audit_logs FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.financial_audit_logs FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.player_trophies FROM anon, authenticated;

-- 8. Tighten team_league_match_submissions & team_league_result_audits RLS (replace USING (true))
DROP POLICY IF EXISTS "team_league_submissions_select" ON public.team_league_match_submissions;
DROP POLICY IF EXISTS "select_team_league_match_submissions" ON public.team_league_match_submissions;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.team_league_match_submissions;
DROP POLICY IF EXISTS "team_members_see_own_league_submissions" ON public.team_league_match_submissions;
CREATE POLICY "team_members_see_own_league_submissions"
  ON public.team_league_match_submissions
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      JOIN public.tournament_matches m ON m.id = team_league_match_submissions.match_id
      JOIN public.championships c ON c.id = m.championship_id
      WHERE tm.user_id = auth.uid()
        AND tm.team_id::text = ANY(COALESCE(c.joined_teams, ARRAY[]::text[]))
    )
    OR public.is_admin_or_cofounder(auth.uid())
  );

DROP POLICY IF EXISTS "team_league_audits_select" ON public.team_league_result_audits;
DROP POLICY IF EXISTS "select_team_league_result_audits" ON public.team_league_result_audits;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.team_league_result_audits;
DROP POLICY IF EXISTS "team_members_see_own_league_audits" ON public.team_league_result_audits;
CREATE POLICY "team_members_see_own_league_audits"
  ON public.team_league_result_audits
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.team_members tm
      JOIN public.tournament_matches m ON m.id = team_league_result_audits.match_id
      JOIN public.championships c ON c.id = m.championship_id
      WHERE tm.user_id = auth.uid()
        AND tm.team_id::text = ANY(COALESCE(c.joined_teams, ARRAY[]::text[]))
    )
    OR public.is_admin_or_cofounder(auth.uid())
  );

COMMIT;
