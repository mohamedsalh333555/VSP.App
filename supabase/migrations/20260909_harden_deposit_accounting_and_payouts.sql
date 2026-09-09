-- ==============================================================================
-- 🔒 VSP PRODUCTION FINANCIAL HARDENING MIGRATION
-- Migration: 20260909_harden_deposit_accounting_and_payouts.sql
-- Description: Fix deposit accounting leak, align partial payment status, and ensure
-- accurate owner online vs cash revenue calculations.
-- ==============================================================================

-- 1️⃣ دالة احتساب الملخص المالي والنزاهة المحاسبية لرصيد المالك
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

    -- 1. حساب الدخل الإلكتروني الفعلي ورسوم المنصة للحجوزات المؤكدة غير الملغاة
    -- معالجة صحيحة لحجوزات العربون: احتساب العربون المحصل إلكترونياً فقط وليس إجمالي سعر الحجز
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN (needs_deposit = true OR is_deposit_paid = true OR payment_status = 'partially_paid') 
                     AND is_paid = false 
                     AND COALESCE(deposit_paid, deposit_amount, 0) > 0 
                THEN COALESCE(NULLIF(deposit_paid, 0), deposit_amount, 0.0)
                ELSE total_price
            END
        ), 0.0),
        COALESCE(SUM(COALESCE(platform_fee, 0.0)), 0.0),
        COUNT(*)
    INTO 
        v_total_online_revenue,
        v_total_platform_fees,
        v_total_completed_bookings
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status IN ('paid', 'partially_paid') OR is_paid = true OR is_deposit_paid = true)
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
    -- يشمل الحجوزات النقدية الخالصة + المتبقي نقداً بالملعب من حجوزات العربون
    SELECT COALESCE(SUM(
        CASE 
            WHEN payment_method = 'cash' THEN total_price
            WHEN (needs_deposit = true OR is_deposit_paid = true OR payment_status = 'partially_paid') 
                 AND is_paid = false 
                 AND COALESCE(deposit_paid, deposit_amount, 0) > 0 
            THEN GREATEST(0.0, total_price - COALESCE(NULLIF(deposit_paid, 0), deposit_amount, 0.0))
            ELSE 0.0
        END
    ), 0.0)
    INTO v_cash_revenue
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND (
          (payment_method = 'cash' AND (payment_status = 'paid' OR is_paid = true))
          OR
          (payment_method != 'cash' AND (needs_deposit = true OR is_deposit_paid = true OR payment_status = 'partially_paid') AND status = 'confirmed')
      )
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


-- 2️⃣ تحصين دالة طلب تسوية وسحب مستحقات المالك واحتساب العربون بدقة
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

    -- 🔒 التحقق الصارم من الرصيد المتاح للسحب من الحجوزات الإلكترونية مع حماية العربون
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN (needs_deposit = true OR is_deposit_paid = true OR payment_status = 'partially_paid') 
                     AND is_paid = false 
                     AND COALESCE(deposit_paid, deposit_amount, 0) > 0 
                THEN COALESCE(NULLIF(deposit_paid, 0), deposit_amount, 0.0)
                ELSE total_price
            END
        ), 0.0),
        COALESCE(SUM(COALESCE(platform_fee, 0.0)), 0.0)
    INTO 
        v_total_online_revenue,
        v_total_platform_fees
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND payment_method != 'cash'
      AND (payment_status IN ('paid', 'partially_paid') OR is_paid = true OR is_deposit_paid = true)
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
        ROUND(p_amount, 2),
        p_method,
        TRIM(p_destination),
        'pending',
        v_now,
        v_now
    ) RETURNING id INTO v_settlement_id;

    -- إرسال إشعار للمالك بتأكيد تسجيل طلبه
    INSERT INTO public.notifications (
        user_id,
        title,
        body,
        type,
        created_at
    ) VALUES (
        p_owner_id,
        'تم تسجيل طلب تسوية الأرباح 💸',
        'تم استلام طلب سحب مبلغ ' || ROUND(p_amount, 2) || ' ج.م عبر ' || p_method || ' وجاري مراجعته والتحويل خلال 24 ساعة.',
        'payout_requested',
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'amount', ROUND(p_amount, 2),
        'remaining_available_balance', ROUND(v_available_balance - p_amount, 2),
        'message', 'تم تقديم طلب السحب بنجاح وهو قيد المعالجة.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_owner_payout_settlement_atomic(uuid, numeric, text, text) TO authenticated, service_role;


-- 3️⃣ مزامنة دالة معالجة الـ Webhook مع منطق سداد العربون الجزئي
CREATE OR REPLACE FUNCTION public.process_paymob_webhook(
  p_booking_id TEXT,
  p_txn_id TEXT,
  p_order_id TEXT,
  p_success BOOLEAN,
  p_signature_verified BOOLEAN,
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_clean_id TEXT;
  v_existing_booking RECORD;
  v_already_processed BOOLEAN;
  v_is_deposit_only BOOLEAN := FALSE;
  v_deposit_amount NUMERIC := 0.0;
BEGIN
  -- التحقق من أن الاستدعاء قادم حصراً من الخدمة الداخلية أو service_role
  IF auth.role() IS NOT NULL AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Security Alert: Direct user invocation of payment webhook RPC is prohibited.';
  END IF;

  v_clean_id := split_part(p_booking_id, '_', 1);

  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, 
    CASE WHEN v_clean_id ~ '^[0-9a-fA-F-]{36}$' THEN v_clean_id::uuid ELSE NULL END, 
    p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  IF p_txn_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bookings
      WHERE paymob_txn_id = p_txn_id
        AND status = 'confirmed'
    ) INTO v_already_processed;

    IF v_already_processed THEN
      RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'duplicate_webhook_ignored',
        'booking_id', v_clean_id
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id::text = v_clean_id
  FOR UPDATE;

  IF v_existing_booking.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'booking_not_found',
      'message', 'No booking found matching the provided ID.'
    );
  END IF;

  -- فحص إذا كان الحجز نظام عربون فقط
  IF v_existing_booking.needs_deposit = TRUE AND COALESCE(v_existing_booking.deposit_amount, 0) > 0 THEN
    v_is_deposit_only := TRUE;
    v_deposit_amount := v_existing_booking.deposit_amount;
  END IF;

  IF p_success AND p_signature_verified THEN
    UPDATE public.bookings
    SET 
      status = 'confirmed',
      is_paid = NOT v_is_deposit_only,
      payment_status = CASE WHEN v_is_deposit_only THEN 'partially_paid' ELSE 'paid' END,
      is_deposit_paid = TRUE,
      deposit_paid = CASE WHEN v_is_deposit_only THEN v_deposit_amount ELSE COALESCE(deposit_paid, total_price) END,
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_verified = TRUE,
      webhook_processed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_existing_booking.id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'booking_id', v_existing_booking.id,
      'action', 'booking_confirmed',
      'payment_status', CASE WHEN v_is_deposit_only THEN 'partially_paid' ELSE 'paid' END
    );
  ELSE
    UPDATE public.bookings
    SET 
      payment_status = 'failed',
      webhook_verified = p_signature_verified,
      webhook_processed_at = NOW(),
      updated_at = NOW()
    WHERE id = v_existing_booking.id;

    RETURN jsonb_build_object(
      'success', FALSE,
      'booking_id', v_existing_booking.id,
      'action', 'payment_failed_recorded'
    );
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_paymob_webhook FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_paymob_webhook TO service_role;
