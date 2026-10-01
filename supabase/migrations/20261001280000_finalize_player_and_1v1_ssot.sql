-- ==============================================================================
-- VSP FINAL COHERENCE: TRACK B (Strict Auth Account Deletion) & TRACK C (1v1 Paid-Only SSOT)
-- Migration: 20261001280000_finalize_player_and_1v1_ssot.sql
-- ==============================================================================

-- 1️⃣ TRACK B: Strict Atomic User Deletion (No Half-Deleted Accounts)
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
    v_auth_deleted_count INT := 0;
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

    -- 🔒 Strict Atomic Deletion: Delete from auth.users WITHOUT swallowing errors
    -- Any failure here will abort and rollback the entire transaction!
    DELETE FROM auth.users WHERE id = p_user_id;
    GET DIAGNOSTICS v_auth_deleted_count = ROW_COUNT;

    -- Delete user record from public.users (in case not cascaded by auth.users)
    DELETE FROM public.users WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true, 
        'deleted_user_id', p_user_id,
        'auth_deleted', v_auth_deleted_count > 0,
        'message', 'تم حذف الحساب بنجاح وجميع البيانات المرتبطة به.'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_user_permanently(UUID) TO authenticated, service_role;


-- 2️⃣ TRACK C: Server-Authoritative 1v1 Registration (Paid-Only SSOT)
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

    -- Idempotency check: Already registered as paid
    IF EXISTS(
        SELECT 1 FROM public.vsp_1v1_tournament_players
        WHERE tournament_id = p_tournament_id AND user_id = v_caller_id AND payment_status = 'paid'
    ) THEN
        RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
    END IF;

    -- Capacity check
    SELECT count(*)::INT INTO v_current_count
    FROM public.vsp_1v1_tournament_players
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid';

    IF v_current_count >= v_champ.target_player_count THEN
        RETURN jsonb_build_object('success', false, 'error', 'CAPACITY_REACHED', 'message', 'عذراً، اكتمل العدد الأقصى للمشاركين في هذه البطولة.');
    END IF;

    -- Strict Paid-Only SSOT: Official 1v1 tournament registration requires a confirmed server-created paid order
    SELECT * INTO v_order
    FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id
      AND user_id = v_caller_id
      AND payment_status = 'paid'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'PAYMENT_REQUIRED',
            'message', 'يجب إتمام الدفع الإلكتروني أولاً للاشتراك في البطولة.'
        );
    END IF;

    -- Register strictly as paid with order linkage
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
        'paid',
        v_order.id,
        COALESCE(v_order.amount, 0)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تسجيلك في البطولة بنجاح! حظاً موفقاً.',
        'player_count', v_current_count + 1,
        'payment_status', 'paid',
        'order_id', v_order.id
    );
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', true, 'already_joined', true, 'message', 'أنت مسجل بالفعل في هذه البطولة.');
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_1v1_tournament_atomic(UUID) TO authenticated, service_role;
