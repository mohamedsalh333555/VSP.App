-- ============================================================================
-- VSP STAGE 9: FINANCIAL INTEGRITY & RECONCILIATION HARDENING
-- File: 20260916000002_stage9_financial_reconciliation.sql
-- ============================================================================

DROP FUNCTION IF EXISTS public.request_owner_payout_settlement_atomic(uuid, numeric, text, text);

-- 1. HARDEN request_owner_payout_settlement_atomic
-- Enforce authoritative zero-trust balance calculation:
-- Deducts gateway fees, 2% VSP commission, pending/completed payouts, AND cash debt liabilities.
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
    p_owner_id UUID,
    p_amount NUMERIC,
    p_method TEXT DEFAULT 'instapay',
    p_destination TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_total_online_revenue NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
BEGIN
    -- 1. Authentication & Authorization Check
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
        END IF;
    END IF;

    -- 2. Input Validation
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة (رقم انستاباي أو المحفظة).');
    END IF;

    -- 3. Lock and fetch owner record
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    v_accumulated_debt := COALESCE(v_owner.accumulated_cash_debt, 0.0);

    -- 4. Check for active pending settlement requests
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل من قبل الإدارة. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- 5. Calculate Net Online Earnings with strict deductions
    SELECT 
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0)
    INTO 
        v_total_online_revenue,
        v_total_gateway_fees,
        v_total_vsp_commission
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status != 'cancelled';

    v_net_online_earnings := v_total_online_revenue - v_total_gateway_fees - v_total_vsp_commission;

    -- 6. Payout deductions (completed & pending)
    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0)
    INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    -- 7. Available Balance strictly incorporates cash debt offset
    v_available_balance := GREATEST(0.0, v_net_online_earnings - v_total_withdrawn - v_pending_payouts - v_accumulated_debt);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م).'
        );
    END IF;

    -- 8. Insert settlement record
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

    -- 9. Insert pending ledger record in transactions
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        status,
        payment_method,
        metadata,
        created_at,
        updated_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout_pending',
        'pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, ''),
            'remaining_balance_after', ROUND(v_available_balance - p_amount, 2)
        ),
        v_now,
        v_now
    );

    -- 10. Admin notification
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


-- 2. HARDEN cancel_booking_with_refund_atomic
-- Guards against cancelling completed matches, restricts player cutoffs properly,
-- and reverses 2% cash debt on cancelled cash bookings.
CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id UUID,
    p_reason TEXT DEFAULT 'إلغاء حجز من العميل'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_owner_rec RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID := NULL;
    v_caller_role TEXT;
    v_minutes_since_created NUMERIC;
    v_commission_to_reverse NUMERIC(10, 2) := 0.00;
    v_new_owner_debt NUMERIC(10, 2);
    v_is_owner_blocked BOOLEAN;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Row lock: Lock target booking row to prevent concurrent race conditions
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. Guard against cancelling already COMPLETED bookings
    IF v_booking.status = 'completed' OR v_booking.is_verified_by_owner IS TRUE THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'CANNOT_CANCEL_COMPLETED_BOOKING',
            'message', 'عذراً، لا يمكن إلغاء أو استرداد حجز لمباراة مكتملة تم حضورها بالفعل.'
        );
    END IF;

    -- 3. Idempotency & State Guard: If booking is ALREADY cancelled, return safely without duplicating refund
    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'code', 'already_cancelled',
            'already_cancelled', true,
            'message', 'الحجز ملغي بالفعل مسبقاً.',
            'booking_id', p_booking_id,
            'refund_amount', COALESCE(v_booking.refund_amount, 0.00)
        );
    END IF;

    -- 4. Authorization Check
    IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'code', 'unauthorized', 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (auth.uid() != v_booking.created_by_user_id)
           AND (auth.uid() != v_booking.user_id)
           AND (auth.uid() != v_booking.owner_id)
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) THEN
            RETURN jsonb_build_object('success', false, 'code', 'forbidden', 'message', 'غير مصرح: يمكنك فقط إلغاء الحجوزات الخاصة بك أو بملاعبك.');
        END IF;
    END IF;

    -- 5. Check 6-hour cutoff rule strictly for PLAYERS (exempting owners, admins, and service_role)
    IF (auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id)
       AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder'))
       AND (COALESCE(auth.role(), '') != 'service_role')
       AND (auth.uid() != v_booking.owner_id) THEN
        v_minutes_since_created := EXTRACT(EPOCH FROM (v_now - COALESCE(v_booking.created_at, v_now))) / 60.0;
        
        IF v_minutes_since_created > 20.0 AND v_booking.start_time <= (v_now + INTERVAL '6 hours') THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'cannot_cancel_within_6_hours',
                'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من إتمام الحجز وفقاً للائحة).'
            );
        END IF;
    END IF;

    -- 6. Calculate refund amount if payment was confirmed
    IF (v_booking.payment_status IN ('paid', 'confirmed') OR v_booking.is_paid IS TRUE OR v_booking.is_deposit_paid IS TRUE) THEN
        v_refund_amount := COALESCE(v_booking.deposit_paid, v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- 7. Reverse Cash Debt if this was a confirmed cash booking with accrued commission
    IF LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' 
       AND (v_booking.is_paid IS TRUE OR v_booking.payment_status = 'paid')
       AND v_booking.owner_id IS NOT NULL THEN
        v_commission_to_reverse := COALESCE(v_booking.vsp_commission, round(COALESCE(v_booking.total_price, 0) * 0.02, 2));
        
        IF v_commission_to_reverse > 0 THEN
            SELECT * INTO v_owner_rec FROM public.users WHERE id = v_booking.owner_id FOR UPDATE;
            v_new_owner_debt := GREATEST(0.00, COALESCE(v_owner_rec.accumulated_cash_debt, 0.00) - v_commission_to_reverse);
            v_is_owner_blocked := (v_new_owner_debt >= COALESCE(v_owner_rec.debt_limit, 500.00));
            
            PERFORM set_config('vsp.system_override', 'true', true);
            UPDATE public.users
            SET accumulated_cash_debt = v_new_owner_debt,
                is_debt_blocked = v_is_owner_blocked,
                updated_at = v_now
            WHERE id = v_booking.owner_id;

            INSERT INTO public.transactions (
                user_id, booking_id, amount, type, status,
                payment_method, description, metadata, created_at, updated_at
            ) VALUES (
                v_booking.owner_id, p_booking_id, v_commission_to_reverse,
                'debt_reversal', 'completed', 'system_adjustment',
                'إلغاء مديونية عمولة لإلغاء حجز نقدي: #' || substring(p_booking_id::text, 1, 8),
                jsonb_build_object(
                    'previous_debt', v_owner_rec.accumulated_cash_debt,
                    'reversed_commission', v_commission_to_reverse,
                    'new_debt', v_new_owner_debt
                ),
                v_now, v_now
            );
        END IF;
    END IF;

    -- 8. Update booking status to cancelled, reset is_paid to false, set payment_status
    UPDATE public.bookings
    SET status = 'cancelled',
        is_paid = false,
        payment_status = CASE 
            WHEN v_refund_amount > 0 AND LOWER(COALESCE(payment_method, '')) != 'cash' THEN 'refund_pending' 
            WHEN v_refund_amount > 0 THEN 'refunded'
            ELSE payment_status 
        END,
        refund_amount = CASE WHEN v_refund_amount > 0 THEN v_refund_amount ELSE refund_amount END,
        cancellation_reason = p_reason,
        cancelled_at = v_now,
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 9. Insert refund transaction ONLY IF one does not already exist for this booking (Strict Idempotency)
    IF v_refund_amount > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.transactions 
            WHERE booking_id = p_booking_id 
              AND type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending')
        ) THEN
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
                COALESCE(v_booking.created_by_user_id, v_booking.user_id),
                p_booking_id,
                v_refund_amount,
                'refund',
                CASE WHEN LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' THEN 'completed' ELSE 'pending' END,
                COALESCE(v_booking.payment_method, 'online'),
                CASE WHEN LOWER(COALESCE(v_booking.payment_method, '')) = 'cash' 
                     THEN 'استرداد نقدي فوري بالملعب لإلغاء الحجز: ' || p_reason
                     ELSE 'طلب استرداد إلكتروني قيد المعالجة البنكية: ' || p_reason 
                END,
                v_now,
                v_now
            ) RETURNING id INTO v_tx_id;
        END IF;
    END IF;

    -- 10. Operational Notifications
    IF v_booking.owner_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_booking.owner_id,
            'إلغاء حجز في ملعبك',
            'قام اللاعب بإلغاء حجزه المقرر في ' || COALESCE(v_booking.stadium_name, 'الملعب') || ' وتم إتاحة الموعد مجدداً.',
            'booking_cancelled',
            v_now
        );
    END IF;

    IF v_booking.created_by_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_booking.created_by_user_id,
            'تم إلغاء الحجز بنجاح',
            CASE 
                WHEN v_refund_amount > 0 AND LOWER(COALESCE(v_booking.payment_method, '')) = 'cash'
                    THEN 'تم إلغاء حجزك وسيتم استرداد مبلغ ' || v_refund_amount || ' ج.م نقداً بالملعب.'
                WHEN v_refund_amount > 0 
                    THEN 'تم إلغاء حجزك بنجاح وجاري استرداد مبلغ ' || v_refund_amount || ' ج.م عبر وسيلة الدفع الخاصة بك.'
                ELSE 'تم إلغاء حجزك بنجاح دون أي رسوم.' 
            END,
            'booking_cancelled',
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم إلغاء الحجز بنجاح.',
        'refund_amount', v_refund_amount,
        'payment_status', CASE WHEN v_refund_amount > 0 AND LOWER(COALESCE(v_booking.payment_method, '')) != 'cash' THEN 'refund_pending' ELSE 'refunded' END,
        'booking_id', p_booking_id,
        'transaction_id', v_tx_id
    );
END;
$$;


-- 3. CREATE FINANCIAL RECONCILIATION VIEW
CREATE OR REPLACE VIEW public.v_financial_reconciliation AS
SELECT 
    u.id AS owner_id,
    u.name AS owner_name,
    u.phone AS owner_phone,
    COUNT(b.id) FILTER (WHERE b.status != 'cancelled') AS active_bookings_count,
    COALESCE(SUM(b.total_price) FILTER (WHERE b.payment_method != 'cash' AND (b.payment_status = 'paid' OR b.is_paid = true) AND b.status != 'cancelled'), 0.0) AS total_online_revenue,
    COALESCE(SUM(COALESCE(b.gateway_fee, b.platform_fee, 0.0)) FILTER (WHERE b.payment_method != 'cash' AND (b.payment_status = 'paid' OR b.is_paid = true) AND b.status != 'cancelled'), 0.0) AS total_gateway_fees,
    COALESCE(SUM(COALESCE(b.vsp_commission, round(b.total_price * 0.02, 2))) FILTER (WHERE (b.payment_status = 'paid' OR b.is_paid = true) AND b.status != 'cancelled'), 0.0) AS total_platform_commission,
    COALESCE(SUM(b.total_price) FILTER (WHERE b.payment_method = 'cash' AND (b.payment_status = 'paid' OR b.is_paid = true) AND b.status != 'cancelled'), 0.0) AS total_pitch_cash_revenue,
    COALESCE(u.accumulated_cash_debt, 0.0) AS accumulated_cash_debt,
    COALESCE(u.debt_limit, 500.0) AS debt_limit,
    COALESCE(u.is_debt_blocked, false) AS is_debt_blocked,
    COALESCE((SELECT SUM(amount) FROM public.payout_settlements WHERE owner_id = u.id AND status = 'completed'), 0.0) AS total_withdrawn,
    COALESCE((SELECT SUM(amount) FROM public.payout_settlements WHERE owner_id = u.id AND status IN ('pending', 'approved')), 0.0) AS pending_payouts
FROM public.users u
LEFT JOIN public.bookings b ON b.owner_id = u.id
WHERE u.role IN ('owner', 'admin', 'co_founder')
GROUP BY u.id, u.name, u.phone, u.accumulated_cash_debt, u.debt_limit, u.is_debt_blocked;
