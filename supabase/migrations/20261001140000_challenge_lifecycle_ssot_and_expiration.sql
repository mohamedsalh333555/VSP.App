-- Migration: 20261001140000_challenge_lifecycle_ssot_and_expiration.sql
-- Description:
--   1. Strict SSOT for challenge_status: purge 'none' completely from check constraint.
--   2. Enforce 7-day expiration lifecycle on team_challenge_codes (generate & replacement).
--   3. Align create_challenge_booking_atomic:
--      - Online payment -> booking.status = 'pending', challenge_status = 'ready'
--      - Cash payment   -> booking.status = 'confirmed', challenge_status = 'confirmed'
--   4. Trigger synchronization: booking status transitions automatically maintain challenge_status.

-- 1. Strict SSOT Constraint for challenge_status (No 'none' permitted)
ALTER TABLE public.bookings ALTER COLUMN challenge_status DROP DEFAULT;
ALTER TABLE public.bookings ALTER COLUMN challenge_status SET DEFAULT NULL;

-- Clean up any residual 'none' values if any exist
UPDATE public.bookings SET challenge_status = NULL WHERE challenge_status = 'none';

ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_challenge_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_challenge_status_check 
  CHECK (challenge_status IS NULL OR challenge_status = ANY (ARRAY['ready'::text, 'confirmed'::text, 'completed'::text, 'cancelled'::text, 'expired'::text]));

-- 2. Update generate_team_challenge_code to enforce 7-day expiration
CREATE OR REPLACE FUNCTION public.generate_team_challenge_code(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_team     record;
  v_code     text;
  v_code_id  uuid;
  v_now      timestamptz := timezone('utc', now());
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  -- Expire any active code that has passed its expiration
  UPDATE public.team_challenge_codes
  SET status = 'expired'
  WHERE team_id = p_team_id AND status = 'active' AND expires_at IS NOT NULL AND expires_at < v_now;

  -- Return existing active, unexpired code if present
  SELECT code, id INTO v_code, v_code_id
  FROM public.team_challenge_codes
  WHERE team_id = p_team_id AND status = 'active'
    AND (expires_at IS NULL OR expires_at > v_now)
  ORDER BY created_at DESC LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'code', v_code,
      'code_id', v_code_id,
      'team_id', p_team_id,
      'team_name', v_team.name,
      'expires_at', (SELECT expires_at FROM public.team_challenge_codes WHERE id = v_code_id)
    );
  END IF;

  -- Generate fresh code with strict 7-day expiration
  v_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (p_team_id, v_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_code_id;

  RETURN jsonb_build_object(
    'success', true,
    'code', v_code,
    'code_id', v_code_id,
    'team_id', p_team_id,
    'team_name', v_team.name,
    'expires_at', v_now + INTERVAL '7 days'
  );
END;
$function$;

-- 3. Update create_challenge_booking_atomic with state alignment and 7-day replacement code
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

  -- Normalize challenge code (strip 'VSP-' prefix if provided)
  v_clean_code := upper(trim(p_challenge_code));
  IF v_clean_code LIKE 'VSP-%' THEN
    v_clean_code := substring(v_clean_code from 5);
  END IF;

  -- 2. Idempotency check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.bookings
    WHERE idempotency_key = p_idempotency_key AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true);
    END IF;
  END IF;

  -- 3. Verify caller is a captain
  SELECT t.* INTO v_caller_team FROM public.teams t WHERE t.captain_id = v_caller LIMIT 1;
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

  -- 5. Opponent team validation
  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND',
      'message', 'تعذر العثور على الفريق صاحب الكود.');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM',
      'message', 'لا يمكنك تحدي فريقك نفسه.');
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

  -- 13. Insert Booking
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
    ARRAY[v_caller], 2, 2, 2,
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

-- 4. Trigger to maintain 1:1 challenge_status synchronization on booking status transitions
CREATE OR REPLACE FUNCTION public.trg_sync_challenge_booking_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  IF NEW.booking_type = 'challenge' THEN
    IF NEW.status = 'confirmed' AND (OLD.status IS DISTINCT FROM 'confirmed' OR NEW.challenge_status = 'ready') THEN
      NEW.challenge_status := 'confirmed';
    ELSIF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
      NEW.challenge_status := 'cancelled';
    ELSIF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
      NEW.challenge_status := 'completed';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_sync_challenge_booking_status ON public.bookings;
CREATE TRIGGER trg_sync_challenge_booking_status
  BEFORE UPDATE OF status ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_sync_challenge_booking_status();

-- 5. Permissions
REVOKE ALL ON FUNCTION public.generate_team_challenge_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_team_challenge_code(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_challenge_booking_atomic FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge_booking_atomic TO authenticated, service_role;
