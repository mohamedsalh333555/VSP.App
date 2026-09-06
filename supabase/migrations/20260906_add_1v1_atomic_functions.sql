-- ==============================================================================
-- Migration: 20260906_add_1v1_atomic_functions.sql
-- Section 2: 1v1 Paid Tournament Atomic RPCs (Order Creation, Confirmation, Real Refund Recording, Prize Delivery)
-- ==============================================================================

-- 1️⃣ CREATE PAYMENT ORDER ATOMIC
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_1v1_payment_order_atomic(p_tournament_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
    v_current_count INT;
    v_order_id UUID := gen_random_uuid();
    v_order_ref TEXT;
    v_user RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً للمشاركة.');
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    -- Check if player is already registered & paid
    IF EXISTS (
        SELECT 1 FROM public.vsp_1v1_tournament_players 
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id AND payment_status = 'paid'
    ) THEN
        RETURN jsonb_build_object('success', false, 'already_registered', true, 'error', 'أنت مسجل ودافع بالفعل في هذه البطولة.');
    END IF;

    -- Check capacity
    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Generate clean unique order reference: TOURN_1V1_<short_id>_<timestamp>
    v_order_ref := 'TOURN_1V1_' || SUBSTRING(v_order_id::text, 1, 8) || '_' || FLOOR(EXTRACT(EPOCH FROM now()))::bigint;

    -- Insert pending order record
    INSERT INTO public.vsp_1v1_tournament_orders (
        id,
        tournament_id,
        user_id,
        amount,
        order_reference,
        payment_status,
        created_at,
        updated_at
    ) VALUES (
        v_order_id,
        p_tournament_id,
        v_caller_id,
        COALESCE(v_champ.entry_fee, 0),
        v_order_ref,
        'pending',
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'order_id', v_order_id,
        'order_reference', v_order_ref,
        'amount', COALESCE(v_champ.entry_fee, 0),
        'tournament_id', p_tournament_id,
        'tournament_name', v_champ.name
    );
END;
$$;

-- 2️⃣ CONFIRM 1v1 PAYMENT ATOMIC (Called by Webhook on Paymob Success)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirm_1v1_payment_atomic(
    p_order_reference TEXT,
    p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_order RECORD;
    v_champ RECORD;
    v_current_count INT;
    v_user RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 Authorization: Only service_role or admin/co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: يتم تأكيد الطلبات عبر الـ Webhook فقط.');
        END IF;
    END IF;

    -- 🔒 Lock order row
    SELECT * INTO v_order 
    FROM public.vsp_1v1_tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب الدفع غير موجود.');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'message', 'تم تأكيد الطلب مسبقاً.');
    END IF;

    -- 🔒 Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = v_order.tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة المرتبطة بالطلب غير موجودة.');
    END IF;

    -- Count active paid players
    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = v_order.tournament_id AND payment_status = 'paid';

    -- 🛡️ RACE CONDITION CHECK: Capacity exceeded while player was on payment screen
    IF v_champ.status != 'registration_open' OR v_current_count >= v_champ.target_player_count THEN
        -- Mark as failed_over_capacity
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            updated_at = v_now
        WHERE id = v_order.id;

        -- Return exact payload signaling the Edge Function to trigger real Paymob Refund API
        RETURN jsonb_build_object(
            'success', false,
            'capacity_exceeded', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'tournament_id', v_order.tournament_id,
            'amount', v_order.amount,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'اكتملت مقاعد البطولة أثناء إتمام الدفع. تم إرسال أمر استرداد فوري لبوابة Paymob.'
        );
    END IF;

    -- 🟢 CAPACITY AVAILABLE: Confirm payment & register player
    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = v_now
    WHERE id = v_order.id;

    -- Fetch player profile
    SELECT name, profile_image_url INTO v_user 
    FROM public.users 
    WHERE id = v_order.user_id;

    -- Upsert player into tournament roster
    INSERT INTO public.vsp_1v1_tournament_players (
        tournament_id,
        user_id,
        player_name,
        avatar_url,
        tackles,
        goals,
        skills,
        payment_status,
        payment_order_id,
        paid_amount,
        registered_at
    ) VALUES (
        v_order.tournament_id,
        v_order.user_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0,
        0,
        0,
        'paid',
        v_order.id,
        v_order.amount,
        v_now
    )
    ON CONFLICT (tournament_id, user_id) 
    DO UPDATE SET 
        payment_status = 'paid',
        payment_order_id = EXCLUDED.payment_order_id,
        paid_amount = EXCLUDED.paid_amount,
        registered_at = v_now;

    -- 💰 ACCUMULATE PRIZE POOL AUTOMATICALLY
    UPDATE public.vsp_1v1_tournaments
    SET prize_pool = COALESCE(prize_pool, 0) + v_order.amount,
        updated_at = v_now
    WHERE id = v_order.tournament_id;

    -- 📝 Financial ledger log
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        v_order.user_id,
        v_order.amount,
        'payment',
        'paymob',
        'completed',
        'رسوم اشتراك بطولة 1v1 - ' || COALESCE(v_champ.name, ''),
        jsonb_build_object(
            'tournament_id', v_order.tournament_id,
            'order_reference', p_order_reference,
            'paymob_transaction_id', p_paymob_transaction_id
        ),
        v_now
    );

    -- 🔔 In-app confirmation notification to player
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
        v_order.user_id,
        'تأكيد التسجيل في بطولة 1v1 🎉',
        'تم تأكيد دفع رسوم الاشتراك (' || v_order.amount || ' ج.م) وتسجيلك رسمياً في ' || COALESCE(v_champ.name, 'البطولة') || '. حظاً موفقاً!',
        'tournament_update',
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'paid',
        'order_id', v_order.id,
        'tournament_id', v_order.tournament_id,
        'player_user_id', v_order.user_id,
        'amount', v_order.amount,
        'new_prize_pool', COALESCE(v_champ.prize_pool, 0) + v_order.amount
    );
END;
$$;

-- 3️⃣ RECORD REFUND STATUS ATOMIC (Called after Paymob Refund API responds)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.record_1v1_refund_status_atomic(
    p_order_reference TEXT,
    p_refund_success BOOLEAN,
    p_paymob_refund_id TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_order RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_admin_id UUID;
BEGIN
    -- 🔒 Authorization
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح.');
        END IF;
    END IF;

    SELECT * INTO v_order 
    FROM public.vsp_1v1_tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'الطلب غير موجود.');
    END IF;

    IF p_refund_success = true THEN
        -- ✅ Real Paymob refund succeeded
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'refunded',
            updated_at = v_now
        WHERE id = v_order.id;

        -- Record completed refund transaction
        INSERT INTO public.transactions (
            user_id,
            amount,
            type,
            payment_method,
            status,
            description,
            metadata,
            created_at
        ) VALUES (
            v_order.user_id,
            v_order.amount,
            'refund',
            'paymob',
            'completed',
            'استرداد رسوم بطولة 1v1 لاكتمال المقاعد',
            jsonb_build_object(
                'order_reference', p_order_reference,
                'paymob_transaction_id', v_order.paymob_transaction_id,
                'paymob_refund_id', p_paymob_refund_id,
                'reason', 'capacity_exceeded'
            ),
            v_now
        );

        -- Send user notification confirming money returned
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.user_id,
            'استرداد رسوم البطولة بنجاح 💳',
            'نعتذر، اكتملت مقاعد البطولة أثناء إتمام عملية الدفع. تم إرجاع مبلغ ' || v_order.amount || ' ج.م بالكامل إلى بطاقتك البنكية بنجاح (مرجع: ' || COALESCE(p_paymob_refund_id, '') || ').',
            'tournament_update',
            v_now
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'refunded',
            'paymob_refund_id', p_paymob_refund_id
        );
    ELSE
        -- ❌ Real Paymob refund call failed -> Flag for immediate manual review!
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'refund_failed_manual_review',
            updated_at = v_now
        WHERE id = v_order.id;

        -- Notify all admins with high-priority alert
        FOR v_admin_id IN (SELECT id FROM public.users WHERE role IN ('admin', 'co_founder')) LOOP
            INSERT INTO public.notifications (user_id, title, body, type, created_at)
            VALUES (
                v_admin_id,
                '🚨 تنبيه أمني مالي: فشل استرداد رسوم تلقائي',
                'فشل استرداد رسوم بطولة 1v1 للطلب ' || p_order_reference || ' (المبلغ: ' || v_order.amount || ' ج.م). سبب الخطأ: ' || COALESCE(p_error_message, 'Paymob API error') || '. يرجى التدخل اليدوي الفوري.',
                'admin_alert',
                v_now
            );
        END LOOP;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'refund_failed_manual_review',
            'alert_sent', true,
            'error_logged', p_error_message
        );
    END IF;
END;
$$;

-- 4️⃣ MARK 1v1 PRIZE DELIVERED ATOMIC (Manual Handover Logging)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.mark_1v1_prize_delivered_atomic(
    p_tournament_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_champ RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 🔒 Authorization: Only admin or co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: فقط الأدمن يمكنه توثيق تسليم الجوائز.');
        END IF;
    END IF;

    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = p_tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة قبل انتهاء البطولة وتتويج البطل رسمياً.');
    END IF;

    IF v_champ.prize_delivered = true THEN
        RETURN jsonb_build_object(
            'success', false, 
            'already_delivered', true, 
            'error', 'تم توثيق تسليم الجائزة بالفعل مسبقاً في: ' || v_champ.prize_delivered_at::text
        );
    END IF;

    -- Update tournament with delivery metadata (Pure audit log, no wallet movements)
    UPDATE public.vsp_1v1_tournaments
    SET 
        prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = p_notes,
        updated_at = v_now
    WHERE id = p_tournament_id;

    -- Notify champion
    IF v_champ.champion_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_champ.champion_user_id,
            'توثيق استلام الجائزة المالية 🏆',
            'تهانينا! تم توثيق استلامك لجائزة بطولة ' || COALESCE(v_champ.name, '1v1') || ' وقدرها ' || COALESCE(v_champ.prize_pool, 0) || ' ج.م بنجاح.',
            'tournament_update',
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'tournament_id', p_tournament_id,
        'prize_delivered', true,
        'prize_pool', v_champ.prize_pool,
        'champion_user_id', v_champ.champion_user_id,
        'delivered_at', v_now
    );
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.create_1v1_payment_order_atomic(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_1v1_payment_atomic(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_1v1_refund_status_atomic(TEXT, BOOLEAN, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(UUID, TEXT) TO authenticated, service_role;
