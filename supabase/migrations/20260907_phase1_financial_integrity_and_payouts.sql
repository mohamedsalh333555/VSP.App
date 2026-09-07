-- ==============================================================================
-- 🚀 VSP MIGRATION: PHASE 1 FINANCIAL INTEGRITY & PAYOUTS HARDENING
-- Date: 2026-09-07
-- Description:
-- 1. Adds public.get_owner_financial_summary RPC (Accurate net accounting)
-- 2. Hardens public.request_owner_payout_settlement_atomic (Zero-Trust Balance Validation)
-- 3. Hardens public.create_booking_atomic (Duration sanity constraints)
-- ==============================================================================

-- 1️⃣ دالة الحساب المالي الشامل للمالك (Zero-Trust Financial Summary)
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_total_online_revenue NUMERIC := 0.0;
    v_total_platform_fees NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_cash_revenue NUMERIC := 0.0;
    v_total_completed_bookings INT := 0;
BEGIN
    -- التحقق من الهوية والصلاحية
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

        IF v_caller_id != p_owner_id AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    -- 1. حساب الدخل الإلكتروني ورسوم المنصة للحجوزات المؤكدة غير الملغاة
    SELECT 
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(platform_fee, 0.0)), 0.0),
        COUNT(*)
    INTO 
        v_total_online_revenue,
        v_total_platform_fees,
        v_total_completed_bookings
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    v_net_online_earnings := v_total_online_revenue - v_total_platform_fees;

    -- 2. حساب المبالغ المسحوبة والمكتملة بالفعل
    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id
      AND status = 'completed';

    -- 3. حساب المبالغ المعلقة قيد المراجعة أو المعتمدة للصرف
    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id
      AND status IN ('pending', 'approved');

    -- 4. الرصيد المتاح للسحب الفعلي
    v_available_balance := GREATEST(0.0, v_net_online_earnings - v_total_withdrawn - v_pending_payouts);

    -- 5. حساب الدخل النقدي المستلم باليد في الملعب (لأغراض الإحصاءات فقط، لا يدخل في السحب)
    SELECT COALESCE(SUM(total_price), 0.0)
    INTO v_cash_revenue
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method = 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_total_online_revenue, 2),
        'total_platform_fees', ROUND(v_total_platform_fees, 2),
        'net_online_earnings', ROUND(v_net_online_earnings, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'cash_revenue', ROUND(v_cash_revenue, 2),
        'completed_bookings_count', v_total_completed_bookings
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_owner_financial_summary(uuid) TO authenticated, service_role;


-- 2️⃣ تحصين دالة طلب تسوية وسحب مستحقات المالك ضد الرصيد الوهمي
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
    p_owner_id uuid,
    p_amount numeric,
    p_method text,
    p_destination text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_total_online_revenue NUMERIC := 0.0;
    v_total_platform_fees NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
BEGIN
    -- التحقق من صلاحيات وهوية المالك
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) OR 
       (auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة (رقم انستاباي أو المحفظة).');
    END IF;

    -- جلب بيانات المالك
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    -- التحقق من عدم وجود طلب تسوية معلق بالفعل
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل من قبل الإدارة. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- 🔒 التحقق الصارم من الرصيد المتاح للسحب من الحجوزات الإلكترونية
    SELECT 
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(platform_fee, 0.0)), 0.0)
    INTO 
        v_total_online_revenue,
        v_total_platform_fees
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    v_net_online_earnings := v_total_online_revenue - v_total_platform_fees;

    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_net_online_earnings - v_total_withdrawn - v_pending_payouts);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م).'
        );
    END IF;

    -- إدراج طلب التسوية في جدول payout_settlements
    INSERT INTO public.payout_settlements (
        owner_id,
        amount,
        method,
        destination,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_owner_id,
        p_amount,
        COALESCE(p_method, 'instapay'),
        p_destination,
        'pending',
        v_now,
        v_now
    ) RETURNING id INTO v_settlement_id;

    -- إدراج حركة قيد معلقة في جدول المعاملات transactions
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout_pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, ''),
            'remaining_balance_after', ROUND(v_available_balance - p_amount, 2)
        ),
        v_now
    );

    -- إرسال إشعار فوري للأدمن
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        is_read,
        created_at
    )
    SELECT 
        id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout',
        false,
        v_now
    FROM public.users
    WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'available_balance', ROUND(v_available_balance - p_amount, 2),
        'message', 'تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid, numeric, text, text) TO authenticated, service_role;


-- 3️⃣ تحصين دالة إنشاء الحجز create_booking_atomic ضد المدد غير المنطقية
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
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_conflict_count INT;
    v_new_booking_id UUID;
    v_stadium RECORD;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_duration_hours NUMERIC;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0.0;
    v_final_total_price NUMERIC;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_owner_id UUID;
    v_calculated_fee NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_final_deposit_paid NUMERIC;
    v_locked_until TIMESTAMPTZ := NULL;
BEGIN
    -- 1. التحقق من هوية المستدعي (Authentication & Authorization)
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإتمام الحجز.');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;

        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. التحقق من صحة التوقيت وفرض مدة حجز منطقية (من 30 دقيقة إلى 8 ساعات)
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

    -- 3. قفل الملعب استشارياً لمنع الحجز المزدوج في نفس اللحظة (Advisory Lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. التحقق من وجود وحالة الملعب وجلب البيانات الرسمية من قاعدة البيانات
    SELECT * INTO v_stadium
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. حساب السعر الحقيقي وحصانة المالك من السيرفر (Strict Fail-Closed Price & Deposit Calculation)
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

    -- رفض صريح لأي تسعيرة غير صالحة
    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.'
        );
    END IF;

    v_final_total_price := v_calculated_price;

    -- قراءة قواعد العربون والمالك الرسمي من سجل الملعب بالداتابيز
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 6. التحقق من حالة المستخدم وقيود عدم الحضور
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- قيد الحجز النقدي الواحد النشط
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > NOW();

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 7. فحص تضارب المواعيد بدقة
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < NOW())
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

    -- 8. ضبط الحالة وقفل الـ 5 دقائق للدفع الإلكتروني
    IF p_payment_method IN ('paymob', 'card', 'wallet') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NOW() + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 9. حساب رسوم المنصة بدقة في الخادم
    v_calculated_fee := round((v_final_total_price * 0.0475) + 3.0, 2);

    -- 10. إدراج الحجز بالسعر والمالك المحسوبين من السيرفر
    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price, platform_fee,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, locked_until, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
        p_start_time, p_end_time, p_booking_type, v_final_total_price, v_calculated_fee,
        COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
        COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
        p_is_private, p_rent_ball,
        v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
        p_payment_method, 'pending', v_final_status, v_final_is_paid,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id::uuid], v_locked_until, NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_booking_atomic TO authenticated, service_role;
