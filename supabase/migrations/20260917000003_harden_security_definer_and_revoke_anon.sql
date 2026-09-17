-- ==============================================================================
-- Migration: 20260917000003_harden_security_definer_and_revoke_anon.sql
-- Description: Comprehensive hardening of all SECURITY DEFINER functions across VSP.
--
-- Defense-in-Depth Architecture:
-- 1. Layer 1 (Transport & PostgREST Barrier): 
--    REVOKE EXECUTE ON FUNCTION ... FROM PUBLIC, anon;
--    GRANT EXECUTE ON FUNCTION ... TO authenticated, service_role; (or service_role only for cron)
-- 2. Layer 2 (Search Path Sanitization):
--    SET search_path = public, pg_temp; to mitigate search_path hijacking attacks.
-- 3. Layer 3 (Identity & Role Invariant Enforcement):
--    Strict auth.uid() checks preventing unauthenticated or unauthorized callers from executing.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- PART 1: RE-DEFINE SENSITIVE FUNCTIONS WITH STRICT INVARIANTS & SEARCH_PATH
-- ------------------------------------------------------------------------------

-- 1.1 [GROUP A] admin_register_owner_on_behalf
-- Ensures ONLY authenticated admins/co-founders or service_role can create accounts on behalf.
CREATE OR REPLACE FUNCTION public.admin_register_owner_on_behalf(
    p_email text, 
    p_password text, 
    p_name text, 
    p_phone text, 
    p_governorate text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $function$
DECLARE
    v_caller_role TEXT;
    v_user_id UUID;
BEGIN
    -- 🔒 الصلاحيات: مسموح فقط للأدمن أو المشرف أو service_role
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RAISE EXCEPTION 'Unauthorized: Authentication required';
        END IF;
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
            RAISE EXCEPTION 'Unauthorized: Admin privileges required';
        END IF;
    END IF;

    -- 1. إنشاء الحساب في نظام المصادقة الداخلي لـ Supabase وتشفير كلمة المرور
    INSERT INTO auth.users (
        instance_id, 
        id, 
        email, 
        encrypted_password, 
        email_confirmed_at, 
        raw_app_meta_data, 
        raw_user_meta_data, 
        created_at, 
        updated_at, 
        role, 
        aud, 
        confirmation_token
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        p_email,
        crypt(p_password, gen_salt('bf')),
        timezone('utc'::text, now()),
        '{"provider": "email", "providers": ["email"]}'::jsonb,
        json_build_object('name', p_name, 'role', 'owner'),
        timezone('utc'::text, now()),
        timezone('utc'::text, now()),
        'authenticated',
        'authenticated',
        ''
    )
    RETURNING id INTO v_user_id;

    -- 2. إدراج أو تحديث الملف الشخصي للمالك (ON CONFLICT) لتفادي التعارض مع الـ Triggers الخلفية
    INSERT INTO public.users (
        id, 
        email, 
        role, 
        name, 
        phone, 
        governorate, 
        is_email_verified, 
        is_registration_complete, 
        created_at, 
        updated_at
    )
    VALUES (
        v_user_id,
        p_email,
        'owner',
        p_name,
        p_phone,
        p_governorate,
        true,
        true,
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    )
    ON CONFLICT (id) DO UPDATE
    SET 
        email = EXCLUDED.email,
        role = EXCLUDED.role,
        name = EXCLUDED.name,
        phone = EXCLUDED.phone,
        governorate = EXCLUDED.governorate,
        is_email_verified = true,
        is_registration_complete = true,
        updated_at = timezone('utc'::text, now());

    RETURN v_user_id;
END;
$function$;

-- 1.2 [GROUP B] close_owner_daily_shift
-- Ensures ONLY the actual pitch owner or admin can close a daily shift.
CREATE OR REPLACE FUNCTION public.close_owner_daily_shift(
    p_owner_id uuid, 
    p_stadium_id uuid, 
    p_operational_date date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_updated_count INT := 0;
    v_total_cash_collected NUMERIC := 0;
    v_caller_role TEXT;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً.');
        END IF;

        IF auth.uid() != p_owner_id THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin') THEN
                RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء تسوية هذا الملعب.');
            END IF;
        END IF;
    END IF;

    WITH updated_rows AS (
        UPDATE public.bookings
        SET 
            is_paid = TRUE,
            payment_status = 'paid',
            deposit_paid = total_price,
            updated_at = timezone('utc'::text, now())
        WHERE stadium_id = p_stadium_id
          AND owner_id = p_owner_id
          AND (operational_date = p_operational_date OR (operational_date IS NULL AND DATE(start_time AT TIME ZONE 'Africa/Cairo') = p_operational_date))
          AND status != 'cancelled'
          AND (is_paid = FALSE OR payment_status != 'paid')
        RETURNING total_price, deposit_paid
    )
    SELECT 
        COUNT(*),
        COALESCE(SUM(total_price), 0)
    INTO v_updated_count, v_total_cash_collected
    FROM updated_rows;

    RETURN jsonb_build_object(
        'success', true,
        'updated_bookings_count', v_updated_count,
        'total_cash_collected', v_total_cash_collected,
        'message', 'تم تقفيل الوردية بنجاح وتأكيد استلام كامل النقدية.'
    );
END;
$function$;

-- 1.3 [GROUP C] create_booking_atomic
-- Hardened with explicit unauthenticated check and SET search_path = public, pg_temp.
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
    
    -- Operating hours variables (Cairo local time)
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
BEGIN
    -- 1. Identity & Zero-Trust Caller check (Explicit unauthenticated guard)
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإجراء حجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
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

    -- 3. Concurrency Lock on Stadium (Advisory Lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Verify stadium existence and status
    SELECT * INTO v_stadium 
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
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
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.'
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
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. Cash Booking: Check Owner Debt Limit
    IF p_payment_method = 'cash' THEN
        SELECT accumulated_cash_debt, debt_limit, is_debt_blocked 
        INTO v_owner
        FROM public.users 
        WHERE id = v_final_owner_id;

        IF v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.0) THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'DEBT_LIMIT_EXCEEDED',
                'message', 'عذراً، تم إيقاف الحجز النقدي لهذا الملعب مؤقتاً لتجاوز حد المديونية المسموح. يرجى الدفع إلكترونياً.'
            );
        END IF;

        -- One active cash booking per user restriction
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Conflict detection against active bookings
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

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

    -- 12. Insert Booking Record
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
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
        p_start_time, p_end_time, p_booking_type, v_final_total_price,
        v_vsp_commission, v_gateway_fee, v_gateway_fee,
        COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
        COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
        p_is_private, p_rent_ball,
        v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
        p_payment_method, 'pending', v_final_status, v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id::uuid], v_locked_until, v_now, v_now
    )
    RETURNING id INTO v_new_booking_id;

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

-- 1.4 [GROUP C] cancel_booking_with_refund_atomic (3-arg Backward Compatibility Wrapper)
-- Forwards legacy 3-parameter client calls (p_booking_id, p_user_id, p_reason) to the 2-arg authoritative RPC.
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT 'إلغاء حجز من المستخدم'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.cancel_booking_with_refund_atomic(p_booking_id, p_reason);
END;
$$;

-- 1.5 [GROUP B] confirm_cash_booking_atomic (3-arg Backward Compatibility Wrapper)
-- Forwards legacy 3-parameter client calls (p_booking_id, p_owner_id, p_total_price) to the 4-arg authoritative RPC.
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_total_price numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN public.confirm_cash_booking_atomic(p_booking_id, p_owner_id, p_total_price, NULL::numeric);
END;
$$;


-- ------------------------------------------------------------------------------
-- PART 2: DYNAMIC SECURITY DEFINER HARDENING & PERMISSIONS BARRIER
-- Queries pg_proc to lock down EVERY overload of all sensitive functions in public.
-- ------------------------------------------------------------------------------

DO $$
DECLARE
    r RECORD;
    
    -- 🔒 Functions strictly reserved for background CRON / SYSTEM execution
    v_cron_system_funcs TEXT[] := ARRAY[
        'auto_approve_tournament_matches_24h',
        'auto_downgrade_expired_subscriptions',
        'auto_expire_matchups',
        'auto_expire_pending_locks',
        'auto_expire_stale_records',
        'auto_reconcile_all_past_bookings',
        'auto_reconcile_single_entry_results',
        'reset_fair_play_score_annually',
        'cleanup_stale_cron_logs'
    ];

    -- 🛡️ Functions reserved for authenticated mobile users, pitch owners, and admins
    v_authenticated_funcs TEXT[] := ARRAY[
        -- Group A: Admin & Financial
        'admin_settle_owner_cash_debt_atomic',
        'admin_approve_owner_atomic',
        'admin_record_payout_settlement_atomic',
        'admin_resolve_dispute_atomic',
        'admin_upgrade_owner_subscription_atomic',
        'approve_payout_settlement_atomic',
        'admin_register_owner_on_behalf',
        'get_admin_metrics',
        'get_admin_quick_metrics',

        -- Group B: Pitch Owner & Shift Operations
        'close_owner_daily_shift',
        'check_owner_stadium_limit',
        'confirm_cash_booking_atomic',
        'owner_create_manual_booking_atomic',
        'owner_lock_slot_atomic',
        'owner_extend_match_atomic',
        'owner_record_no_show_atomic',
        'request_owner_payout_settlement_atomic',
        'submit_owner_verification',
        'get_owner_financial_summary',
        'get_owner_revenue',
        'get_owner_booked_hours',

        -- Group C: Match, Booking, Tournaments & Players
        'create_booking_atomic',
        'cancel_booking_with_refund_atomic',
        'accept_join_request',
        'reject_join_request',
        'request_join_public_match',
        'leave_public_match_atomic',
        'update_host_spots_atomic',
        'add_team_to_matchup_by_code',
        'confirm_matchup_atomic',
        'close_matchup_atomic',
        'record_matchup_result_atomic',
        'create_tournament_order_atomic',
        'join_championship_atomic',
        'leave_championship_atomic',
        'prepare_tournament_bracket',
        'prepare_tournament_bracket_atomic',
        'record_match_result_and_advance_atomic',
        'crown_tournament_champion_atomic',
        'crown_individual_1v1_champion',
        'mark_championship_prize_delivered_atomic',
        'record_tournament_refund_status_atomic',
        'dispute_no_show_with_gps',
        'submit_stadium_review_atomic',
        'delete_chat_for_user_atomic',
        'delete_chat_for_user',
        'delete_user_permanently',
        'verify_booking_qr_atomic',
        'process_referral_reward_on_qr_verification',
        'complete_user_registration',
        'generate_team_invite_code',
        'auto_reconcile_past_bookings'
    ];
BEGIN
    -- 1. CRON / SYSTEM FUNCTIONS: Strip all PUBLIC and anon and authenticated access; permit ONLY service_role
    FOR r IN 
        SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = ANY(v_cron_system_funcs)
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon, authenticated', r.proname, r.args);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO service_role', r.proname, r.args);
    END LOOP;

    -- 2. AUTHENTICATED APP / OWNER / ADMIN FUNCTIONS: Strip PUBLIC and anon; permit authenticated and service_role
    FOR r IN 
        SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = ANY(v_authenticated_funcs)
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%I(%s) FROM PUBLIC, anon', r.proname, r.args);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%I(%s) TO authenticated, service_role', r.proname, r.args);
    END LOOP;
END;
$$;
