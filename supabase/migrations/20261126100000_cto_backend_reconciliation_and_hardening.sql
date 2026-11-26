-- =============================================================
-- VSP CTO Backend Reconciliation & Security Hardening
-- Migration: 20261126100000_cto_backend_reconciliation_and_hardening.sql
--
-- Fixes verified against Production (mktqkddbcddrxjxabdua):
-- 1. Issue 1 (P0): Retire subscription_plans, create_owner_subscription_order,
--    claim_owner_web_subscription, admin_upgrade_owner_subscription_atomic,
--    and subscription cron jobs (preserving historical orders/records).
-- 2. Issue 2 (P0): Revoke confirm_cash_booking_atomic (4-arg & 3-arg) and
--    admin_settle_owner_cash_debt_atomic from PUBLIC/anon/authenticated.
-- 3. Issue 3 (P0): Enforce needs_deposit=false, deposit_amount=0 on stadiums
--    via vsp_guard_stadium_owner_rules() trigger (blocks API re-activation).
-- 4. Issue 4 (P0): Require paid & confirmed booking in submit_challenge_result_atomic()
--    before any challenge result can be finalized / trigger Gamification XP & Ranking.
-- 5. Issue 5 (P1): Neutralize No-Show & cash debt restrictions for online payers
--    while keeping admin account suspension (is_blocked).
-- 6. Issue 12 (P0): Revoke excessive PUBLIC/anon/authenticated EXECUTE grants
--    on 23 SECURITY DEFINER Gamification/StrongestTeam/Award/Season functions;
--    fix rollover_annual_season_atomic auth.uid() IS NULL bypass;
--    add advisory locks in check_team_and_member_limits() against race conditions;
--    enforce stadium.is_verified in book_stadium_with_monthly_award_atomic().
-- =============================================================
BEGIN;

-- ── 1. Retire Paid Owner Subscriptions (Preserve Historical Records) ─────────
UPDATE public.subscription_plans
SET is_active = false,
    monthly_price = 0,
    yearly_price = 0,
    updated_at = now()
WHERE is_active = true OR monthly_price > 0 OR yearly_price > 0;

CREATE OR REPLACE FUNCTION public.create_owner_subscription_order(
  p_plan_code text,
  p_billing_period text DEFAULT 'monthly'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'SUBSCRIPTIONS_RETIRED',
    'message', 'تم إلغاء باقات الاشتراك المدفوعة؛ جميع مميزات المالك متاحة مجاناً بدون قيود.'
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.create_owner_subscription_order(text, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.claim_owner_web_subscription()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'success', false,
    'error', 'SUBSCRIPTIONS_RETIRED',
    'message', 'تم إلغاء باقات الاشتراك المدفوعة؛ جميع مميزات المالك متاحة مجاناً.'
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.claim_owner_web_subscription()
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_upgrade_owner_subscription_atomic(uuid, text, integer)
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_job record;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'cron' AND table_name = 'job') THEN
    FOR v_job IN
      SELECT jobid FROM cron.job
      WHERE command ILIKE '%auto_downgrade_expired_subscriptions%'
         OR command ILIKE '%reconcile_owner_web_subscription_orders%'
    LOOP
      PERFORM cron.alter_job(v_job.jobid, active := false);
    END LOOP;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ── 2. Close Remaining Cash Paths (Preserve Historical & Manual Bookings) ───
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_settle_owner_cash_debt_atomic(uuid, numeric, text)
  FROM PUBLIC, anon, authenticated;

-- ── 3. Prevent Deposit Re-activation on Stadiums via Trigger ────────────────
CREATE OR REPLACE FUNCTION public.vsp_guard_stadium_owner_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval   record;
  v_caller uuid := auth.uid();
BEGIN
  -- 100% online payments: deposits are retired platform-wide.
  NEW.needs_deposit := false;
  NEW.deposit_amount := 0;

  IF TG_OP = 'INSERT' THEN
    IF NEW.owner_id IS NULL THEN
      RAISE EXCEPTION 'stadium_owner_required';
    END IF;

    PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;

    SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id);
    IF NOT v_eval.allowed THEN
      RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
        USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
    END IF;

    NEW.is_verified := false;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF v_caller = OLD.owner_id AND NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
      RAISE EXCEPTION 'owner_cannot_reassign_stadium: لا يمكن نقل ملكية الملعب لمستخدم آخر.';
    END IF;

    IF OLD.is_deleted_by_owner IS TRUE AND NEW.is_deleted_by_owner IS FALSE THEN
      PERFORM 1 FROM public.users WHERE id = NEW.owner_id FOR UPDATE;
      SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(NEW.owner_id, NEW.id);
      IF NOT v_eval.allowed THEN
        RAISE EXCEPTION 'STADIUM_LIMIT_EXCEEDED: %', v_eval.message
          USING ERRCODE = 'P0002', DETAIL = 'LIMIT_REACHED';
      END IF;
    END IF;

    IF v_caller = OLD.owner_id THEN
      IF NEW.name IS DISTINCT FROM OLD.name
         OR NEW.location IS DISTINCT FROM OLD.location
         OR NEW.governorate IS DISTINCT FROM OLD.governorate
         OR NEW.price_per_hour IS DISTINCT FROM OLD.price_per_hour
         OR NEW.base_price IS DISTINCT FROM OLD.base_price
         OR NEW.players_per_team IS DISTINCT FROM OLD.players_per_team
         OR NEW.total_field_capacity IS DISTINCT FROM OLD.total_field_capacity
         OR NEW.opening_time IS DISTINCT FROM OLD.opening_time
         OR NEW.closing_time IS DISTINCT FROM OLD.closing_time
         OR NEW.images IS DISTINCT FROM OLD.images
         OR NEW.image_url IS DISTINCT FROM OLD.image_url
         OR NEW.features IS DISTINCT FROM OLD.features
         OR NEW.lat IS DISTINCT FROM OLD.lat
         OR NEW.lng IS DISTINCT FROM OLD.lng THEN
        NEW.is_verified := false;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

-- ── 4. Challenge Result Payment Gate (No Owner Involvement) ──────────────────
CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(
  p_booking_id uuid,
  p_team_id uuid,
  p_outcome text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_team record;
  v_now timestamptz := timezone('utc', now());
  v_existing_team uuid;
  v_existing_outcome text;
  v_updated_summary jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
  END IF;
  IF p_outcome NOT IN ('homeWin', 'draw', 'awayWin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_OUTCOME');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_FOUND');
  END IF;
  IF v_booking.booking_type <> 'challenge' THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_CHALLENGE');
  END IF;
  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_CANCELLED');
  END IF;
  IF v_booking.status NOT IN ('confirmed', 'completed')
     OR COALESCE(v_booking.is_paid, false) IS NOT TRUE
     OR COALESCE(v_booking.payment_status, '') <> 'paid' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'CHALLENGE_PAYMENT_REQUIRED',
      'message', 'لا يمكن اعتماد نتيجة التحدي قبل إتمام سداد قيمة الحجز إلكترونياً.'
    );
  END IF;
  IF v_booking.end_time > v_now THEN
    RETURN jsonb_build_object('success', false, 'error', 'MATCH_NOT_FINISHED');
  END IF;
  IF p_team_id NOT IN (v_booking.player_team_id, v_booking.opponent_team_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_IN_BOOKING');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  IF v_booking.match_result_status = 'confirmed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'RESULT_ALREADY_FINALIZED');
  END IF;

  v_existing_team := v_booking.result_submitted_by_team_id;
  v_existing_outcome := v_booking.pending_outcome;

  IF v_existing_team IS NULL OR v_existing_team = p_team_id THEN
    UPDATE public.bookings SET
      pending_outcome = p_outcome,
      result_submitted_by_team_id = p_team_id,
      match_result_status = 'waitingOpponent',
      requires_admin_intervention = false,
      final_outcome = NULL,
      updated_at = v_now
    WHERE id = p_booking_id;
    RETURN jsonb_build_object(
      'success', true, 'state', 'waitingOpponent', 'finalized', false,
      'pending_outcome', p_outcome, 'submitted_by_team_id', p_team_id
    );
  END IF;

  IF v_existing_outcome = p_outcome THEN
    UPDATE public.bookings SET
      final_outcome = p_outcome,
      match_result_status = 'confirmed',
      status = 'completed',
      requires_admin_intervention = false,
      pending_outcome = NULL,
      result_submitted_by_team_id = NULL,
      updated_at = v_now
    WHERE id = p_booking_id
    RETURNING gamification_summary INTO v_updated_summary;

    RETURN jsonb_build_object(
      'success', true, 'state', 'confirmed', 'finalized', true,
      'final_outcome', p_outcome, 'gamification_summary', v_updated_summary
    );
  END IF;

  UPDATE public.bookings SET
    pending_outcome = p_outcome,
    result_submitted_by_team_id = p_team_id,
    match_result_status = 'waitingOpponent',
    requires_admin_intervention = false,
    final_outcome = NULL,
    updated_at = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true, 'state', 'mismatch', 'finalized', false,
    'error', 'RESULT_MISMATCH', 'latest_outcome', p_outcome,
    'latest_submitted_by_team_id', p_team_id
  );
END;
$function$;

-- ── 5. Neutralize No-Show & Legacy Cash Restrictions for Online Bookings ─────
REVOKE EXECUTE ON FUNCTION public.apply_no_show_penalty(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.owner_record_no_show_atomic(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_cash_booking_restrictions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_blocked boolean := false;
  v_booking_user_id uuid;
BEGIN
  IF NEW.created_by_user_id IS NOT NULL
     AND NEW.owner_id IS NOT NULL
     AND NEW.created_by_user_id = NEW.owner_id THEN
    RETURN NEW;
  END IF;

  v_booking_user_id := COALESCE(NEW.created_by_user_id, NEW.user_id);
  IF v_booking_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Preserve legitimate admin account suspension; ignore legacy no_show / cash debt flags.
  SELECT COALESCE(is_blocked, false) INTO v_is_blocked
  FROM public.users
  WHERE id = v_booking_user_id;

  IF FOUND AND v_is_blocked = true THEN
    RAISE EXCEPTION 'حسابك معلق حالياً من قبل الإدارة. لا يمكنك إجراء حجوزات جديدة.';
  END IF;

  -- Ensure online bookings never carry deposit flags.
  IF NEW.payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
    NEW.needs_deposit := false;
    NEW.deposit_amount := 0;
  END IF;

  RETURN NEW;
END;
$function$;

-- ── 6. Security Hardening: Team Race Conditions, Monthly Award & RPC Grants ─
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
  -- Advisory transaction locks serialize concurrent joins on both team and player.
  PERFORM pg_advisory_xact_lock(hashtextextended('team_cap:' || NEW.team_id::text, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('player_teams:' || NEW.user_id::text, 0));

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

CREATE OR REPLACE FUNCTION public.rollover_annual_season_atomic(
  p_closing_season_id uuid,
  p_next_year integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_closing RECORD;
  v_next_yr int;
  v_next_id uuid;
  v_prog    RECORD;
  v_archived int := 0;
BEGIN
  -- Fail-closed: require service_role/postgres OR active admin actor (never allow anon).
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    PERFORM public.require_active_admin_actor();
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_closing FROM public.competition_seasons WHERE id = p_closing_season_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'SEASON_NOT_FOUND'); END IF;
  IF v_closing.status = 'archived' THEN RETURN jsonb_build_object('success', true, 'already_archived', true); END IF;

  v_next_yr := COALESCE(p_next_year, v_closing.year_number + 1);

  FOR v_prog IN
    SELECT p.*,
           (SELECT min(r.final_rank) FROM public.team_monthly_rankings r WHERE r.season_id = p_closing_season_id AND r.team_id = p.team_id AND r.final_rank IS NOT NULL) AS best_rank,
           (SELECT e.reward_status FROM public.immortal_reward_entitlements e WHERE e.season_id = p_closing_season_id AND e.team_id = p.team_id LIMIT 1) AS imm_status
    FROM public.team_season_progress p
    WHERE p.season_id = p_closing_season_id
  LOOP
    INSERT INTO public.team_season_history (
      season_id, team_id, year_number, final_xp, highest_shield,
      challenges_total, challenges_weighted, wins_total, best_monthly_rank,
      immortal_qualified, immortal_reward_status, archived_at
    ) VALUES (
      p_closing_season_id, v_prog.team_id, v_closing.year_number, v_prog.season_xp, v_prog.highest_shield,
      v_prog.challenges_total, v_prog.challenges_weighted, v_prog.wins_total, v_prog.best_rank,
      v_prog.immortal_qualified, COALESCE(v_prog.imm_status, 'not_qualified'), now()
    ) ON CONFLICT (season_id, team_id) DO NOTHING;
    v_archived := v_archived + 1;
  END LOOP;

  UPDATE public.competition_seasons SET status = 'archived', closed_at = now(), updated_at = now()
  WHERE id = p_closing_season_id;

  INSERT INTO public.competition_seasons (
    season_code, name_ar, name_en, year_number, starts_at, ends_at, status, rules_config
  ) VALUES (
    v_next_yr::text,
    'موسم ' || v_next_yr::text,
    'Season ' || v_next_yr::text,
    v_next_yr,
    make_timestamptz(v_next_yr, 1, 1, 0, 0, 0, 'Africa/Cairo'),
    make_timestamptz(v_next_yr, 12, 31, 23, 59, 59, 'Africa/Cairo'),
    'active',
    v_closing.rules_config
  )
  ON CONFLICT (season_code) DO UPDATE SET status = 'active', updated_at = now()
  RETURNING id INTO v_next_id;

  RETURN jsonb_build_object('success', true, 'archived_teams', v_archived, 'next_season_id', v_next_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.book_stadium_with_monthly_award_atomic(
  p_award_id uuid,
  p_stadium_id uuid,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_award    RECORD;
  v_team     RECORD;
  v_stadium  RECORD;
  v_dur_hr   numeric;
  v_price    numeric;
  v_booking_id uuid;
  v_op_date  date;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_award FROM public.monthly_champion_awards WHERE id = p_award_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'AWARD_NOT_FOUND'); END IF;
  IF v_award.status <> 'issued' THEN RETURN jsonb_build_object('success', false, 'error', 'AWARD_ALREADY_USED_OR_VOID'); END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_award.team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  v_dur_hr := extract(epoch FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_dur_hr <= 0 OR v_dur_hr > 1.05 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EXACTLY_ONE_FREE_HOUR_ALLOWED');
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
  IF NOT FOUND
     OR v_stadium.is_active IS NOT TRUE
     OR v_stadium.is_verified IS NOT TRUE
     OR v_stadium.is_blocked IS TRUE
     OR COALESCE(v_stadium.is_deleted_by_owner, false) IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE');
  END IF;

  IF lower(btrim(COALESCE(v_stadium.governorate, ''))) <> lower(btrim(v_award.governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'GOVERNORATE_MISMATCH_WITH_AWARD');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id::text, 0));

  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time, v_stadium.closing_time, v_stadium.break_start_time, v_stadium.break_end_time,
    v_stadium.is_split_shift, v_stadium.maintenance_until, p_start_time, p_end_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_STADIUM_WINDOW');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status IN ('pending','confirmed','completed')
      AND start_time < p_end_time AND end_time > p_start_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_ALREADY_BOOKED');
  END IF;

  v_price := round(COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0), 2);
  v_op_date := (p_start_time AT TIME ZONE 'Africa/Cairo')::date;

  INSERT INTO public.bookings (
    stadium_id, owner_id, user_id, created_by_user_id, stadium_name, stadium_image_url,
    start_time, end_time, operational_date, booking_type, player_team_id, player_team_name,
    is_private, total_price, deposit_paid, is_deposit_paid, is_paid, payment_status,
    payment_method, payment_source, payment_transaction_id, platform_fee, vsp_commission, gateway_fee,
    status, currency, is_verified_by_owner
  ) VALUES (
    p_stadium_id, v_stadium.owner_id, v_caller, v_caller, v_stadium.name, v_stadium.image_url,
    p_start_time, p_end_time, v_op_date, 'team', v_team.id, v_team.name,
    true, v_price, v_price, true, true, 'paid',
    'vsp_monthly_award', 'vsp_monthly_award', 'AWARD_' || v_award.id::text, 0, 0, 0,
    'confirmed', 'EGP', true
  ) RETURNING id INTO v_booking_id;

  UPDATE public.monthly_champion_awards
  SET status = 'redeemed',
      redeemed_booking_id = v_booking_id,
      redeemed_at = now(),
      reimbursed_amount_egp = v_price,
      updated_at = now()
  WHERE id = v_award.id;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, type, status, payment_method, metadata, created_at, updated_at
  ) VALUES (
    v_stadium.owner_id, v_booking_id, v_price, 'vsp_monthly_award_credit', 'completed', 'vsp_monthly_award',
    jsonb_build_object('award_id', v_award.id, 'team_id', v_team.id, 'month_key', v_award.month_key, 'vsp_funded', true),
    now(), now()
  );

  RETURN jsonb_build_object('success', true, 'booking_id', v_booking_id, 'vsp_covered_amount', v_price);
END;
$function$;

-- Lock down internal/webhook/cron SECURITY DEFINER functions (service_role only)
REVOKE EXECUTE ON FUNCTION public.confirm_strongest_team_payment_atomic(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.confirm_strongest_team_payment_atomic(text, text, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.vsp_apply_single_team_challenge_outcome(uuid, text, uuid, uuid, uuid, text, text, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.vsp_apply_single_team_challenge_outcome(uuid, text, uuid, uuid, uuid, text, text, text, boolean) TO service_role;

REVOKE EXECUTE ON FUNCTION public.vsp_refresh_team_season_state(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.vsp_refresh_team_season_state(uuid, uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.vsp_grant_tournament_mission_if_eligible(uuid, text, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.vsp_grant_tournament_mission_if_eligible(uuid, text, uuid, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.vsp_unlock_achievement_if_new(uuid, uuid, text, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.vsp_unlock_achievement_if_new(uuid, uuid, text, text, text, text, text, text, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.distribute_field_championship_xp_atomic(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.distribute_field_championship_xp_atomic(uuid, uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.close_monthly_ranking_period(text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.close_monthly_ranking_period(text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.rollover_annual_season_atomic(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.rollover_annual_season_atomic(uuid, integer) TO service_role;

REVOKE EXECUTE ON FUNCTION public.vsp_cairo_season_cron_tick() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.vsp_cairo_season_cron_tick() TO service_role;

-- Lock down authenticated-only RPCs (revoke PUBLIC & anon)
REVOKE EXECUTE ON FUNCTION public.book_stadium_with_monthly_award_atomic(uuid, uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.book_stadium_with_monthly_award_atomic(uuid, uuid, timestamptz, timestamptz) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.join_strongest_team_event_atomic(uuid, uuid, uuid[], uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.join_strongest_team_event_atomic(uuid, uuid, uuid[], uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.submit_immortal_player_size(uuid, uuid, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.submit_immortal_player_size(uuid, uuid, text, text, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_adjust_team_xp_atomic(uuid, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_adjust_team_xp_atomic(uuid, numeric, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_finalize_strongest_team_event_atomic(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_finalize_strongest_team_event_atomic(uuid, uuid, uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_reverse_xp_entry_atomic(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_reverse_xp_entry_atomic(uuid, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_update_immortal_reward_status_atomic(uuid, text, text, boolean, numeric, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_update_immortal_reward_status_atomic(uuid, text, text, boolean, numeric, text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_update_season_config_atomic(uuid, timestamptz, timestamptz, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.admin_update_season_config_atomic(uuid, timestamptz, timestamptz, jsonb) TO authenticated;

COMMIT;
