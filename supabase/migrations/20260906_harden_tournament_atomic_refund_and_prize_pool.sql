-- ==============================================================================
-- Migration: 20260906_harden_tournament_atomic_refund_and_prize_pool.sql
-- Description: 
--   1. Update confirm_tournament_order_atomic to:
--      - Return needs_refund / requires_refund and amount details upon over-capacity.
--      - Increment championships.prize_pool atomically on successful confirmation.
--      - Correctly append text representation of team_id to TEXT[] array.
--      - Insert pending refund audit transaction with order_reference in metadata.
--   2. Update and overload record_tournament_refund_status_atomic to:
--      - Accept boolean (p_refund_success) or text (p_refund_status).
--      - Mark transaction status (completed vs failed) and store paymob_refund_id in metadata.
--      - Alert admins upon refund_failed_manual_review.
-- ==============================================================================

-- 1. Main Function: confirm_tournament_order_atomic
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
    p_order_reference TEXT, 
    p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_order RECORD;
    v_champ RECORD;
    v_caller_role TEXT;
    v_joined_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- Authorization: service_role, postgres, admin, co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Unauthorized: Tournament orders can only be confirmed via server webhook or admin.'
            );
        END IF;
    END IF;

    -- Lock and retrieve tournament order
    SELECT * INTO v_order 
    FROM public.tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament order not found');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', true, 
            'message', 'Order already confirmed',
            'already_confirmed', true,
            'order_id', v_order.id,
            'team_id', v_order.team_id
        );
    END IF;

    -- Lock and retrieve championship row
    SELECT * INTO v_champ 
    FROM public.championships 
    WHERE id = v_order.championship_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Associated championship not found');
    END IF;

    v_joined_count := COALESCE(array_length(v_champ.joined_teams, 1), 0);

    -- RACE CONDITION OVER-CAPACITY CHECK:
    -- If championship closed or capacity reached, reject and trigger refund flow
    IF v_champ.status != 'open' OR v_joined_count >= v_champ.max_teams THEN
        UPDATE public.tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            updated_at = v_now
        WHERE id = v_order.id;

        -- Record initial audit transaction with pending status and order_reference in metadata
        INSERT INTO public.transactions (
            championship_id,
            user_id,
            amount,
            type,
            payment_method,
            status,
            description,
            metadata,
            created_at
        ) VALUES (
            v_order.championship_id,
            v_order.captain_user_id,
            v_order.amount,
            'refund',
            'paymob',
            'pending',
            'استرداد رسوم البطولة لاكتمال المقاعد',
            jsonb_build_object(
                'paymob_transaction_id', p_paymob_transaction_id,
                'order_reference', p_order_reference,
                'team_id', v_order.team_id,
                'reason', 'tournament_full'
            ),
            v_now
        );

        -- Send notification to captain
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'تعذر الانضمام للبطولة (اكتملت المقاعد)',
            'نعتذر، اكتملت مقاعد البطولة أثناء إتمام عملية الدفع. تم تسجيل حركة الاسترداد وجارٍ إرجاع المبلغ لحسابك البنكي.',
            'tournament_update',
            v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Championship is full or closed; payment logged for refund',
            'needs_refund', true,
            'requires_refund', true,
            'amount', v_order.amount,
            'amount_cents', ROUND(v_order.amount * 100),
            'paymob_transaction_id', p_paymob_transaction_id,
            'order_reference', p_order_reference,
            'team_id', v_order.team_id,
            'championship_id', v_order.championship_id
        );
    END IF;

    -- STANDARD SUCCESS CONFIRMATION
    UPDATE public.tournament_orders
    SET 
        payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = v_now
    WHERE id = v_order.id;

    -- Update championship: add team and accumulate prize_pool
    UPDATE public.championships
    SET 
        joined_teams = array_append(COALESCE(joined_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
        paid_teams = array_append(COALESCE(paid_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
        prize_pool = COALESCE(prize_pool, 0.00) + COALESCE(v_order.amount, 0.00),
        updated_at = v_now
    WHERE id = v_order.championship_id;

    -- Record completed payment transaction
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        v_order.championship_id,
        v_order.captain_user_id,
        v_order.amount,
        'digital',
        'paymob',
        'completed',
        'سداد رسوم اشتراك بطولة فرق',
        jsonb_build_object(
            'paymob_transaction_id', p_paymob_transaction_id,
            'order_reference', p_order_reference,
            'team_id', v_order.team_id
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true, 
        'order_id', v_order.id, 
        'team_id', v_order.team_id,
        'championship_id', v_order.championship_id,
        'amount', v_order.amount
    );
END;
$function$;

-- 2. Primary Function: record_tournament_refund_status_atomic (text status)
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(
    p_order_reference TEXT, 
    p_refund_status TEXT, 
    p_paymob_refund_id TEXT DEFAULT NULL::TEXT, 
    p_error_message TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_order RECORD;
    v_caller_role TEXT;
    v_admin_id UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- Authorization: service_role, postgres, admin, co_founder
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: تحديث حالة الاسترداد مقتصر على خادم الويب هوك أو الإدارة.');
        END IF;
    END IF;

    -- Validate refund status input
    IF p_refund_status NOT IN ('refunded', 'refund_failed_manual_review') THEN
        RETURN jsonb_build_object('success', false, 'error', 'حالة الاسترداد غير صالحة.');
    END IF;

    -- Lock and retrieve order
    SELECT * INTO v_order 
    FROM public.tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب اشتراك البطولة غير موجود.');
    END IF;

    -- Update order status
    UPDATE public.tournament_orders
    SET payment_status = p_refund_status,
        updated_at = v_now
    WHERE id = v_order.id;

    -- Update audit transaction matching order_reference in metadata
    UPDATE public.transactions
    SET status = CASE WHEN p_refund_status = 'refunded' THEN 'completed' ELSE 'failed' END,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'paymob_refund_id', p_paymob_refund_id,
            'refund_error', p_error_message,
            'refund_recorded_at', v_now
        )
    WHERE championship_id = v_order.championship_id
      AND type = 'refund'
      AND metadata->>'order_reference' = p_order_reference;

    -- Notifications
    IF p_refund_status = 'refunded' THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'تم استرداد رسوم اشتراك البطولة بنجاح',
            'تمت إعادة مبلغ رسوم الاشتراك (' || v_order.amount || ' ج.م) بنجاح إلى بطاقتك/محفظتك عبر Paymob (مرجع: ' || COALESCE(p_paymob_refund_id, '') || ').',
            'tournament_refund',
            v_now
        );
    ELSE
        -- Notify captain of manual review
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)',
            'تعذر الاسترداد التلقائي للرسوم (' || v_order.amount || ' ج.م). تم تحويل العملية لفريق الدعم المالي للمراجعة اليدوية ورد المبلغ لك.',
            'tournament_refund_manual',
            v_now
        );

        -- Notify all admins of financial security alert
        FOR v_admin_id IN (SELECT id FROM public.users WHERE role IN ('admin', 'co_founder')) LOOP
            INSERT INTO public.notifications (user_id, title, body, type, created_at)
            VALUES (
                v_admin_id,
                'تنبيه أمني مالي: فشل استرداد رسوم تلقائي لبطولة فرق',
                'فشل استرداد رسوم بطولة الفرق للطلب ' || p_order_reference || ' (المبلغ: ' || v_order.amount || ' ج.م). سبب الخطأ: ' || COALESCE(p_error_message, 'Paymob API error') || '. يرجى التدخل اليدوي الفوري.',
                'admin_alert',
                v_now
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_reference', p_order_reference,
        'status', p_refund_status,
        'paymob_refund_id', p_paymob_refund_id
    );
END;
$function$;

-- 3. Overloaded Function: record_tournament_refund_status_atomic (boolean p_refund_success)
CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(
    p_order_reference TEXT, 
    p_refund_success BOOLEAN, 
    p_paymob_refund_id TEXT DEFAULT NULL::TEXT, 
    p_error_message TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    RETURN public.record_tournament_refund_status_atomic(
        p_order_reference,
        CASE WHEN p_refund_success THEN 'refunded' ELSE 'refund_failed_manual_review' END,
        p_paymob_refund_id,
        p_error_message
    );
END;
$function$;
