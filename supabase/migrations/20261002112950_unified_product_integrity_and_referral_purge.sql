-- 1. Update verify_booking_qr_atomic to purge referral reward call while preserving full verification logic
CREATE OR REPLACE FUNCTION public.verify_booking_qr_atomic(
    p_booking_id UUID,
    p_qr_token TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_stadium RECORD;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_is_authorized BOOLEAN := false;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF v_caller_id IS NULL AND session_user NOT IN ('postgres', 'supabase_admin') AND COALESCE(auth.role(), '') != 'service_role' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'BOOKING_NOT_FOUND', 'message', 'الحجز غير موجود.');
    END IF;

    SELECT * INTO v_stadium FROM public.stadiums WHERE id = v_booking.stadium_id;

    -- Authorization check: Stadium owner or platform admin
    IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        v_is_authorized := true;
    ELSIF v_caller_id IS NOT NULL THEN
        IF v_stadium.owner_id = v_caller_id THEN
            v_is_authorized := true;
        ELSE
            SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
            IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
                v_is_authorized := true;
            END IF;
        END IF;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Only the stadium owner or platform admin can verify match attendance.'
            USING ERRCODE = '42501';
    END IF;

    -- 1. Single-use guard: check if already scanned
    IF v_booking.qr_scanned_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'QR_ALREADY_SCANNED', 'message', 'تم مسح رمز الحضور وتأكيد الحضور لهذا الحجز مسبقاً.');
    END IF;

    -- 2. State guard
    IF v_booking.status != 'confirmed' THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_BOOKING_STATUS', 'message', 'لا يمكن تأكيد حضور حجز غير مؤكد أو ملغي.');
    END IF;

    -- 3. Token hash verification
    IF v_booking.qr_hash IS NULL OR encode(digest(p_qr_token, 'sha256'), 'hex') != v_booking.qr_hash THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_QR_TOKEN', 'message', 'رمز الـ QR غير صالح أو لا يطابق بيانات هذا الحجز.');
    END IF;

    -- 4. Expiration check
    IF v_now > v_booking.qr_expires_at THEN
        RETURN jsonb_build_object('success', false, 'code', 'QR_EXPIRED', 'message', 'انتهت صلاحية رمز الـ QR المحدد.');
    END IF;

    -- 5. Mark completed and verified
    UPDATE public.bookings
    SET 
        qr_scanned_at = v_now,
        is_verified_by_owner = true,
        status = 'completed',
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'status', 'completed',
        'is_verified_by_owner', true,
        'message', 'تم تأكيد حضور المباراة واكتمال الحجز بنجاح.'
    );
END;
$$;

-- 2. Drop legacy referral functions
DROP FUNCTION IF EXISTS public.process_referral_reward_on_qr_verification(uuid, uuid);
DROP FUNCTION IF EXISTS public.register_user_referral(text);

-- 3. Update user sensitive fields trigger to remove points check
CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_system_override boolean := (current_setting('vsp.system_override', true) = 'true');
    v_jwt_role           text := COALESCE(auth.jwt() ->> 'role', auth.role(), '');
    v_caller_id          uuid := auth.uid();
    v_is_admin           boolean := false;
BEGIN
    IF v_is_system_override THEN
        RETURN NEW;
    END IF;

    IF v_jwt_role = 'service_role' THEN
        RETURN NEW;
    END IF;

    IF v_caller_id IS NULL AND v_jwt_role = '' AND session_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
        INTO v_is_admin
        FROM public.users
        WHERE id = v_caller_id;
    END IF;

    IF COALESCE(v_is_admin, false) THEN 
        RETURN NEW; 
    END IF;

    IF OLD.role IS DISTINCT FROM NEW.role
       OR OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan
       OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at
       OR OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at
       OR OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees
       OR OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned
       OR OLD.no_show_count IS DISTINCT FROM NEW.no_show_count
       OR OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified
       OR OLD.is_email_verified IS DISTINCT FROM NEW.is_email_verified
       OR OLD.verification_status IS DISTINCT FROM NEW.verification_status
       OR OLD.is_blocked IS DISTINCT FROM NEW.is_blocked
       OR OLD.has_stadium IS DISTINCT FROM NEW.has_stadium
       OR OLD.is_registration_complete IS DISTINCT FROM NEW.is_registration_complete
       OR OLD.is_onboarding_confirmed IS DISTINCT FROM NEW.is_onboarding_confirmed
       OR OLD.accumulated_cash_debt IS DISTINCT FROM NEW.accumulated_cash_debt
       OR OLD.debt_limit IS DISTINCT FROM NEW.debt_limit
       OR OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Account security, financial state, and lifecycle fields are server-authoritative.'
          USING errcode = '42501', detail = 'UNAUTHORIZED_USER_SENSITIVE_UPDATE';
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Drop legacy referral and points tables
DROP TABLE IF EXISTS public.referrals CASCADE;
DROP TABLE IF EXISTS public.points_ledger CASCADE;

-- 5. Drop legacy referral and points columns from users table
ALTER TABLE public.users DROP COLUMN IF EXISTS referral_code;
ALTER TABLE public.users DROP COLUMN IF EXISTS points;

-- 6. Align legacy view admin_stadium_settlements with SSOT platform fee config (0% cash, 2% online)
CREATE OR REPLACE VIEW public.admin_stadium_settlements AS
SELECT 
  b.owner_id,
  b.stadium_name,
  count(b.id) AS total_matches,
  sum(b.total_price) AS total_revenue,
  sum(CASE WHEN (b.payment_method = 'cash') THEN b.total_price ELSE 0 END) AS cash_collected_by_owner,
  sum(CASE WHEN (b.payment_method <> 'cash') THEN b.total_price ELSE 0 END) AS online_collected_by_vsp,
  round(sum(coalesce(b.platform_fee, b.vsp_commission, 0)), 2) AS vsp_commission,
  round(sum(CASE WHEN (b.payment_method <> 'cash') THEN b.total_price ELSE 0 END) - sum(coalesce(b.platform_fee, b.vsp_commission, 0)), 2) AS net_balance
FROM public.bookings b
WHERE b.status = 'completed' AND b.match_result_status <> 'disputed'
GROUP BY b.owner_id, b.stadium_name;
