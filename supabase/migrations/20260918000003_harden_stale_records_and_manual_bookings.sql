-- =============================================================================
-- Migration: 20260918000003_harden_stale_records_and_manual_bookings.sql
-- Description:
--   1. Self-healing for paid pending bookings (auto-promoted to confirmed) in auto_expire_stale_records.
--   2. Strict permissions on auto_expire_stale_records (restricted to service_role only).
--   3. Exception guard (unique_violation OR exclusion_violation) on manual booking creation.
--   4. Enforce NOT NULL on bookings.status to prevent escaping exclusion constraints.
-- =============================================================================

BEGIN;

-- ============================================================
-- (1) auto_expire_stale_records + self-healing
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_expire_stale_records()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- المرحلة 0: self-healing — حجز دُفع فعلاً لكن ظل عالقاً على pending
  UPDATE public.bookings
  SET status = 'confirmed', updated_at = NOW(),
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-promoted to confirmed - payment succeeded but status was stuck at pending]'
  WHERE status = 'pending'
    AND (is_paid = TRUE OR payment_status IN ('paid', 'completed'))
    AND created_at <= NOW() - INTERVAL '2 minutes';

  -- المرحلة 1: إلغاء الحجوزات التي انتهى قفلها المؤقت فوراً
  UPDATE public.bookings
  SET status = 'cancelled', payment_status = 'failed', updated_at = NOW(),
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired - payment window elapsed]'
  WHERE status = 'pending' AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND locked_until IS NOT NULL AND locked_until < NOW();

  -- المرحلة 2: Safety Net - إلغاء أي pending غير مدفوع تجاوز 10 دقائق
  UPDATE public.bookings
  SET status = 'cancelled', payment_status = 'failed', updated_at = NOW(),
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to payment timeout]'
  WHERE status = 'pending' AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '10 minutes';

  -- المرحلة 3: إلغاء التحديات المعلقة
  UPDATE public.bookings
  SET status = 'cancelled', updated_at = NOW(),
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Challenge expired automatically]'
  WHERE booking_type = 'challenge' AND status = 'pending'
    AND (NOW() - created_at >= INTERVAL '4 hours' OR start_time - NOW() <= INTERVAL '12 hours');
END;
$function$;

-- حصر صلاحيات التنفيذ في service_role فقط (ممنوعة عن anon و authenticated)
REVOKE EXECUTE ON FUNCTION public.auto_expire_stale_records() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_expire_stale_records() TO service_role;

-- ============================================================
-- (2) owner_create_manual_booking_atomic + exception handling
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(
    p_owner_id uuid,
    p_stadium_id uuid,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_customer_name text,
    p_customer_phone text DEFAULT NULL::text,
    p_notes text DEFAULT NULL::text,
    p_total_price numeric DEFAULT 0.0,
    p_collected_amount numeric DEFAULT 0.0,
    p_current_players integer DEFAULT 10
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_stadium RECORD; 
    v_owner RECORD; 
    v_overlap_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_booking_id UUID; 
    v_payment_status TEXT; 
    v_is_paid BOOLEAN;
    v_customer_clean TEXT; 
    v_caller_role TEXT; 
    v_actual_owner_id UUID;
    v_is_authorized BOOLEAN := false; 
    v_vsp_commission NUMERIC;
    v_new_debt NUMERIC; 
    v_is_blocked BOOLEAN;
BEGIN
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found', 'message', 'الملعب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', 'stadium_deleted', 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        v_is_authorized := true;
    ELSIF auth.uid() IS NOT NULL THEN
        IF v_stadium.owner_id = auth.uid() THEN
            v_is_authorized := true;
        ELSE
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
                v_is_authorized := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized', 'message', 'غير مصرح لك بالحجز في هذا الملعب: يمكنك فقط إدارة حجوزات ملاعبك.');
    END IF;

    v_actual_owner_id := v_stadium.owner_id;
    SELECT * INTO v_owner FROM public.users WHERE id = v_actual_owner_id FOR UPDATE;

    IF v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.00) THEN
        RETURN jsonb_build_object('success', false, 'code', 'DEBT_LIMIT_EXCEEDED', 'error', 'debt_limit_exceeded',
            'message', 'عذراً، تم إيقاف إنشاء الحجوزات النقدية مؤقتاً لتجاوز حد مديونية عمولات المنصة. يرجى تسوية المديونية للمتابعة.');
    END IF;

    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id AND status != 'cancelled'
      AND p_start_time < end_time AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'conflict', 'message', 'عذراً، هذا الموعد تم حجزه للتو أو يتعارض مع حجز آخر نشط.');
    END IF;

    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE WHEN v_is_paid THEN 'paid' WHEN p_collected_amount > 0 THEN 'partially_paid' ELSE 'pending' END;
    v_customer_clean := COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي');
    v_vsp_commission := round(p_total_price * 0.02, 2);

    -- معالجة استثناء تعارض القيد الحصري
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
            p_total_price, v_vsp_commission, 0.00,
            p_collected_amount, (p_collected_amount > 0), v_is_paid, v_payment_status,
            'cash', 'MANUAL_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
            'confirmed', p_current_players, true, false, v_now, v_now
        )
        RETURNING id INTO v_booking_id;
    EXCEPTION
        WHEN unique_violation OR exclusion_violation THEN
            RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN', 'error', 'conflict', 'message', 'عذراً، تم حجز هذا الموعد للتو من قبل مستخدم آخر.');
    END;

    v_new_debt := COALESCE(v_owner.accumulated_cash_debt, 0) + v_vsp_commission;
    v_is_blocked := (v_new_debt >= COALESCE(v_owner.debt_limit, 500.00));

    PERFORM set_config('vsp.system_override', 'true', true);
    UPDATE public.users SET accumulated_cash_debt = v_new_debt, is_debt_blocked = v_is_blocked, updated_at = v_now
    WHERE id = v_actual_owner_id;

    IF p_collected_amount > 0 THEN
        INSERT INTO public.transactions (user_id, booking_id, amount, type, status, payment_method, description, created_at, updated_at)
        VALUES (v_actual_owner_id, v_booking_id, p_collected_amount, 'cash', 'completed', 'cash',
            'دفع ' || CASE WHEN v_is_paid THEN 'كامل' ELSE 'عربون' END || ' حجز يدوي: ' || COALESCE(v_stadium.name, 'الملعب'),
            v_now, v_now);
    END IF;

    RETURN jsonb_build_object('success', true, 'booking_id', v_booking_id, 'vsp_commission', v_vsp_commission,
        'accumulated_cash_debt', v_new_debt, 'is_debt_blocked', v_is_blocked, 'message', 'تم إنشاء الحجز اليدوي بنجاح.');
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid, uuid, timestamptz, timestamptz, text, text, text, numeric, numeric, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_create_manual_booking_atomic(uuid, uuid, timestamptz, timestamptz, text, text, text, numeric, numeric, integer) TO authenticated, service_role;

-- ============================================================
-- (3) منع NULL في status نهائياً لحماية قيد الـ EXCLUDE
-- ============================================================
ALTER TABLE public.bookings ALTER COLUMN status SET NOT NULL;

COMMIT;
