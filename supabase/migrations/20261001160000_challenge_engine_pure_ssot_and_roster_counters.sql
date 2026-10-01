-- Migration: 20261001160000_challenge_engine_pure_ssot_and_roster_counters.sql
-- Description:
--   1. Challenge Player Counters: Challenge matches do NOT use current_players / capacity to represent teams.
--      current_players, initial_players_count, total_field_capacity are set to NULL.
--   2. Authoritative Team Eligibility: Validates teams, captain authorization, and FairPlay (attendance_score >= 40)
--      entirely on the server.
--   3. Idempotency Gate: Safe retry with idempotency_key returning the existing booking on network drops.
--   4. Challenge Code Atomic Consumption: Validates, locks, consumes code, and generates replacement with 7-day expiry.

CREATE OR REPLACE FUNCTION public.create_challenge_booking_atomic(
  p_challenge_code  text,
  p_stadium_id      text,
  p_start_time      timestamptz,
  p_end_time        timestamptz,
  p_payment_method  text    DEFAULT 'cash',
  p_rent_ball       boolean DEFAULT false,
  p_idempotency_key text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller                 uuid := auth.uid();
  v_caller_role            text;
  v_caller_team            record;
  v_code_entry             record;
  v_opponent_team          record;
  v_stadium                record;
  v_duration_hours         numeric;
  v_hourly_rate            numeric;
  v_price                  numeric;
  v_ball_price             numeric := 0;
  v_final_status           text;
  v_final_challenge_status text;
  v_final_is_paid          boolean;
  v_locked_until           timestamptz;
  v_conflict_count         int;
  v_active_cash_cnt        int := 0;
  v_user_blocked           boolean;
  v_no_show_count          int;
  v_new_booking_id         uuid;
  v_new_code               text;
  v_new_code_id            uuid;
  v_existing_id            uuid;
  v_existing_status        text;
  v_clean_code             text;
  v_now                    timestamptz := timezone('utc', now());
BEGIN
  -- 1. Authentication check
  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED',
      'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  -- 2. Strengthened User-Scoped Idempotency protection
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT id, status, user_id INTO v_existing_id, v_existing_status, v_existing_user_id
    FROM public.bookings
    WHERE idempotency_key = trim(p_idempotency_key) AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      IF v_existing_user_id IS NOT NULL AND v_caller IS NOT NULL AND v_existing_user_id <> v_caller THEN
        RETURN jsonb_build_object(
          'success', false,
          'error',   'IDEMPOTENCY_KEY_COLLISION',
          'message', 'مفتاح العملية غير صالح أو مستخدم مسبقاً لحساب آخر.'
        );
      END IF;

      RETURN jsonb_build_object(
        'success',     true,
        'booking_id',  v_existing_id,
        'status',      v_existing_status,
        'idempotent',  true
      );
    END IF;
  END IF;

  -- Normalize challenge code (strip 'VSP-' prefix if provided)
  v_clean_code := upper(trim(COALESCE(p_challenge_code, '')));
  IF v_clean_code LIKE 'VSP-%' THEN
    v_clean_code := substring(v_clean_code from 5);
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CHALLENGE_CODE',
      'message', 'يرجى إدخال كود التحدي.');
  END IF;

  -- 3. Verify caller is a captain of an active team
  SELECT t.* INTO v_caller_team 
  FROM public.teams t 
  WHERE t.captain_id = v_caller 
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN',
      'message', 'يجب أن تكون كابتن فريق لإنشاء حجز تحدي.');
  END IF;

  -- 4. Verify & lock challenge code (match either raw code or with prefix)
  SELECT * INTO v_code_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = 'VSP-' || v_clean_code) AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_INVALID_OR_USED',
      'message', 'كود التحدي غير صالح أو تم استخدامه مسبقاً.');
  END IF;

  IF v_code_entry.expires_at IS NOT NULL AND v_code_entry.expires_at < v_now THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_code_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_EXPIRED',
      'message', 'كود التحدي منتهي الصلاحية.');
  END IF;

  -- 5. Opponent team validation & Server-Side Eligibility
  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND',
      'message', 'تعذر العثور على الفريق صاحب الكود.');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM',
      'message', 'لا يمكنك تحدي فريقك نفسه.');
  END IF;

  -- Server-Side FairPlay Eligibility (attendance_score >= 40)
  IF COALESCE(v_caller_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'فريقك مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  IF COALESCE(v_opponent_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'الفريق المنافس مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  -- 6. Platform business rules: Duration check
  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TIME_RANGE',
      'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DURATION',
      'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  -- 7. Advisory lock per stadium to serialize slot bookings
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  -- 8. Validate stadium
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_FOUND',
      'message', 'الملعب المطلوب غير موجود.');
  END IF;
  IF COALESCE(v_stadium.is_deleted_by_owner, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_DELETED',
      'message', 'عذراً، هذا الملعب محذوف.');
  END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE',
      'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  -- 9. User Account & Cash Rules (Same SSOT as create_booking_atomic)
  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id = v_caller;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED',
      'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'CASH_LIMIT_EXCEEDED',
      'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
  END IF;

  SELECT COUNT(*) INTO v_active_cash_cnt
  FROM public.bookings
  WHERE (user_id = v_caller OR created_by_user_id = v_caller)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') AND end_time > v_now;
  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash' AND v_active_cash_cnt > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي قائم بالفعل. يجب لعبه أولاً أو الدفع إلكترونياً.');
  END IF;

  -- 10. Authoritative Server-Side Pricing
  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_price := v_price + v_ball_price;
  END IF;
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_PRICE_NOT_SET',
      'message', 'تسعيرة الملعب غير صحيحة.');
  END IF;

  -- 11. Slot conflict check
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع حالياً.');
  END IF;

  -- 12. Status and Payment Lock Window: Perfect SSOT State Alignment
  IF lower(COALESCE(p_payment_method, 'cash')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status           := 'pending';
    v_final_challenge_status := 'ready';       -- Ready, awaiting payment confirmation
    v_final_is_paid          := false;
    v_locked_until           := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status           := 'confirmed';
    v_final_challenge_status := 'confirmed';   -- Confirmed immediately for cash
    v_final_is_paid          := false;
    v_locked_until           := NULL;
  END IF;

  -- 13. Insert Booking (Player counters are NULL for Challenge matches)
  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type,
    total_price, platform_fee, vsp_commission, gateway_fee,
    stadium_name, stadium_image_url,
    is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key,
    created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, v_caller, v_caller, v_stadium.owner_id,
    p_start_time, p_end_time, 'challenge',
    v_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    true, p_rent_ball,
    COALESCE(v_stadium.needs_deposit, false),
    CASE WHEN COALESCE(v_stadium.needs_deposit, false) THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END,
    0,
    lower(COALESCE(p_payment_method, 'cash')), 'pending',
    v_final_status, v_final_is_paid,
    v_caller_team.id, v_caller_team.name,
    v_opponent_team.id, v_opponent_team.name,
    v_final_challenge_status,
    ARRAY[v_caller], NULL, NULL, NULL,
    v_locked_until, p_idempotency_key,
    v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  -- 14. Consume challenge code
  UPDATE public.team_challenge_codes
  SET status = 'used', used_at = v_now, used_in_booking_id = v_new_booking_id
  WHERE id = v_code_entry.id;

  -- 15. Generate fresh replacement challenge code for opponent team with 7-day expiration
  v_new_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (v_opponent_team.id, v_new_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_new_code_id;

  RETURN jsonb_build_object(
    'success',            true,
    'booking_id',         v_new_booking_id,
    'status',             v_final_status,
    'challenge_status',   v_final_challenge_status,
    'total_price',        v_price,
    'player_team_id',     v_caller_team.id,
    'player_team_name',   v_caller_team.name,
    'opponent_team_id',   v_opponent_team.id,
    'opponent_team_name', v_opponent_team.name,
    'new_opponent_code',  v_new_code,
    'locked_until',       v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$;

REVOKE ALL ON FUNCTION public.create_challenge_booking_atomic FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge_booking_atomic TO authenticated, service_role;
