-- ==============================================================================
-- VSP PARALLEL CLOSURE: TRACK B (Player Identity) & TRACK C (1v1 Journey)
-- Migration: 20261001270000_player_and_1v1_journey_ssot.sql
-- ==============================================================================

-- 1️⃣ TRACK B: Harden User Sensitive Fields Trigger
-- Protects debt, limit, debt blocking, and points against direct client tampering
CREATE OR REPLACE FUNCTION public.trg_fn_protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_is_admin BOOLEAN := false;
BEGIN
    IF current_user IN ('postgres', 'service_role')
       OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        RETURN NEW;
    END IF;

    IF auth.uid() IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        v_is_admin := COALESCE(v_caller_role IN ('admin', 'co_founder', 'cofounder', 'super_admin'), false);
    END IF;

    IF v_is_admin THEN 
        RETURN NEW; 
    END IF;

    IF OLD.role IS DISTINCT FROM NEW.role
       OR OLD.email IS DISTINCT FROM NEW.email
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
       OR OLD.is_debt_blocked IS DISTINCT FROM NEW.is_debt_blocked
       OR OLD.points IS DISTINCT FROM NEW.points THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Account security, financial state, and lifecycle fields are server-authoritative.'
          USING errcode = '42501', detail = 'UNAUTHORIZED_USER_SENSITIVE_UPDATE';
    END IF;

    RETURN NEW;
END;
$$;


-- 2️⃣ TRACK B: Safe Permanent Account Deletion with Captaincy Cascade & Debt/Booking Guards
CREATE OR REPLACE FUNCTION public.delete_user_permanently(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_role TEXT;
    v_target_user RECORD;
    v_team RECORD;
    v_new_captain RECORD;
    v_active_bookings_count INT := 0;
BEGIN
    -- 🔒 Verification: Caller must be self or admin/service_role
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (p_user_id IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'غير مصرح: يمكنك حذف حسابك الشخصي فقط.');
            END IF;
        END IF;
    END IF;

    -- Fetch user details
    SELECT * INTO v_target_user FROM public.users WHERE id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND', 'message', 'المستخدم غير موجود.');
    END IF;

    -- 🛡️ Guard 1: Financial Debt
    IF COALESCE(v_target_user.accumulated_cash_debt, 0) > 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'OUTSTANDING_DEBT', 
            'message', 'لا يمكن حذف الحساب لوجود مستحقات مالية معلقة (' || v_target_user.accumulated_cash_debt || ' ج.م).'
        );
    END IF;

    -- 🛡️ Guard 2: Active or Upcoming Bookings
    SELECT COUNT(*) INTO v_active_bookings_count
    FROM public.bookings
    WHERE created_by_user_id = p_user_id
      AND status IN ('confirmed', 'pending')
      AND start_time >= timezone('utc', now());

    IF v_active_bookings_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'ACTIVE_BOOKINGS', 
            'message', 'لا يمكن حذف الحساب لوجود حجوزات نشطة قادمة. يرجى إلغاء الحجوزات أولاً.'
        );
    END IF;

    -- 🛡️ Guard 3: Team Captaincy Preservation & Safe Cascade
    -- Iterate over all teams where user is captain
    FOR v_team IN SELECT id, name FROM public.teams WHERE captain_id = p_user_id FOR UPDATE LOOP
        -- Check if there are other members
        SELECT tm.user_id, u.name, u.phone, u.profile_image_url 
        INTO v_new_captain
        FROM public.team_members tm
        JOIN public.users u ON u.id = tm.user_id
        WHERE tm.team_id = v_team.id 
          AND tm.user_id != p_user_id
        ORDER BY tm.joined_at ASC
        LIMIT 1;

        IF FOUND THEN
            -- Reassign captaincy to oldest member
            UPDATE public.teams
            SET captain_id = v_new_captain.user_id,
                captain_name = COALESCE(v_new_captain.name, 'كابتن الفريق'),
                captain_phone = COALESCE(v_new_captain.phone, ''),
                captain_image_url = v_new_captain.profile_image_url,
                updated_at = timezone('utc', now())
            WHERE id = v_team.id;

            -- Remove user from team members
            DELETE FROM public.team_members WHERE team_id = v_team.id AND user_id = p_user_id;

            -- Notify new captain
            INSERT INTO public.notifications (user_id, title, body, type, created_at)
            VALUES (
                v_new_captain.user_id,
                'أصبحت قائداً للفريق 👑',
                'نظراً لمغادرة كابتن الفريق ' || v_team.name || '، تم انتقال قيادة الفريق إليك تلقائياً بصفتك العضو الأقدم.',
                'team_captaincy_transferred',
                timezone('utc', now())
            );
        ELSE
            -- Sole member team: Disband cleanly
            DELETE FROM public.teams WHERE id = v_team.id;
        END IF;
    END LOOP;

    -- Clean up regular team memberships
    DELETE FROM public.team_members WHERE user_id = p_user_id;

    -- Clean up related non-critical user records
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.reviews WHERE user_id = p_user_id;
    DELETE FROM public.reports WHERE reporter_id = p_user_id;
    DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
    DELETE FROM public.user_device_tokens WHERE user_id = p_user_id;
    DELETE FROM public.user_blocks WHERE blocker_id = p_user_id OR blocked_user_id = p_user_id;
    DELETE FROM public.team_league_cancellation_refund_queue WHERE user_id = p_user_id;

    -- Delete user record from public.users
    DELETE FROM public.users WHERE id = p_user_id;

    -- Delete user from auth.users safely
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        'success', true, 
        'deleted_user_id', p_user_id,
        'message', 'تم حذف الحساب بنجاح وجميع البيانات المرتبطة به.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_permanently(UUID) TO authenticated, service_role;


-- 3️⃣ TRACK C: Server-Authoritative 1v1 Registration with Blocked Checks
CREATE OR REPLACE FUNCTION public.join_1v1_tournament_atomic(
    p_tournament_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_champ RECORD;
    v_order RECORD;
    v_user RECORD;
    v_current_count INT;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED', 'message', 'يجب تسجيل الدخول أولاً للمشاركة.');
    END IF;

    -- Check caller user status
    SELECT * INTO v_user
    FROM public.users
    WHERE id = v_caller_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND', 'message', 'المستخدم غير موجود.');
    END IF;

    IF COALESCE(v_user.is_blocked, false) = true THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED', 'message', 'الحساب محظور من المشاركة في البطولات.');
    END IF;

    IF COALESCE(v_user.is_debt_blocked, false) = true THEN
        RETURN jsonb_build_object('success', false, 'error', 'DEBT_BLOCKED', 'message', 'الحساب موقوف لتجاوز حد المديونية.');
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ
    FROM public.vsp_1v1_tournaments
    WHERE id = p_tournament_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'TOURNAMENT_NOT_FOUND', 'message', 'البطولة غير موجودة.');
    END IF;

    IF v_champ.status <> 'registration_open' THEN
        RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'message', 'التسجيل في هذه البطولة مغلق حالياً.');
    END IF;

    IF EXISTS(
        SELECT 1 FROM public.vsp_1v1_tournament_players
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id AND payment_status = 'paid'
    ) THEN
        RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
    END IF;

    SELECT count(*)::INT INTO v_current_count
    FROM public.vsp_1v1_tournament_players
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'CAPACITY_REACHED', 'message', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Official 1v1 tournaments are paid: a registration can only be created
    -- when a server-created Paymob order is already paid.
    SELECT * INTO v_order
    FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id
      AND user_id = v_caller_id
      AND payment_status = 'paid'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF COALESCE(v_champ.entry_fee, 0) > 0 AND NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'PAYMENT_REQUIRED',
            'message', 'يجب إتمام الدفع الإلكتروني قبل تسجيلك في البطولة.'
        );
    END IF;

    INSERT INTO public.vsp_1v1_tournament_players(
        tournament_id, user_id, player_name, avatar_url, tackles, goals, skills,
        registered_at, payment_status, payment_order_id, paid_amount
    )
    VALUES(
        p_tournament_id,
        v_caller_id,
        COALESCE(NULLIF(TRIM(v_user.name), ''), 'لاعب'),
        COALESCE(v_user.profile_image_url, ''),
        0, 0, 0, timezone('utc', now()),
        CASE WHEN v_order.id IS NOT NULL THEN 'paid' ELSE 'unpaid' END,
        v_order.id,
        COALESCE(v_order.amount, 0)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسجيلك في البطولة بنجاح! حظاً موفقاً.',
        'player_count', v_current_count + 1,
        'payment_status', CASE WHEN v_order.id IS NOT NULL THEN 'paid' ELSE 'unpaid' END
    );
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_1v1_tournament_atomic(UUID) TO authenticated, service_role;


-- 4️⃣ TRACK C: Confirm 1v1 Payment with Blocked Guard
CREATE OR REPLACE FUNCTION public.confirm_1v1_payment_atomic(
    p_order_reference TEXT,
    p_paymob_transaction_id TEXT,
    p_gross_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_champ RECORD;
    v_current_count INT;
    v_user RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_gross NUMERIC;
BEGIN
    -- Strict authorization: strictly service_role or postgres internal caller ONLY
    IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'غير مصرح: يتم تأكيد الطلبات عبر الـ Webhook فقط.');
    END IF;

    -- Strict actual gross validation: mandatory from gateway
    IF p_gross_amount IS NULL OR p_gross_amount <= 0 THEN
        RAISE EXCEPTION 'مبلغ الدفع الإجمالي الفعلي مطلوب';
    END IF;
    v_gross := round(p_gross_amount, 2);

    -- Lock order row
    SELECT * INTO v_order 
    FROM public.vsp_1v1_tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND', 'message', 'طلب الدفع غير موجود.');
    END IF;

    IF v_order.payment_status = 'paid' THEN
        RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'message', 'تم تأكيد الطلب مسبقاً.');
    END IF;

    -- Verify user is not blocked
    SELECT name, profile_image_url, is_blocked, is_debt_blocked INTO v_user 
    FROM public.users 
    WHERE id = v_order.user_id;

    IF COALESCE(v_user.is_blocked, false) = true OR COALESCE(v_user.is_debt_blocked, false) = true THEN
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_user_blocked',
            paymob_transaction_id = p_paymob_transaction_id,
            gross_amount = v_gross,
            updated_at = v_now
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'user_blocked', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'amount', v_order.amount,
            'gross_amount', v_gross,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'حساب اللاعب محظور. تم إرسال أمر استرداد المبلغ.'
        );
    END IF;

    -- Lock tournament row
    SELECT * INTO v_champ 
    FROM public.vsp_1v1_tournaments 
    WHERE id = v_order.tournament_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'TOURNAMENT_NOT_FOUND', 'message', 'البطولة المرتبطة بالطلب غير موجودة.');
    END IF;

    -- Count active paid players
    SELECT COUNT(*) INTO v_current_count 
    FROM public.vsp_1v1_tournament_players 
    WHERE tournament_id = v_order.tournament_id AND payment_status = 'paid';

    -- Race condition capacity check
    IF v_champ.status != 'registration_open' OR v_current_count >= v_champ.target_player_count THEN
        UPDATE public.vsp_1v1_tournament_orders
        SET payment_status = 'failed_over_capacity',
            paymob_transaction_id = p_paymob_transaction_id,
            gross_amount = v_gross,
            updated_at = v_now
        WHERE id = v_order.id;

        RETURN jsonb_build_object(
            'success', false,
            'capacity_exceeded', true,
            'needs_refund', true,
            'order_id', v_order.id,
            'order_reference', p_order_reference,
            'user_id', v_order.user_id,
            'tournament_id', v_order.tournament_id,
            'amount', v_order.amount,
            'gross_amount', v_gross,
            'paymob_transaction_id', p_paymob_transaction_id,
            'message', 'اكتملت مقاعد البطولة أثناء إتمام الدفع. تم إرسال أمر استرداد فوري لبوابة Paymob.'
        );
    END IF;

    -- Confirm payment & register player with immutable gross_amount
    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'paid',
        paymob_transaction_id = p_paymob_transaction_id,
        gross_amount = v_gross,
        updated_at = v_now
    WHERE id = v_order.id;

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

    UPDATE public.vsp_1v1_tournaments
    SET prize_pool = COALESCE(prize_pool, 0) + v_order.amount,
        updated_at = v_now
    WHERE id = v_order.tournament_id;

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
            'paymob_transaction_id', p_paymob_transaction_id,
            'gross_amount', v_gross
        ),
        v_now
    );

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
        'gross_amount', v_gross,
        'new_prize_pool', COALESCE(v_champ.prize_pool, 0) + v_order.amount
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_1v1_payment_atomic(TEXT, TEXT, NUMERIC) TO authenticated, service_role;
