-- Migration: 20261001150000_strict_booking_type_and_auto_expire_worker.sql
-- Description:
--   1. Strict SSOT Gate: create_booking_atomic explicitly rejects any unknown/invalid booking_type
--      instead of silently falling back to 'personal'.
--   2. Automatic Challenge Code Worker: hook 7-day expiration sweep into auto_expire_stale_records()
--      which runs automatically every 5 minutes via pg_cron.

-- 1. Update auto_expire_stale_records() to include challenge code sweep and challenge_status sync
CREATE OR REPLACE FUNCTION public.auto_expire_stale_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Stage 0: self-healing. A booking that was actually PAID but stayed stuck at 'pending'
  UPDATE public.bookings
  SET
    status = 'confirmed',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'confirmed' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-promoted to confirmed - payment succeeded but status was stuck at pending]'
  WHERE status = 'pending'
    AND (is_paid = TRUE OR payment_status IN ('paid', 'completed'))
    AND created_at <= NOW() - INTERVAL '2 minutes';

  -- Stage 1: cancel bookings whose temporary payment lock elapsed
  UPDATE public.bookings
  SET
    status = 'cancelled',
    payment_status = 'failed',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired - payment window elapsed]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND locked_until IS NOT NULL
    AND locked_until < NOW();

  -- Stage 2: safety net - cancel any unpaid pending older than 10 minutes
  UPDATE public.bookings
  SET
    status = 'cancelled',
    payment_status = 'failed',
    challenge_status = CASE WHEN booking_type = 'challenge' THEN 'expired' ELSE challenge_status END,
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- Stage 3: expire stale challenge pending reservations
  UPDATE public.bookings
  SET
    status = 'cancelled',
    challenge_status = 'expired',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );

  -- Stage 4: Expire stale team challenge codes (Automated 7-day lifecycle worker)
  UPDATE public.team_challenge_codes
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at IS NOT NULL
    AND expires_at < timezone('utc', now());
END;
$function$;

-- 2. Update create_booking_atomic with strict booking_type rejection gate
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_stadium_id        text,
  p_user_id           text,
  p_owner_id          text,
  p_start_time        timestamp with time zone,
  p_end_time          timestamp with time zone,
  p_booking_type      text,
  p_total_price       numeric,
  p_stadium_name      text DEFAULT ''::text,
  p_stadium_image_url text DEFAULT ''::text,
  p_is_private        boolean DEFAULT true,
  p_rent_ball         boolean DEFAULT false,
  p_needs_deposit     boolean DEFAULT false,
  p_deposit_amount    numeric DEFAULT 0,
  p_payment_method    text DEFAULT 'cash'::text,
  p_payment_status    text DEFAULT 'pending'::text,
  p_player_team_id    text DEFAULT NULL::text,
  p_player_team_name  text DEFAULT NULL::text,
  p_opponent_team_id  text DEFAULT NULL::text,
  p_opponent_team_name text DEFAULT NULL::text,
  p_platform_fee      numeric DEFAULT 0,
  p_idempotency_key   text DEFAULT NULL::text,
  p_initial_players   integer DEFAULT 1,
  p_total_capacity    integer DEFAULT NULL::integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium              record;
  v_caller               uuid := auth.uid();
  v_caller_role          text;
  v_duration_hours       numeric;
  v_calculated_price     numeric;
  v_hourly_rate          numeric;
  v_ball_price           numeric := 0;
  v_final_total_price    numeric;
  v_final_needs_deposit  boolean;
  v_final_deposit_amount numeric;
  v_final_deposit_paid   numeric := 0;
  v_final_status         text;
  v_final_is_paid        boolean;
  v_locked_until         timestamptz;
  v_active_cash_count    int := 0;
  v_conflict_count       int := 0;
  v_user_blocked         boolean;
  v_no_show_count        int;
  v_new_booking_id       uuid;
  v_existing_id          uuid;
  v_existing_status      text;
  v_now                  timestamptz := timezone('utc', now());
  v_initial_players      int;
  v_capacity             int;
  v_raw_type             text;
  v_normalized_type      text;
BEGIN
  -- SSOT Strict Gate: Exactly personal, open_join, or challenge accepted
  v_raw_type := lower(trim(COALESCE(p_booking_type, '')));
  IF v_raw_type = 'openjoin' THEN
    v_raw_type := 'open_join';
  END IF;

  IF v_raw_type NOT IN ('personal', 'open_join', 'challenge') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'INVALID_BOOKING_TYPE',
      'error', 'INVALID_BOOKING_TYPE',
      'message', 'نوع الحجز غير صالح. الأنواع المعتمدة هي: personal أو open_join أو challenge.'
    );
  END IF;

  IF v_raw_type = 'challenge' THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'USE_CHALLENGE_RPC',
      'error', 'USE_CHALLENGE_RPC',
      'message', 'حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.'
    );
  END IF;

  v_normalized_type := v_raw_type;

  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  IF v_caller IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller;
    IF v_caller::text <> p_user_id
       AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')
       AND current_user NOT IN ('postgres', 'service_role')
    THEN
      RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;
  END IF;

  -- Idempotency protection
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.bookings
    WHERE idempotency_key = p_idempotency_key AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true);
    END IF;
  END IF;

  -- Time validation against platform business rules
  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  -- Advisory lock per stadium to serialize slot bookings
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  -- Validate Stadium
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
  END IF;
  IF v_stadium.is_deleted_by_owner THEN
    RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف.');
  END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  -- User Account & Cash Rules
  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id::text = p_user_id;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, '')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
  END IF;

  -- Active Cash Booking Limit
  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') AND end_time > v_now;
  IF lower(COALESCE(p_payment_method, '')) = 'cash' AND v_active_cash_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي قائم بالفعل. يجب لعبه أولاً أو الدفع إلكترونياً.');
  END IF;

  -- Authoritative Server-Side Pricing
  v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
  v_final_deposit_amount := CASE WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END;

  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_calculated_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_calculated_price := v_calculated_price + v_ball_price;
  END IF;
  IF v_calculated_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'تسعيرة الملعب غير صحيحة.');
  END IF;
  v_final_total_price := v_calculated_price;

  -- Payment Status and Lock Window
  IF lower(COALESCE(p_payment_method, '')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status  := 'pending';
    v_final_is_paid := false;
    v_locked_until  := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status  := 'confirmed';
    v_final_is_paid := false;
    v_locked_until  := NULL;
  END IF;

  -- Slot Availability Check
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;
  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  -- GATE 2: Open Join Strict Integrity
  IF v_normalized_type = 'open_join' THEN
    v_initial_players := COALESCE(p_initial_players, 1);
    IF v_initial_players < 1 THEN
      RETURN jsonb_build_object('success', false, 'code', 'INVALID_INITIAL_PLAYERS',
        'message', 'عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;

    -- Authoritative total field capacity
    v_capacity := COALESCE(p_total_capacity, v_stadium.total_field_capacity, 10);
    IF v_capacity < 1 THEN v_capacity := 10; END IF;

    -- Strict validation: initial players CANNOT exceed capacity!
    IF v_initial_players > v_capacity THEN
      RETURN jsonb_build_object('success', false, 'code', 'INITIAL_PLAYERS_EXCEED_CAPACITY',
        'message', 'عدد اللاعبين المبدئي (' || v_initial_players || ') لا يمكن أن يتجاوز سعة الملعب (' || v_capacity || ').');
    END IF;
  ELSE
    v_initial_players := 1;
    v_capacity := NULL;
  END IF;

  -- Insert Booking (challenge_status is NULL for personal and open_join)
  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type, total_price, vsp_commission, gateway_fee, platform_fee,
    stadium_name, stadium_image_url, is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key, created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, p_user_id::uuid, p_user_id::uuid, v_stadium.owner_id,
    p_start_time, p_end_time, v_normalized_type,
    v_final_total_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    p_is_private, p_rent_ball,
    v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
    lower(COALESCE(p_payment_method, 'cash')), 'pending', v_final_status, v_final_is_paid,
    CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
    p_player_team_name,
    CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
    p_opponent_team_name,
    NULL,
    ARRAY[p_user_id::uuid], v_initial_players, v_initial_players, v_capacity,
    v_locked_until, p_idempotency_key, v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success',              true,
    'booking_id',           v_new_booking_id,
    'status',               v_final_status,
    'total_price',          v_final_total_price,
    'needs_deposit',        v_final_needs_deposit,
    'deposit_amount',       v_final_deposit_amount,
    'initial_players',      v_initial_players,
    'total_capacity',       v_capacity,
    'requires_full_online', (v_active_cash_count > 0 AND lower(COALESCE(p_payment_method, '')) IN ('paymob', 'card', 'wallet', 'online')),
    'locked_until',         v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$;
