-- ==============================================================================
-- VSP STAGE 6 MIGRATION: SECURITY, AUTHORIZATION & FINANCIAL HARDENING
-- Migration Name: 20260915_stage6_security_hardening.sql
-- Target Database: Supabase / PostgreSQL 15.8 (Project: mktqkddbcddrxjxabdua)
-- Applies Zero-Trust server-side security, revokes direct PostgREST spoofing,
-- hardens sensitive user fields, RPCs, storage policies, and financial ledgers.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. [F-001] USERS TABLE SENSITIVE COLUMN PROTECTION
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text;
  v_is_admin boolean := false;
BEGIN
  -- Allow internal postgres and service_role system processes ONLY when no user identity is set
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    RETURN NEW;
  END IF;

  -- Verify if caller is an authoritative administrator based on pre-existing database record
  IF auth.uid() IS NOT NULL THEN
    SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text, 'cofounder'::text]))
    INTO v_is_admin
    FROM public.users
    WHERE id = auth.uid();
  END IF;

  -- Allow platform admins to update sensitive user fields
  IF COALESCE(v_is_admin, false) THEN
    RETURN NEW;
  END IF;

  -- For normal authenticated users, strictly forbid self-mutation of sensitive columns
  IF (OLD.role IS DISTINCT FROM NEW.role) OR
     (OLD.subscription_plan IS DISTINCT FROM NEW.subscription_plan) OR
     (OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at) OR
     (OLD.trial_ends_at IS DISTINCT FROM NEW.trial_ends_at) OR
     (OLD.total_platform_fees IS DISTINCT FROM NEW.total_platform_fees) OR
     (OLD.cash_booking_banned IS DISTINCT FROM NEW.cash_booking_banned) OR
     (OLD.no_show_count IS DISTINCT FROM NEW.no_show_count) OR
     (OLD.is_identity_verified IS DISTINCT FROM NEW.is_identity_verified) OR
     (OLD.verification_status IS DISTINCT FROM NEW.verification_status) OR
     (OLD.is_blocked IS DISTINCT FROM NEW.is_blocked) THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Modifying security-sensitive user fields is restricted to platform administrators.'
      USING ERRCODE = '42501', DETAIL = 'UNAUTHORIZED_SENSITIVE_FIELD_UPDATE';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_protect_users_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_users_sensitive_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_protect_user_sensitive_fields();


-- ------------------------------------------------------------------------------
-- 2. [F-003] HARDEN verify_match_played AUTHORIZATION & IDEMPOTENCY
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.verify_match_played(
    p_booking_id uuid,
    p_attended boolean,
    p_absent_team_id text DEFAULT NULL::text
)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_caller_role text;
  v_is_authorized boolean := false;
BEGIN
  -- 1. Fetch booking record
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Strict Zero-Trust Authorization check (auth.uid = owner_id OR admin OR service_role)
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    v_is_authorized := true;
  ELSIF auth.uid() IS NOT NULL THEN
    IF v_booking.owner_id = auth.uid() THEN
      v_is_authorized := true;
    ELSE
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
        v_is_authorized := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Only the stadium owner or platform administrators can verify match attendance.'
      USING ERRCODE = '42501';
  END IF;

  -- 3. Idempotency Check: Do not trigger duplicate Elo calculations, penalties, or status writes
  IF p_attended THEN
    IF v_booking.is_verified_by_owner IS TRUE AND v_booking.status = 'completed' THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = true,
      status = 'completed',
      updated_at = now()
    WHERE id = p_booking_id;
  ELSE
    IF v_booking.status = 'cancelled' AND v_booking.is_verified_by_owner IS FALSE THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = false,
      absent_team_id = p_absent_team_id,
      status = 'cancelled',
      updated_at = now()
    WHERE id = p_booking_id;

    IF p_absent_team_id IS NOT NULL THEN
      UPDATE public.teams SET attendance_score = GREATEST(0, attendance_score - 10) WHERE id::text = p_absent_team_id;
      UPDATE public.users SET no_show_count = no_show_count + 1 WHERE id = (SELECT captain_id FROM public.teams WHERE id::text = p_absent_team_id);
    END IF;
  END IF;

  RETURN true;
END;
$function$;


-- ------------------------------------------------------------------------------
-- 3. [F-002] FIX owner_create_manual_booking_atomic AUTHORIZATION & SOFT-DELETE
-- ------------------------------------------------------------------------------

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
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_stadium RECORD;
    v_overlap_count INT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_booking_id UUID;
    v_payment_status TEXT;
    v_is_paid BOOLEAN;
    v_customer_clean TEXT;
    v_caller_role TEXT;
    v_actual_owner_id UUID;
    v_is_authorized BOOLEAN := false;
BEGIN
    -- 1. Fetch stadium and verify existence
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found', 'message', 'الملعب غير موجود.');
    END IF;

    -- [F-016] Reject soft-deleted stadium
    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'error', 'stadium_deleted', 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    -- 2. Strict Authorization check: Caller must own this stadium OR be admin/service_role
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

    -- Bind authoritative owner ID from the stadium record (Zero-Trust)
    v_actual_owner_id := v_stadium.owner_id;

    -- 3. Lock stadium for update
    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    -- 4. Overlap check
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'conflict', 'message', 'عذراً، هذا الموعد تم حجزه للتو أو يتعارض مع حجز آخر نشط.');
    END IF;

    -- 5. Payment status
    v_is_paid := (p_collected_amount >= p_total_price AND p_total_price > 0);
    v_payment_status := CASE 
        WHEN v_is_paid THEN 'paid'
        WHEN p_collected_amount > 0 THEN 'partially_paid'
        ELSE 'pending'
    END;

    v_customer_clean := COALESCE(NULLIF(TRIM(p_customer_name), ''), 'حجز يدوي');

    -- 6. Insert booking with authoritative v_actual_owner_id
    INSERT INTO public.bookings (
        stadium_id,
        stadium_name,
        owner_id,
        user_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        host_name,
        player_phone,
        notes,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        payment_transaction_id,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        v_stadium.name,
        v_actual_owner_id,
        v_actual_owner_id,
        COALESCE(auth.uid(), v_actual_owner_id),
        p_start_time,
        p_end_time,
        'personal',
        v_customer_clean,
        v_customer_clean,
        NULLIF(TRIM(p_customer_phone), ''),
        NULLIF(TRIM(p_notes), ''),
        p_total_price,
        p_collected_amount,
        (p_collected_amount > 0),
        v_is_paid,
        v_payment_status,
        'cash',
        'MANUAL_' || EXTRACT(EPOCH FROM v_now)::BIGINT,
        'confirmed',
        p_current_players,
        true,
        false,
        v_now,
        v_now
    )
    RETURNING id INTO v_booking_id;

    -- 7. Insert cash transaction if collected
    IF p_collected_amount > 0 THEN
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
            v_actual_owner_id,
            v_booking_id,
            p_collected_amount,
            'cash',
            'completed',
            'cash',
            'دفع ' || CASE WHEN v_is_paid THEN 'كامل' ELSE 'عربون' END || ' حجز يدوي: ' || COALESCE(v_stadium.name, 'الملعب'),
            v_now,
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'تم إنشاء الحجز اليدوي بنجاح.'
    );
END;
$function$;


-- ------------------------------------------------------------------------------
-- 4. [F-004] HARDEN cancel_booking_with_refund_atomic (ROW LOCK, IDEMPOTENCY, REFUND DUP GUARD)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
    p_booking_id uuid,
    p_user_id uuid,
    p_reason text DEFAULT 'Cancelled by user'::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_refund_amount NUMERIC(10, 2) := 0.00;
    v_tx_id UUID := NULL;
    v_caller_role TEXT;
    v_minutes_since_created NUMERIC;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. 🔒 Row lock: Lock target booking row to prevent concurrent race conditions
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'booking_not_found', 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. 🛡️ Idempotency & State Guard: If booking is ALREADY cancelled, return safely without duplicating refund
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

    -- 3. Authorization Check
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

    -- 4. Check 6-hour cutoff rule for players (with 20-minute grace window)
    IF (auth.role() = 'service_role' OR auth.uid() = v_booking.created_by_user_id OR auth.uid() = v_booking.user_id) THEN
        v_minutes_since_created := EXTRACT(EPOCH FROM (v_now - COALESCE(v_booking.created_at, v_now))) / 60.0;
        
        IF v_minutes_since_created > 20.0 AND v_booking.start_time <= (v_now + INTERVAL '6 hours') THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'cannot_cancel_within_6_hours',
                'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة من إتمام الحجز وفقاً للائحة).'
            );
        END IF;
    END IF;

    -- 5. Calculate refund amount if payment was confirmed
    IF (v_booking.payment_status IN ('paid', 'confirmed') OR v_booking.is_paid IS TRUE OR v_booking.is_deposit_paid IS TRUE) THEN
        v_refund_amount := COALESCE(v_booking.deposit_paid, v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- 6. Update booking status to cancelled, reset is_paid to false, set payment_status
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

    -- 7. Insert refund transaction ONLY IF one does not already exist for this booking (Strict Idempotency)
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

    -- 8. Notifications
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
$function$;

-- Partial unique index ensuring at most one refund ledger record exists per booking
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_unique_booking_refund 
ON public.transactions (booking_id) 
WHERE (type IN ('refund', 'refund_card', 'refund_wallet', 'refund_cash', 'refund_pending') AND status IN ('completed', 'pending'));


-- ------------------------------------------------------------------------------
-- 5. [F-005] & [F-006] REVOKE DIRECT INSERT ON BOOKINGS & TRANSACTIONS
-- ------------------------------------------------------------------------------

-- Revoke direct table-level insertion from authenticated role
REVOKE INSERT ON public.bookings FROM authenticated;
REVOKE INSERT ON public.transactions FROM authenticated;

-- Tighten RLS policies on bookings
DROP POLICY IF EXISTS bookings_insert_secure ON public.bookings;
DROP POLICY IF EXISTS bookings_insert_admin_service ON public.bookings;
CREATE POLICY bookings_insert_admin_service ON public.bookings
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin'))
  );

-- Tighten RLS policies on transactions
DROP POLICY IF EXISTS transactions_insert_policy ON public.transactions;
DROP POLICY IF EXISTS transactions_insert_admin_service ON public.transactions;
CREATE POLICY transactions_insert_admin_service ON public.transactions
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin'))
  );


-- ------------------------------------------------------------------------------
-- 6. [F-007] HARDEN get_admin_quick_metrics FINANCIAL REVENUE AGGREGATION
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_admin_quick_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_owners integer;
  v_pending_verifications integer;
  v_active_bookings integer;
  v_total_revenue numeric;
BEGIN
  -- Verify admin authorization
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = ANY(ARRAY['admin', 'co_founder', 'super_admin', 'cofounder'])
    ) THEN
      RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT count(*) INTO v_total_owners FROM public.users WHERE role = 'owner';
  SELECT count(*) INTO v_pending_verifications FROM public.users WHERE role = 'owner' AND verification_status = 'pending';
  SELECT count(*) INTO v_active_bookings FROM public.bookings WHERE status IN ('confirmed', 'upcoming');

  -- Gross platform completed turnover: only completed payments, excluding duplicates, refunds, payouts
  SELECT COALESCE(sum(amount), 0) INTO v_total_revenue 
  FROM public.transactions 
  WHERE type IN ('digital', 'cash_settlement') 
    AND status = 'completed';

  RETURN jsonb_build_object(
    'total_owners', v_total_owners,
    'pending_verifications', v_pending_verifications,
    'active_bookings', v_active_bookings,
    'total_revenue', v_total_revenue
  );
END;
$function$;


-- ------------------------------------------------------------------------------
-- 7. [F-009] HARDEN SENSITIVE ADMINISTRATIVE & DISCIPLINARY RPCS
-- ------------------------------------------------------------------------------

-- 7.1 prepare_tournament_bracket: restrict to championship owner or admin
CREATE OR REPLACE FUNCTION public.prepare_tournament_bracket(p_championship_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.championships c
      LEFT JOIN public.users u ON u.id = auth.uid()
      WHERE c.id = p_championship_id
        AND (c.owner_id = auth.uid() OR u.role IN ('admin', 'co_founder', 'super_admin', 'cofounder'))
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only the championship organizer or platform administrator can prepare brackets.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;
END;
$function$;

-- 7.2 dismiss_no_show_penalty: restrict to admin/co_founder/service_role
CREATE OR REPLACE FUNCTION public.dismiss_no_show_penalty(p_player_id uuid, p_booking_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_no_show int;
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only platform administrators can dismiss penalties.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.bookings
  SET 
    is_paid = true,
    payment_status = 'paid',
    notes = COALESCE(notes, '') || E'\n[DISPUTE RESOLVED - PENALTY CLEARED]'
  WHERE id = p_booking_id;

  SELECT GREATEST(0, COALESCE(no_show_count, 1) - 1) INTO v_new_no_show
  FROM public.users
  WHERE id = p_player_id;

  UPDATE public.users
  SET 
    no_show_count = v_new_no_show,
    is_blocked = (v_new_no_show >= 3),
    cash_booking_banned = (v_new_no_show >= 2),
    updated_at = NOW()
  WHERE id = p_player_id;
END;
$function$;

-- 7.3 apply_no_show_penalty: restrict direct invocation to admin/service_role
CREATE OR REPLACE FUNCTION public.apply_no_show_penalty(p_player_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only administrators or authorized system services can apply penalties directly.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.users
  SET no_show_count = COALESCE(no_show_count, 0) + 1,
      cash_booking_banned = CASE 
          WHEN COALESCE(no_show_count, 0) + 1 >= 2 THEN true 
          ELSE false 
      END
  WHERE id = p_player_id;
END;
$function$;

-- 7.4 crown_individual_1v1_champion: restrict to admin/service_role
CREATE OR REPLACE FUNCTION public.crown_individual_1v1_champion(p_championship_id uuid, p_winner_user_id uuid, p_prize numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ_name TEXT;
  v_user_name TEXT;
  v_user_avatar TEXT;
BEGIN
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin', 'cofounder')
    ) THEN
      RAISE EXCEPTION 'PERMISSION_DENIED: Only platform administrators can crown champions.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT name INTO v_champ_name FROM public.championships WHERE id = p_championship_id;
  SELECT name, profile_image_url INTO v_user_name, v_user_avatar FROM public.users WHERE id = p_winner_user_id;

  UPDATE public.championships
  SET 
    status = 'completed',
    champion_user_id = p_winner_user_id,
    champion_team_name = v_user_name,
    updated_at = NOW()
  WHERE id = p_championship_id;

  INSERT INTO public.player_trophies (user_id, championship_id, title, prize_won, created_at)
  VALUES (p_winner_user_id, p_championship_id, 'بطل بطولة ' || COALESCE(v_champ_name, 'VSP'), p_prize, NOW());

  INSERT INTO public.vsp_1vs1_players (id, name, avatar_url, titles, total_points, skill_points, goals, tackles, trend, created_at, updated_at)
  VALUES (p_winner_user_id, COALESCE(v_user_name, 'Player'), COALESCE(v_user_avatar, ''), 1, 100, 50, 0, 0, 'up', NOW(), NOW())
  ON CONFLICT (id) DO UPDATE
  SET titles = COALESCE(public.vsp_1vs1_players.titles, 0) + 1,
      total_points = public.vsp_1vs1_players.total_points + 50,
      updated_at = NOW();
END;
$function$;

-- 7.5 join_public_match & request_join_public_match: verify auth.uid matches p_user_id
CREATE OR REPLACE FUNCTION public.request_join_public_match(p_booking_id text, p_user_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
    v_booking_uuid UUID;
    v_user_uuid UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- [F-009] Verify caller is joining for their own account
    IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        IF auth.uid() IS NULL OR auth.uid()::text != p_user_id THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: You can only join public matches for your own account.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    v_booking_uuid := p_booking_id::UUID;
    v_user_uuid := p_user_id::UUID;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id = v_booking_uuid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'match_cancelled';
    END IF;

    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
    IF v_user_blocked IS TRUE THEN
        RAISE EXCEPTION 'user_blocked';
    END IF;

    v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
    IF v_booking.current_players >= v_capacity THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    IF p_user_id = ANY(COALESCE(v_booking.joined_user_ids::text[], ARRAY[]::text[])) THEN
        RAISE EXCEPTION 'already_joined';
    END IF;

    SELECT COUNT(*) INTO v_user_conflict
    FROM public.bookings
    WHERE status != 'cancelled'
      AND id != v_booking_uuid
      AND (created_by_user_id::text = p_user_id OR p_user_id = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[])))
      AND start_time < v_booking.end_time
      AND end_time > v_booking.start_time;

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::text[]), p_user_id),
        current_players = COALESCE(current_players, 0) + 1,
        updated_at = v_now
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'current_players', v_booking.current_players + 1
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.join_public_match(p_booking_id uuid, p_user_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_res jsonb;
BEGIN
  v_res := public.request_join_public_match(p_booking_id::text, p_user_id);
  RETURN (v_res->>'success')::boolean;
END;
$function$;


-- ------------------------------------------------------------------------------
-- 8. [F-008] HARDEN STORAGE POLICIES (BANNERS & STADIUM-IMAGES)
-- ------------------------------------------------------------------------------

-- Drop insecure open policies
DROP POLICY IF EXISTS "Admin Delete Access for Banner Images" ON storage.objects;
DROP POLICY IF EXISTS "Admin Modify Access for Banner Images" ON storage.objects;
DROP POLICY IF EXISTS "Admin Upload Access for Banner Images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete stadium images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update stadium images" ON storage.objects;
DROP POLICY IF EXISTS "Owner delete own stadium images" ON storage.objects;
DROP POLICY IF EXISTS "Owner update own stadium images" ON storage.objects;

-- Admin-only policies for banners
CREATE POLICY "Admin Upload Access for Banner Images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'banners' AND (
      EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin'))
    )
  );

CREATE POLICY "Admin Modify Access for Banner Images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'banners' AND (
      EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin'))
    )
  );

CREATE POLICY "Admin Delete Access for Banner Images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'banners' AND (
      EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin'))
    )
  );

-- Owner-verified policies for stadium-images
CREATE POLICY "Owner delete own stadium images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'stadium-images' AND (
      (auth.uid() = owner) OR
      ((storage.foldername(name))[1] = auth.uid()::text) OR
      (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin')))
    )
  );

CREATE POLICY "Owner update own stadium images" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'stadium-images' AND (
      (auth.uid() = owner) OR
      ((storage.foldername(name))[1] = auth.uid()::text) OR
      (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder', 'super_admin')))
    )
  );


-- ------------------------------------------------------------------------------
-- 9. [F-014] BOOKING STATE MACHINE TRIGGER
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_fn_enforce_booking_state_machine()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Allow internal maintenance or migrations ONLY when no user identity is set
  IF (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    RETURN NEW;
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  -- 1. Cancelled is terminal: cannot be reactivated
  IF OLD.status = 'cancelled' AND NEW.status != 'cancelled' THEN
    RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Cancelled bookings cannot be reactivated (% -> %)', OLD.status, NEW.status
      USING ERRCODE = 'P0004';
  END IF;

  -- 2. Completed is terminal: cannot be cancelled or reopened
  IF OLD.status = 'completed' AND NEW.status != 'completed' THEN
    RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Completed bookings cannot be modified (% -> %)', OLD.status, NEW.status
      USING ERRCODE = 'P0004';
  END IF;

  -- 3. Pending bookings cannot jump directly to completed without confirmation
  IF OLD.status = 'pending' AND NEW.status = 'completed' THEN
    RAISE EXCEPTION 'ILLEGAL_STATE_TRANSITION: Pending bookings must be confirmed before completion (% -> %)', OLD.status, NEW.status
      USING ERRCODE = 'P0004';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_booking_state_machine ON public.bookings;
DROP TRIGGER IF EXISTS aaa_trg_enforce_booking_state_machine ON public.bookings;
CREATE TRIGGER aaa_trg_enforce_booking_state_machine
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_fn_enforce_booking_state_machine();


-- ------------------------------------------------------------------------------
-- 10. [F-015] ALIGN check_owner_stadium_limit PRE-CHECK WITH TRIGGER LIMIT
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_owner RECORD;
    v_count INT;
    v_max_allowed INT := 0;
    v_is_active_trial BOOLEAN := FALSE;
    v_is_sub_active BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', false, 'message', 'المستخدم غير موجود.');
    END IF;

    IF v_owner.role IN ('admin', 'co_founder', 'super_admin') THEN
        RETURN jsonb_build_object('allowed', true, 'current_count', 0, 'max_allowed', 999);
    END IF;

    v_is_active_trial := (
        COALESCE(v_owner.subscription_plan, 'free_trial') = 'free_trial' AND
        (
            (v_owner.trial_ends_at IS NOT NULL AND v_owner.trial_ends_at > NOW()) OR
            (v_owner.trial_ends_at IS NULL AND v_owner.created_at + INTERVAL '60 days' > NOW())
        )
    );

    v_is_sub_active := (
        v_owner.subscription_expires_at IS NOT NULL AND v_owner.subscription_expires_at > NOW()
    );

    IF v_owner.subscription_plan = 'pro' AND v_is_sub_active THEN
        v_max_allowed := 3;
    ELSIF (v_owner.subscription_plan = 'basic' AND v_is_sub_active) OR v_is_active_trial THEN
        v_max_allowed := 1;
    ELSE
        v_max_allowed := 0;
    END IF;

    SELECT COUNT(*) INTO v_count 
    FROM public.stadiums 
    WHERE owner_id = p_owner_id AND is_deleted_by_owner = false;

    IF v_count >= v_max_allowed THEN
        RETURN jsonb_build_object(
            'allowed', false,
            'current_count', v_count,
            'max_allowed', v_max_allowed,
            'message', 'لقد وصلت للحد الأقصى للملاعب المسموح بها في باقتك (' || v_max_allowed || ' ملاعب). يرجى ترقية باقتك لإضافة ملاعب جديدة.'
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'current_count', v_count,
        'max_allowed', v_max_allowed
    );
END;
$function$;


-- ------------------------------------------------------------------------------
-- 11. [F-016] HARDEN create_booking_atomic TO REJECT SOFT-DELETED STADIUMS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id text,
    p_user_id text,
    p_owner_id text,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_booking_type text,
    p_total_price numeric,
    p_platform_fee numeric,
    p_stadium_name text DEFAULT NULL::text,
    p_stadium_image_url text DEFAULT NULL::text,
    p_is_private boolean DEFAULT true,
    p_rent_ball boolean DEFAULT false,
    p_needs_deposit boolean DEFAULT false,
    p_deposit_amount numeric DEFAULT 0,
    p_payment_method text DEFAULT 'cash'::text,
    p_payment_status text DEFAULT 'pending'::text,
    p_player_team_id text DEFAULT NULL::text,
    p_player_team_name text DEFAULT NULL::text,
    p_opponent_team_id text DEFAULT NULL::text,
    p_opponent_team_name text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_stadium RECORD;
    v_conflict_count INT;
    v_active_cash_count INT;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_duration_hours NUMERIC;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0.0;
    v_final_total_price NUMERIC;
    v_final_deposit_amount NUMERIC;
    v_final_needs_deposit BOOLEAN;
    v_final_owner_id UUID;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_final_deposit_paid NUMERIC;
    v_locked_until TIMESTAMPTZ;
    v_new_booking_id UUID;
    v_calculated_fee NUMERIC;
BEGIN
    -- 1. Caller verification
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder')) AND COALESCE(auth.role(), '') <> 'service_role' THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. Duration check
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

    -- 3. Lock stadium
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Stadium existence and active status check
    SELECT * INTO v_stadium
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    -- [F-016] Reject soft-deleted stadiums
    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز (تم حذفه من قِبل المالك).');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. Calculate official server price
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

    -- 6. User checks & no-show limits
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

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

    -- 7. Overlap check
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

    -- 8. Status setup
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

    -- 9. Server platform fee calculation
    v_calculated_fee := round((v_final_total_price * 0.0475) + 3.0, 2);

    -- 10. Insert booking
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
$function$;


-- ------------------------------------------------------------------------------
-- 12. [F-011] TIMEZONE FIX FOR handle_stadium_breaks_collision
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_stadium_breaks_collision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_break_start timestamptz;
  v_break_end timestamptz;
  v_is_split_shift boolean;
  v_break_start_str text;
  v_break_end_str text;
  v_start_time time;
  v_end_time time;
  v_today_cairo date;
BEGIN
  v_is_split_shift := COALESCE((NEW.features->>'isSplitShift')::boolean, false);
  v_break_start_str := NEW.features->'breakTime'->>'start';
  v_break_end_str := NEW.features->'breakTime'->>'end';

  IF (v_is_split_shift = true AND v_break_start_str IS NOT NULL AND v_break_end_str IS NOT NULL) THEN
    
    BEGIN
      v_start_time := v_break_start_str::time;
      v_end_time := v_break_end_str::time;
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        v_start_time := to_timestamp(v_break_start_str, 'HH12:MI AM')::time;
        v_end_time := to_timestamp(v_break_end_str, 'HH12:MI AM')::time;
      EXCEPTION WHEN OTHERS THEN
        RETURN NEW;
      END;
    END;

    -- Compute break window using explicit Egyptian local calendar date and timezone
    v_today_cairo := (timezone('Africa/Cairo', now()))::date;
    v_break_start := (v_today_cairo + v_start_time) AT TIME ZONE 'Africa/Cairo';
    v_break_end := (v_today_cairo + v_end_time) AT TIME ZONE 'Africa/Cairo';

    IF (v_break_end <= v_break_start) THEN
      v_break_end := v_break_end + interval '1 day';
    END IF;

    FOR v_booking IN 
      SELECT id, created_by_user_id
      FROM public.bookings
      WHERE stadium_id = NEW.id
        AND status = 'confirmed'
        AND start_time < v_break_end 
        AND end_time > v_break_start
    LOOP
      UPDATE public.bookings
      SET 
        status = 'cancelled',
        payment_status = 'refund_pending',
        updated_at = now()
      WHERE id = v_booking.id;

      INSERT INTO public.notifications (user_id, title, body, type, booking_id, created_at)
      VALUES (
        v_booking.created_by_user_id,
        '⚠️ إلغاء حجز واسترداد المبلغ',
        'تم إغلاق الملعب لفترة صيانة/راحة، وجاري استرداد المبلغ إلى حسابك.',
        'booking_cancelled',
        v_booking.id,
        now()
      );
    END LOOP;

  END IF;

  RETURN NEW;
END;
$function$;


-- ------------------------------------------------------------------------------
-- 13. PRESERVE OWNER MANUAL CASH BOOKINGS IN enforce_cash_booking_restrictions
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enforce_cash_booking_restrictions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user_record record;
BEGIN
  -- If booking is created by the stadium owner for their own stadium (manual desk booking), bypass player restriction
  IF NEW.created_by_user_id IS NOT NULL AND NEW.owner_id IS NOT NULL AND NEW.created_by_user_id = NEW.owner_id THEN
    RETURN NEW;
  END IF;

  SELECT is_blocked, COALESCE(no_show_count, 0) as no_show_count INTO v_user_record
  FROM public.users
  WHERE id = NEW.created_by_user_id;

  IF FOUND THEN
    IF (v_user_record.is_blocked = true) THEN
      RAISE EXCEPTION 'حسابك معلق حالياً من قبل الإدارة. لا يمكنك إجراء حجوزات جديدة.';
    END IF;

    IF (NEW.payment_method = 'cash' AND v_user_record.no_show_count >= 2) THEN
      RAISE EXCEPTION 'حسابك مقيد مؤقتاً من الحجوزات النقدية بسبب تكرار عدم الحضور (No-Show). يرجى الدفع إلكترونياً لتأكيد الحجز.';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
