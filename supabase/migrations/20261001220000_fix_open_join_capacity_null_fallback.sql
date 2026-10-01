-- Migration: 20261001220000_fix_open_join_capacity_null_fallback.sql
-- Remove hardcoded fallback capacity (10) in create_booking_atomic.
-- If stadium.total_field_capacity IS NULL, reject open_join booking creation.
-- All existing active stadiums confirmed to have a real capacity value.

CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_stadium_id text,
  p_user_id text,
  p_owner_id text,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_booking_type text,
  p_total_price numeric,
  p_stadium_name text DEFAULT ''::text,
  p_stadium_image_url text DEFAULT ''::text,
  p_is_private boolean DEFAULT true,
  p_rent_ball boolean DEFAULT false,
  p_needs_deposit boolean DEFAULT false,
  p_deposit_amount numeric DEFAULT 0,
  p_payment_method text DEFAULT 'cash'::text,
  p_payment_status text DEFAULT 'pending'::text,
  p_player_team_id text DEFAULT NULL::text,
  p_player_team_name text DEFAULT NULL::text,
  p_opponent_team_id text DEFAULT NULL::text,
  p_opponent_team_name text DEFAULT NULL::text,
  p_platform_fee numeric DEFAULT 0,
  p_idempotency_key text DEFAULT NULL::text,
  p_initial_players integer DEFAULT 1,
  p_total_capacity integer DEFAULT NULL::integer
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
  v_raw_type := lower(trim(COALESCE(p_booking_type, '')));
  IF v_raw_type = 'openjoin' THEN v_raw_type := 'open_join'; END IF;

  IF v_raw_type NOT IN ('personal', 'open_join', 'challenge') THEN
    RETURN jsonb_build_object('success', false, 'code', 'INVALID_BOOKING_TYPE',
      'message', 'نوع الحجز غير صالح.');
  END IF;

  IF v_raw_type = 'challenge' THEN
    RETURN jsonb_build_object('success', false, 'code', 'USE_CHALLENGE_RPC',
      'message', 'حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.');
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

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.bookings
    WHERE idempotency_key = p_idempotency_key AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true);
    END IF;
  END IF;

  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

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

  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id::text = p_user_id;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, '')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي.');
  END IF;

  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') AND end_time > v_now;
  IF lower(COALESCE(p_payment_method, '')) = 'cash' AND v_active_cash_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي قائم بالفعل.');
  END IF;

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

  IF lower(COALESCE(p_payment_method, '')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status  := 'pending';
    v_final_is_paid := false;
    v_locked_until  := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status  := 'confirmed';
    v_final_is_paid := false;
    v_locked_until  := NULL;
  END IF;

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

  -- GATE: Open Join — NO FALLBACK CAPACITY (SSOT fix)
  IF v_normalized_type = 'open_join' THEN
    v_initial_players := COALESCE(p_initial_players, 1);
    IF v_initial_players < 1 THEN
      RETURN jsonb_build_object('success', false, 'code', 'INVALID_INITIAL_PLAYERS',
        'message', 'عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;

    -- Use DB value directly — no COALESCE fallback
    v_capacity := v_stadium.total_field_capacity;

    IF v_capacity IS NULL OR v_capacity < 1 THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'STADIUM_CAPACITY_NOT_CONFIGURED',
        'message', 'هذا الملعب لا تتوفر له سعة محددة. لا يمكن إنشاء حجز مفتوح حتى يقوم المالك بتحديد السعة.'
      );
    END IF;

    IF v_initial_players > v_capacity THEN
      RETURN jsonb_build_object('success', false, 'code', 'INITIAL_PLAYERS_EXCEED_CAPACITY',
        'message', 'عدد اللاعبين المبدئي (' || v_initial_players || ') لا يمكن أن يتجاوز سعة الملعب (' || v_capacity || ').');
    END IF;
  ELSE
    v_initial_players := 1;
    v_capacity := NULL;
  END IF;

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

GRANT EXECUTE ON FUNCTION public.create_booking_atomic TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.create_booking_atomic FROM anon, public;
