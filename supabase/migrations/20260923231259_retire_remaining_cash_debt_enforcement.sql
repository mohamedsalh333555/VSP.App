-- Migration version: 20260923231259
-- Retire the final owner cash-debt enforcement paths.
-- Cash bookings use 0% VSP commission and never depend on debt_limit/is_debt_blocked.
CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0.0, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_new_booking_id UUID;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0;
    v_duration_hours NUMERIC;
    v_final_total_price NUMERIC;
    v_vsp_commission NUMERIC;
    v_gateway_fee NUMERIC := 0.00;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_deposit_paid NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_locked_until TIMESTAMPTZ;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_conflict_count INT;
    v_final_owner_id UUID;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
    v_existing_booking_id UUID;
    v_existing_status TEXT;
BEGIN
    -- Idempotency Check
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, status INTO v_existing_booking_id, v_existing_status
        FROM public.bookings
        WHERE idempotency_key = p_idempotency_key
          AND status != 'cancelled'
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'success', true,
                'booking_id', v_existing_booking_id,
                'status', v_existing_status,
                'idempotent', true,
                'message', 'تم إرجاع حجز موجود مسبقاً (idempotent response).'
            );
        END IF;
    END IF;

    -- 1. Identity & Caller check
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. Duration validity
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;
    IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id=1) / 60.0) THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تقل عن 30 دقيقة.');
    END IF;
    IF v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id=1) THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تتجاوز 8 ساعات في المرة الواحدة.');
    END IF;

    -- 3. Concurrency Lock on Stadium
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Verify stadium
    SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;
    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;
    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. Operating Hours
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;
    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
        ELSE
            IF v_start_cairo::time >= v_stadium.opening_time THEN
                v_open_ts := v_date_cairo + v_stadium.opening_time;
                v_close_ts := (v_date_cairo + interval '1 day') + v_stadium.closing_time;
            ELSE
                v_open_ts := (v_date_cairo - interval '1 day') + v_stadium.opening_time;
                v_close_ts := v_date_cairo + v_stadium.closing_time;
            END IF;
        END IF;
        IF v_start_cairo < v_open_ts OR v_end_cairo > v_close_ts THEN
            RETURN jsonb_build_object('success', false, 'code', 'OUTSIDE_OPERATING_HOURS', 'message', 'عذراً، هذا الموعد خارج أوقات عمل الملعب الرسمية (' || v_stadium.opening_time || ' - ' || v_stadium.closing_time || ').');
        END IF;
        IF v_stadium.is_split_shift IS TRUE AND v_stadium.break_start_time IS NOT NULL AND v_stadium.break_end_time IS NOT NULL THEN
            IF v_stadium.break_start_time >= v_stadium.opening_time THEN
                v_break_start_ts := v_open_ts::date + v_stadium.break_start_time;
            ELSE
                v_break_start_ts := (v_open_ts::date + interval '1 day') + v_stadium.break_start_time;
            END IF;
            IF v_stadium.break_end_time >= v_stadium.break_start_time THEN
                v_break_end_ts := v_break_start_ts::date + v_stadium.break_end_time;
            ELSE
                v_break_end_ts := (v_break_start_ts::date + interval '1 day') + v_stadium.break_end_time;
            END IF;
            IF v_start_cairo < v_break_end_ts AND v_end_cairo > v_break_start_ts THEN
                RETURN jsonb_build_object('success', false, 'code', 'OUTSIDE_OPERATING_HOURS', 'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).');
            END IF;
        END IF;
    END IF;

    -- 6. Server-Side Price Calculation
    v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
    v_calculated_price := round(v_hourly_rate * v_duration_hours, 2);
    IF p_rent_ball IS TRUE THEN
        BEGIN
            v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0.0);
        EXCEPTION WHEN OTHERS THEN
            v_ball_price := 0.0;
        END;
        v_calculated_price := v_calculated_price + v_ball_price;
    END IF;
    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.');
    END IF;
    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. Payment fees are resolved from the actual payment transaction.
    -- At booking creation there is no confirmed payment amount yet.
    v_vsp_commission := 0.00;
    v_gateway_fee := 0.00;

    -- 8. User state checks
    SELECT is_blocked, COALESCE(no_show_count, 0) INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;
    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;
    IF p_payment_method = 'cash' AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id=1) THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. Cash collection has no owner debt limit; retain only the active-cash guard.
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash' AND is_paid = FALSE
          AND status IN ('pending', 'confirmed') AND end_time > v_now;
        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Conflict detection (8 minutes lock window)
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1) || ' minutes')::interval) < v_now)
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );
    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN', 'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.');
    END IF;

    -- 11. Status assignment & 8 minutes lock
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1) || ' minutes')::interval;
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 12. Insert Booking
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, user_id, created_by_user_id, owner_id,
            start_time, end_time, booking_type, total_price,
            vsp_commission, gateway_fee, platform_fee,
            stadium_name, stadium_image_url, is_private, rent_ball,
            needs_deposit, deposit_amount, deposit_paid,
            payment_method, payment_status, status, is_paid,
            player_team_id, player_team_name, opponent_team_id, opponent_team_name,
            joined_user_ids, locked_until, idempotency_key, created_at, updated_at
        ) VALUES (
            CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
            p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
            p_start_time, p_end_time, p_booking_type, v_final_total_price,
            v_vsp_commission, v_gateway_fee, v_vsp_commission,
            COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name),
            COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url),
            p_is_private, p_rent_ball,
            v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
            p_payment_method, 'pending', v_final_status, v_final_is_paid,
            CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
            p_player_team_name,
            CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
            p_opponent_team_name,
            ARRAY[p_user_id::uuid], v_locked_until, p_idempotency_key, v_now, v_now
        )
        RETURNING id INTO v_new_booking_id;
    EXCEPTION
        WHEN unique_violation OR exclusion_violation THEN
            IF p_idempotency_key IS NOT NULL THEN
                SELECT id, status INTO v_existing_booking_id, v_existing_status
                FROM public.bookings
                WHERE idempotency_key = p_idempotency_key AND status != 'cancelled' LIMIT 1;
                IF FOUND THEN
                    RETURN jsonb_build_object(
                        'success', true,
                        'booking_id', v_existing_booking_id,
                        'status', v_existing_status,
                        'idempotent', true,
                        'message', 'تم إرجاع حجز موجود مسبقاً (idempotent response).'
                    );
                END IF;
            END IF;
            RETURN jsonb_build_object(
                'success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
                'message', 'عذراً، تم حجز هذا الموعد للتو من قِبل لاعب آخر. يرجى اختيار موعد مختلف.'
            );
    END;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'vsp_commission', v_vsp_commission,
        'gateway_fee', v_gateway_fee,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until,
        'idempotent', false
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'إلغاء حجز من المستخدم'::text, p_user_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_refund_amount numeric(10,2) := 0;
  v_tx_id uuid := NULL;
  v_caller_role text;
  v_minutes_since_created numeric;
  v_now timestamptz := timezone('utc', now());
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'code', 'cannot_cancel_completed_booking', 'message', 'لا يمكن إلغاء حجز مكتمل.');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object(
      'success', true, 'code', 'already_cancelled', 'already_cancelled', true,
      'booking_id', p_booking_id, 'refund_amount', coalesce(v_booking.refund_amount, 0)
    );
  END IF;

  IF coalesce(auth.role(), '') <> 'service_role'
     AND current_user NOT IN ('postgres','service_role') THEN
    IF auth.uid() IS NULL THEN
      RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

    IF auth.uid() IS DISTINCT FROM v_booking.created_by_user_id
       AND auth.uid() IS DISTINCT FROM v_booking.user_id
       AND auth.uid() IS DISTINCT FROM v_booking.owner_id
       AND coalesce(v_caller_role, '') NOT IN ('admin','co_founder','super_admin','cofounder') THEN
      RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: لا يمكنك إلغاء هذا الحجز.');
    END IF;

    IF auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id THEN
      v_minutes_since_created := extract(epoch from (v_now - coalesce(v_booking.created_at, v_now))) / 60.0;
      IF v_minutes_since_created > (SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id=1)
         AND v_booking.start_time <= (v_now + ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id=1) * INTERVAL '1 hour')) THEN
        RETURN jsonb_build_object(
          'success', false, 'code', 'cannot_cancel_within_6_hours',
          'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات إلا خلال أول 20 دقيقة.'
        );
      END IF;
    END IF;
  END IF;

  IF v_booking.payment_status IN ('paid','confirmed','partially_paid')
     OR v_booking.is_paid IS TRUE
     OR v_booking.is_deposit_paid IS TRUE THEN
    v_refund_amount := coalesce(
      nullif(v_booking.deposit_paid, 0),
      v_booking.deposit_amount,
      v_booking.total_price,
      0
    );
  END IF;

  UPDATE public.bookings
  SET
    status = 'cancelled',
    is_paid = false,
    payment_status = CASE
      WHEN v_refund_amount > 0 AND lower(coalesce(payment_method,'')) <> 'cash'
        THEN 'refund_pending'
      WHEN v_refund_amount > 0 THEN 'refunded'
      ELSE payment_status
    END,
    refund_amount = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
    cancellation_reason = p_reason,
    cancelled_at = v_now,
    updated_at = v_now
  WHERE id = p_booking_id;

  IF v_refund_amount > 0
     AND NOT EXISTS (
       SELECT 1 FROM public.transactions
       WHERE booking_id = p_booking_id
         AND type IN ('refund','refund_card','refund_wallet','refund_cash','refund_pending')
         AND status IN ('pending','completed')
     ) THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, type, status, payment_method, description, created_at, updated_at
    ) VALUES (
      coalesce(v_booking.created_by_user_id, v_booking.user_id),
      p_booking_id,
      v_refund_amount,
      'refund',
      CASE WHEN lower(coalesce(v_booking.payment_method,'')) = 'cash'
           THEN 'completed' ELSE 'pending' END,
      coalesce(v_booking.payment_method,'online'),
      CASE WHEN lower(coalesce(v_booking.payment_method,'')) = 'cash'
           THEN 'استرداد نقدي بالملعب لإلغاء الحجز'
           ELSE 'طلب استرداد إلكتروني قيد المعالجة' END,
      v_now,
      v_now
    )
    RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم إلغاء الحجز بنجاح.',
    'refund_amount', v_refund_amount,
    'payment_status', CASE
      WHEN v_refund_amount > 0 AND lower(coalesce(v_booking.payment_method,'')) <> 'cash'
        THEN 'refund_pending'
      ELSE 'refunded'
    END,
    'booking_id', p_booking_id,
    'transaction_id', v_tx_id
  );
END;
$function$
;
