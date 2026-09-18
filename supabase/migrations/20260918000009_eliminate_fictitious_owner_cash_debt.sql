-- ==============================================================================
-- Migration: 20260918000009_eliminate_fictitious_owner_cash_debt.sql
-- Description:
--   1. Zero out all fictitious cash debt on stadium owners (accumulated_cash_debt = 0, is_debt_blocked = false).
--   2. Remove debt calculation and blocking logic from confirm_cash_booking_atomic.
--   3. Remove debt calculation and blocking logic from owner_create_manual_booking_atomic.
--   4. Remove owner debt checking from create_booking_atomic.
--   5. Fix get_owner_financial_summary: Owner receives 100% of stadium price with ZERO deductions.
--   6. Fix request_payout_atomic: Owner can withdraw 100% of their net stadium online revenue.
-- ==============================================================================

BEGIN;

-- 1️⃣ تصفير كافة المديونيات وإلغاء أي حظر للملاك فوراً
UPDATE public.users 
SET accumulated_cash_debt = 0.00,
    is_debt_blocked = false
WHERE role = 'owner';


-- 2️⃣ تنقيح confirm_cash_booking_atomic (حذف أي مديونية أو مساس برصيد المالك)
CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(
    p_booking_id uuid,
    p_owner_id uuid,
    p_total_price numeric DEFAULT NULL::numeric,
    p_collected_amount numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_booking RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
    v_commission NUMERIC;
    v_actual_deposit NUMERIC;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. قفل صف الحجز لمنع التضارب
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. التحقق من الصلاحيات (المالك الحقيقي أو الأدمن أو service_role)
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role 
        FROM public.users 
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- 3. منع تحصيل الحجوزات الملغاة
    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    -- 4. Idempotency: إذا تم سداده مسبقاً لا نكرر العملية
    IF v_booking.is_paid IS TRUE AND v_booking.payment_status = 'paid' AND v_booking.payment_method = 'cash' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً ككاش.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'total_price', v_booking.total_price
        );
    END IF;

    -- 5. احتساب مبلغ الكاش الفعلي المستلم بالملعب
    IF p_collected_amount IS NOT NULL AND p_collected_amount > 0 THEN
        v_cash_amount := p_collected_amount;
    ELSE
        v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
        IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
            v_cash_amount := v_booking.total_price;
        END IF;
    END IF;

    v_actual_deposit := COALESCE(v_booking.deposit_paid, 0.0);
    v_commission := COALESCE(NULLIF(v_booking.vsp_commission, 0), round(v_cash_amount * 0.02, 2));

    -- 6. تحديث حالة الحجز إلى مؤكد ومسدد كاش (بدون أي دين على المالك نهائياً)
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        payment_method = 'cash',
        status = 'confirmed',
        vsp_commission = v_commission,
        deposit_paid = v_actual_deposit,
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 7. تسجيل قيد المعاملة النقدية في السجل
    INSERT INTO public.transactions (
        user_id,
        booking_id,
        amount,
        type,
        status,
        payment_method,
        description,
        created_at,
        updated_at
    ) VALUES (
        v_booking.owner_id,
        p_booking_id,
        v_cash_amount,
        'cash',
        'completed',
        'cash',
        'تحصيل نقدي بالملعب للحجز رقم ' || SUBSTRING(p_booking_id::text, 1, 8),
        v_now,
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تأكيد استلام الكاش بالملعب وتحديث حالة الحجز بنجاح.',
        'booking_id', p_booking_id,
        'cash_collected', v_cash_amount,
        'deposit_paid', v_actual_deposit,
        'total_price', v_booking.total_price
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) FROM anon, public;


-- 3️⃣ تنقيح owner_create_manual_booking_atomic (حذف أي فرض دين عند حجز المالك لملعبه يدوياً)
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(
    p_owner_id uuid,
    p_stadium_id uuid,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_customer_name text,
    p_customer_phone text,
    p_notes text,
    p_total_price numeric,
    p_collected_amount numeric DEFAULT 0,
    p_current_players integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_stadium RECORD;
    v_actual_owner_id UUID;
    v_caller_role TEXT;
    v_booking_id UUID;
    v_now TIMESTAMPTZ := now();
    v_is_paid BOOLEAN;
    v_payment_status TEXT;
    v_customer_clean TEXT;
BEGIN
    -- 1. التحقق من المدخلات الزمنية
    IF p_start_time >= p_end_time THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_time', 'message', 'وقت بداية الحجز يجب أن يكون قبل وقت النهاية.');
    END IF;

    IF p_total_price < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'invalid_price', 'message', 'سعر الحجز لا يمكن أن يكون سالباً.');
    END IF;

    -- 2. فحص الملعب وصلاحية المالك
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'stadium_not_found', 'message', 'الملعب غير موجود.');
    END IF;

    v_actual_owner_id := v_stadium.owner_id;

    IF auth.uid() IS NOT NULL AND auth.uid() != v_actual_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin') THEN
            RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message', 'غير مصرح لك بإنشاء حجز في هذا الملعب.');
        END IF;
    END IF;

    -- 3. قفل الملعب لمنع التضارب
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id::text));

    -- 4. فحص التضارب مع الحجوزات القائمة
    IF EXISTS (
        SELECT 1 FROM public.bookings
        WHERE stadium_id = p_stadium_id
          AND status IN ('confirmed', 'pending')
          AND NOT (end_time <= p_start_time OR start_time >= p_end_time)
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'conflict', 'message', 'عذراً، هذا الموعد يتعارض مع حجز قائم بالفعل.');
    END IF;

    v_customer_clean := COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي');
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'unpaid'
    END;

    -- 5. إنشاء سجل الحجز
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, stadium_name, owner_id, user_id, created_by_user_id,
            start_time, end_time, booking_type, player_team_name, host_name,
            player_phone, notes, total_price, vsp_commission, gateway_fee,
            deposit_paid, is_deposit_paid, is_paid, payment_status, payment_method,
            payment_transaction_id, status, current_players, is_private, rent_ball,
            created_at, updated_at
        ) VALUES (
            p_stadium_id, v_stadium.name, v_actual_owner_id, v_actual_owner_id,
            COALESCE(auth.uid(), v_actual_owner_id),
            p_start_time, p_end_time, 'personal', v_customer_clean, v_customer_clean,
            NULLIF(TRIM(p_customer_phone), ''), NULLIF(TRIM(p_notes), ''),
            p_total_price, 0.00, 0.00,
            p_collected_amount, (p_collected_amount > 0), v_is_paid, v_payment_status,
            'cash', 'MANUAL_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
            'confirmed', p_current_players, true, false, v_now, v_now
        )
        RETURNING id INTO v_booking_id;
    EXCEPTION
        WHEN unique_violation OR exclusion_violation THEN
            RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN', 'error', 'conflict', 'message', 'عذراً، تم حجز هذا الموعد للتو من قبل مستخدم آخر.');
    END;

    -- 6. تسجيل معاملة الكاش في السجل إن وجد تحصيل
    IF p_collected_amount > 0 THEN
        INSERT INTO public.transactions (user_id, booking_id, amount, type, status, payment_method, description, created_at, updated_at)
        VALUES (v_actual_owner_id, v_booking_id, p_collected_amount, 'cash', 'completed', 'cash',
            'تحصيل حجز يدوي: ' || COALESCE(v_stadium.name, 'الملعب'),
            v_now, v_now);
    END IF;

    RETURN jsonb_build_object('success', true, 'booking_id', v_booking_id, 'message', 'تم إنشاء الحجز اليدوي بنجاح وبدون أي مديونية.');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid, uuid, timestamptz, timestamptz, text, text, text, numeric, numeric, integer) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid, uuid, timestamptz, timestamptz, text, text, text, numeric, numeric, integer) FROM PUBLIC, anon;


-- 4️⃣ تنقيح create_booking_atomic (حذف فحص حظر الكاش بسبب المديونية نهائياً)
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id text,
    p_user_id text,
    p_start_time timestamptz,
    p_end_time timestamptz,
    p_payment_method text,
    p_client_price numeric DEFAULT NULL::numeric,
    p_player_phone text DEFAULT NULL::text,
    p_player_team_name text DEFAULT NULL::text,
    p_rent_ball boolean DEFAULT false,
    p_match_type text DEFAULT 'friendly'::text,
    p_player_team_id uuid DEFAULT NULL::uuid,
    p_opponent_team_id uuid DEFAULT NULL::uuid,
    p_is_private boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_stadium_uuid UUID;
    v_user_uuid UUID;
    v_stadium RECORD;
    v_duration_hours NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0.0;
    v_vsp_commission NUMERIC;
    v_gateway_fee NUMERIC;
    v_final_total_price NUMERIC;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_deposit_paid NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_locked_until TIMESTAMPTZ;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_final_owner_id UUID;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := now();
    
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
    v_booking_id UUID;
BEGIN
    -- 1. Identity & Zero-Trust Caller check
    IF (COALESCE(auth.role(), '') != 'service_role') AND current_user NOT IN ('postgres', 'service_role') THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإجراء حجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder', 'super_admin')) THEN
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

    -- 2. Duration validity
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours < 0.5 OR v_duration_hours > 8.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز يجب أن تكون بين 30 دقيقة و 8 ساعات.');
    END IF;

    -- 3. Concurrency Lock on Stadium
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

    -- Deposit Enforcement
    IF COALESCE(v_stadium.needs_deposit, false) IS TRUE AND p_payment_method = 'cash' THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'DEPOSIT_REQUIRED',
            'message', 'عذراً، هذا الملعب يشترط دفع عربون إلكتروني أونلاين لتأكيد الحجز ولا يقبل الحجز النقدي الكامل.'
        );
    END IF;

    -- 5. Operating Hours Validation
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;

    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
            IF v_start_cairo < v_open_ts OR v_end_cairo > v_close_ts THEN
                RETURN jsonb_build_object('success', false, 'message', 'الموعد المختار يقع خارج ساعات عمل الملعب الرسمية.');
            END IF;
        END IF;
    END IF;

    -- 6. Server-side Canonical Price Calculation
    v_calculated_price := ROUND(v_stadium.price_per_hour * v_duration_hours, 2);

    IF p_rent_ball IS TRUE AND v_stadium.has_ball IS TRUE THEN
        BEGIN
            v_ball_price := COALESCE((v_stadium.features->>'ball_price')::numeric, 0.0);
        EXCEPTION WHEN OTHERS THEN
            v_ball_price := 0.0;
        END;
        v_calculated_price := v_calculated_price + v_ball_price;
    END IF;

    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'تسعيرة هذا الملعب غير محددة بشكل صحيح.');
    END IF;

    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. Platform Commission
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

    -- 9. Cash booking limitation (1 active cash booking per user)
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id = v_user_uuid OR created_by_user_id = v_user_uuid)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. لا يمكن إنشاء أكثر من حجز نقدي واحد في نفس الوقت.');
        END IF;
    END IF;

    -- 10. Conflict check
    IF EXISTS (
        SELECT 1 FROM public.bookings
        WHERE stadium_id = v_stadium_uuid
          AND status IN ('confirmed', 'pending')
          AND (
            (status = 'confirmed') OR
            (status = 'pending' AND (locked_until IS NULL OR locked_until > v_now))
          )
          AND NOT (end_time <= p_start_time OR start_time >= p_end_time)
    ) THEN
        RETURN jsonb_build_object('success', false, 'message', 'هذا الموعد محجوز بالفعل أو قيد الدفع من لاعب آخر.');
    END IF;

    -- 11. Final Status assignment
    IF p_payment_method = 'cash' THEN
        v_final_status := 'confirmed';
        v_final_is_paid := false;
        v_final_deposit_paid := 0.00;
        v_locked_until := NULL;
    ELSE
        v_final_status := 'pending';
        v_final_is_paid := false;
        v_final_deposit_paid := 0.00;
        v_locked_until := v_now + INTERVAL '5 minutes';
    END IF;

    -- 12. Create Booking
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, user_id, created_by_user_id, owner_id,
            start_time, end_time, total_price, deposit_paid,
            payment_method, payment_status, status, is_paid,
            vsp_commission, gateway_fee, locked_until,
            player_phone, player_team_name, rent_ball,
            match_type, player_team_id, opponent_team_id, is_private,
            created_at, updated_at
        ) VALUES (
            v_stadium_uuid, v_user_uuid, v_caller_id, v_final_owner_id,
            p_start_time, p_end_time, v_final_total_price, v_final_deposit_paid,
            p_payment_method, 'pending', v_final_status, v_final_is_paid,
            v_vsp_commission, v_gateway_fee, v_locked_until,
            p_player_phone, p_player_team_name, p_rent_ball,
            p_match_type, p_player_team_id, p_opponent_team_id, p_is_private,
            v_now, v_now
        )
        RETURNING id INTO v_booking_id;
    EXCEPTION
        WHEN unique_violation OR exclusion_violation THEN
            RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN', 'message', 'عذراً، تم حجز هذا الموعد للتو.');
    END;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'needs_deposit', v_final_needs_deposit,
        'deposit_amount', v_final_deposit_amount,
        'locked_until', v_locked_until,
        'message', 'تم إنشاء الحجز بنجاح.'
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_booking_atomic(text, text, timestamptz, timestamptz, text, numeric, text, text, boolean, text, uuid, uuid, boolean) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.create_booking_atomic(text, text, timestamptz, timestamptz, text, numeric, text, text, boolean, text, uuid, uuid, boolean) FROM anon, public;


-- 5️⃣ تنقيح get_owner_financial_summary (المالك يحصل على 100% من سعر ملعبه بدون أي خصم لرسوم المنصة أو ديون وهمية)
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_completed_online_rev NUMERIC := 0.0;
    v_escrow_online_rev NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_completed_cash_rev NUMERIC := 0.0;
    v_completed_bookings_count INT := 0;
BEGIN
    -- التحقق من الصلاحيات
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    -- 1. إيرادات الأونلاين للمباريات المكتملة (سعر الملعب / العربون يعود للمالك كاملاً 100%)
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
                ELSE total_price
            END
        ), 0.0),
        COUNT(*)
    INTO
        v_completed_online_rev,
        v_completed_bookings_count
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    -- 2. أموال الضمان للمباريات المؤكدة القادمة (Escrow)
    SELECT COALESCE(SUM(
        CASE 
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
            ELSE total_price
        END
    ), 0.0)
    INTO v_escrow_online_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'confirmed';

    -- 3. المسحوبات السابقة والمعلقة
    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- 4. الرصيد الصافي المتاح للسحب (كامل إيراد المالك الأونلاين - مسحوباته فقط، بدون أي مديونية أو خصم رسوم)
    v_available_balance := GREATEST(0.0,
        v_completed_online_rev - v_total_withdrawn - v_pending_payouts
    );

    -- 5. إيرادات الكاش المستلمة بالملعب
    SELECT COALESCE(SUM(
        CASE 
            WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN (total_price - deposit_paid)
            ELSE total_price
        END
    ), 0.0)
    INTO v_completed_cash_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND (LOWER(COALESCE(payment_method, '')) = 'cash' OR status = 'completed')
      AND is_paid = true;

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'completed_online_revenue', ROUND(v_completed_online_rev, 2),
        'escrow_online_revenue', ROUND(v_escrow_online_rev, 2),
        'net_completed_earnings', ROUND(v_completed_online_rev, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'cash_revenue', ROUND(v_completed_cash_rev, 2),
        'accumulated_cash_debt', 0.00,
        'debt_limit', 500.00,
        'is_debt_blocked', false,
        'completed_bookings_count', v_completed_bookings_count
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) FROM PUBLIC, anon;


-- 6️⃣ تنقيح request_payout_atomic (المالك يسحب 100% من أرباح ملعبه بدون خصم رسوم أو ديون)
CREATE OR REPLACE FUNCTION public.request_payout_atomic(
    p_owner_id uuid,
    p_amount numeric,
    p_destination text,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_caller_role TEXT;
    v_owner RECORD;
    v_pending_count INT;
    v_completed_online_revenue NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_new_settlement_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. التحقق من التوثيق
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة.');
    END IF;

    -- 2. قفل سجل المالك
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    -- 3. فحص الطلبات المعلقة
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل.');
    END IF;

    -- 4. احتساب أرباح المالك الأونلاين كاملة 100%
    SELECT
        COALESCE(SUM(
            CASE 
                WHEN COALESCE(deposit_paid, 0.0) > 0.0 AND COALESCE(deposit_paid, 0.0) < total_price THEN deposit_paid
                ELSE total_price
            END
        ), 0.0)
    INTO
        v_completed_online_revenue
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    -- 5. خصم المسحوبات فقط
    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_completed_online_revenue - v_total_withdrawn - v_pending_payouts);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م).'
        );
    END IF;

    -- 6. إنشاء طلب التسوية
    INSERT INTO public.payout_settlements (
        owner_id, amount, status, notes, payout_details,
        requested_at, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, 'pending', p_notes,
        jsonb_build_object('destination', p_destination, 'requested_by', auth.uid()),
        v_now, v_now, v_now
    )
    RETURNING id INTO v_new_settlement_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تقديم طلب السحب بنجاح وهو قيد التحويل.',
        'settlement_id', v_new_settlement_id,
        'requested_amount', p_amount,
        'remaining_balance', ROUND(v_available_balance - p_amount, 2)
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.request_payout_atomic(uuid, numeric, text, text) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.request_payout_atomic(uuid, numeric, text, text) FROM PUBLIC, anon;

COMMIT;
