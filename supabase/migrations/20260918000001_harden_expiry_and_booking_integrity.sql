-- ==============================================================================
-- Migration: 20260918000001_harden_expiry_and_booking_integrity.sql
-- Description:
--   1. Drop dead 2-argument overload of cancel_booking_with_refund_atomic.
--   2. Upgrade auto_expire_stale_records (the active cron) to clean up expired 5-min locked_until slots.
--   3. Fix platform_fee assignment in create_booking_atomic (vsp_commission instead of duplicate gateway_fee).
--   4. Wrap booking INSERT with exclusion_violation exception guard to return clean JSON errors on rare race conditions.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DROP DEAD 2-ARGUMENT OVERLOAD
-- ------------------------------------------------------------------------------
-- Verified: zero callers in client apps (which pass 3 args) and zero internal callers in schema.
DROP FUNCTION IF EXISTS public.cancel_booking_with_refund_atomic(uuid, text);


-- ------------------------------------------------------------------------------
-- 2. UPGRADE auto_expire_stale_records (ACTIVE CRON JOB)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.auto_expire_stale_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  -- 2.1 إلغاء الحجوزات المعلقة التي انتهى وقت قفلها المؤقت (5 دقائق / locked_until)
  -- هذا يحرر الـ slot فوراً أمام قيد الاستبعاد EXCLUDE constraint
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    payment_status = CASE WHEN payment_status = 'pending' THEN 'failed' ELSE payment_status END,
    cancellation_reason = 'Payment session expired (auto-lock timeout)',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to lock timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND (
      (locked_until IS NOT NULL AND locked_until < NOW())
      OR
      (locked_until IS NULL AND created_at <= NOW() - INTERVAL '5 minutes')
    );

  -- 2.2 إلغاء الحجوزات المعلقة القديمة غير المدفوعة بعد 10 دقائق (Safety Fallback)
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    payment_status = 'failed',
    cancellation_reason = 'Payment session expired (10m fallback timeout)',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- 2.3 إلغاء التحديات المعلقة إذا مر عليها 4 ساعات أو اقتربت المباراة لأقل من 12 ساعة
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge'
    AND status = 'pending'
    AND (
      NOW() - created_at >= INTERVAL '4 hours' OR
      start_time - NOW() <= INTERVAL '12 hours'
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.auto_expire_stale_records() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_expire_stale_records() TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3. HARDEN create_booking_atomic (FINANCIAL INTEGRITY & EXCEPTION GUARD)
-- ------------------------------------------------------------------------------
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
    p_platform_fee numeric DEFAULT 0.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_stadium_uuid UUID;
    v_user_uuid UUID;
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
    v_now TIMESTAMPTZ := now();
    
    -- Operating hours variables (Cairo local time)
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
BEGIN
    -- 1. Identity & Zero-Trust Caller check
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإجراء حجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- Validate UUID upfront
    IF p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_stadium_uuid := p_stadium_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف الملعب غير صالح.');
    END IF;

    IF p_user_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_user_uuid := p_user_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف المستخدم غير صالح.');
    END IF;

    -- 2. Duration validity (30 minutes to 8 hours)
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;

    IF v_duration_hours < 0.5 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تقل عن 30 دقيقة.');
    END IF;

    IF v_duration_hours > 8.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تتجاوز 8 ساعات في المرة الواحدة.');
    END IF;

    -- 3. Concurrency Lock on Stadium (Advisory Lock per stadium)
    PERFORM pg_advisory_xact_lock(hashtext(v_stadium_uuid::text));

    -- 4. Verify stadium existence and status
    SELECT * INTO v_stadium 
    FROM public.stadiums 
    WHERE id = v_stadium_uuid;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- Deposit Enforcement: Reject full cash if owner requires an online deposit
    IF COALESCE(v_stadium.needs_deposit, false) IS TRUE AND p_payment_method = 'cash' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'DEPOSIT_REQUIRED',
            'message', 'عذراً، هذا الملعب يشترط دفع عربون إلكتروني أونلاين لتأكيد الحجز ولا يقبل الحجز النقدي الكامل.'
        );
    END IF;

    -- 5. Operating Hours & Split-Shift Validation (Cairo Local Time)
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
            RETURN jsonb_build_object(
                'success', false,
                'code', 'OUTSIDE_OPERATING_HOURS',
                'message', 'عذراً، هذا الموعد خارج أوقات عمل الملعب الرسمية (' || v_stadium.opening_time || ' - ' || v_stadium.closing_time || ').'
            );
        END IF;

        -- Split-shift break validation
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
                RETURN jsonb_build_object(
                    'success', false,
                    'code', 'OUTSIDE_OPERATING_HOURS',
                    'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).'
                );
            END IF;
        END IF;
    END IF;

    -- 6. Server-Authoritative Price Calculation
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
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام.'
        );
    END IF;

    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. Platform Commission and Gateway Fee
    v_vsp_commission := round(v_final_total_price * 0.02, 2);
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_gateway_fee := round((v_final_total_price * 0.0475) + 3.0, 2);
    ELSE
        v_gateway_fee := 0.00;
    END IF;

    -- 8. User state & No-show checks
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id = v_user_uuid;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. Cash Booking: Check Owner Debt Limit (Fail-Closed)
    IF p_payment_method = 'cash' THEN
        IF v_final_owner_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'بيانات مالك الملعب غير مكتملة.');
        END IF;

        SELECT accumulated_cash_debt, debt_limit, is_debt_blocked 
        INTO v_owner
        FROM public.users 
        WHERE id = v_final_owner_id;

        IF NOT FOUND OR v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.0) THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'DEBT_LIMIT_EXCEEDED',
                'message', 'عذراً، تم إيقاف الحجز النقدي لهذا الملعب مؤقتاً لتجاوز حد المديونية المسموح. يرجى الدفع إلكترونياً.'
            );
        END IF;

        -- One active cash booking per user restriction
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id = v_user_uuid OR created_by_user_id = v_user_uuid)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Direct UUID Index Search + Overlap Check
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id = v_stadium_uuid
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
      AND (p_start_time < end_time AND p_end_time > start_time);

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SLOT_LOCKED_OR_TAKEN',
            'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.'
        );
    END IF;

    -- 11. Booking status assignment
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := v_now + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 12. Insert Booking Record (Wrapped in Exception Guard)
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, user_id, created_by_user_id, owner_id,
            start_time, end_time, booking_type, total_price, 
            vsp_commission, gateway_fee, platform_fee,
            stadium_name, stadium_image_url, is_private, rent_ball,
            needs_deposit, deposit_amount, deposit_paid,
            payment_method, payment_status, status, is_paid,
            player_team_id, player_team_name, opponent_team_id, opponent_team_name,
            joined_user_ids, locked_until, created_at, updated_at
        ) VALUES (
            v_stadium_uuid,
            v_user_uuid, 
            v_user_uuid, 
            v_final_owner_id,
            p_start_time, 
            p_end_time, 
            p_booking_type, 
            v_final_total_price,
            v_vsp_commission, 
            v_gateway_fee, 
            v_vsp_commission, -- ✅ Fix: platform_fee stores real vsp_commission, not gateway_fee
            COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
            COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
            p_is_private, 
            p_rent_ball,
            v_final_needs_deposit, 
            v_final_deposit_amount, 
            0.0,
            p_payment_method, 
            'pending', 
            v_final_status, 
            v_final_is_paid,
            CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
            p_player_team_name,
            CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
            p_opponent_team_name,
            ARRAY[v_user_uuid], 
            v_locked_until, 
            v_now, 
            v_now
        )
        RETURNING id INTO v_new_booking_id;

    EXCEPTION 
        WHEN unique_violation OR exclusion_violation THEN
            -- 🛡️ Catch kernel-level collision and return clean JSON response instead of Postgres 500 / 23P01 error
            RETURN jsonb_build_object(
                'success', false,
                'code', 'SLOT_LOCKED_OR_TAKEN',
                'message', 'عذراً، تم حجز هذا الموعد للتو من قِبل لاعب آخر.'
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
        'locked_until', v_locked_until
    );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.create_booking_atomic(text, text, text, timestamp with time zone, timestamp with time zone, text, numeric, text, text, boolean, boolean, boolean, numeric, text, text, text, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_booking_atomic(text, text, text, timestamp with time zone, timestamp with time zone, text, numeric, text, text, boolean, boolean, boolean, numeric, text, text, text, text, text, text, numeric) TO authenticated, service_role;
