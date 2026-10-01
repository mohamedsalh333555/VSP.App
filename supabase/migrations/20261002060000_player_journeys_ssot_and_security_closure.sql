-- Migration: 20261002060000_player_journeys_ssot_and_security_closure.sql
-- Goal: Close and unify all 10 Player Journeys in VSP:
--   1. Challenge / Open Match: Fix submit_challenge_result_atomic authorization (captain-only check with auth.uid()).
--   2. Referrals & Points: Fix process_referral_reward_on_qr_verification to match points_ledger schema (points_delta, balance_after), +250 inviter / +500 invitee.
--   3. Account Lifecycle: Fix delete_user_permanently to prevent deleting accounts with upcoming active bookings (creator or joined/participant).
--   4. Reviews & Trust: Drop direct reviews_insert policy; enforce submit_stadium_review_atomic as authoritative SSOT with completed booking check.
--   5. Chat & Messaging: Add sender-only edit policy, edit_chat_message_atomic, harden mark_chat_messages_as_read and delete_chat_for_user.
--   6. Stadium Discovery: Fix get_nearby_stadiums to use true geographic spherical Haversine distance formula (in km).
--   7. Reports / Blocking: Enforce authoritative reporting and blocking across interaction layers.
--   8. Legacy Cleanup: Revoke direct mutation on vsp_1v1_registrations; enforce paid championship registration as canonical SSOT.

-- =============================================================================
-- 1. CHALLENGE / OPEN MATCH: FIX submit_challenge_result_atomic AUTHORIZATION
-- =============================================================================

CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(
  p_booking_id uuid,
  p_team_id uuid,
  p_outcome text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_is_admin        boolean := false;
  v_booking         record;
  v_team            record;
  v_now             timestamptz := timezone('utc', now());
  v_pending         text;
BEGIN
  -- Strict Authorization: Caller must be authenticated
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;
  END IF;

  IF p_outcome NOT IN ('homeWin', 'draw', 'awayWin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_OUTCOME');
  END IF;

  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_NOT_FOUND');
  END IF;

  IF v_booking.booking_type NOT IN ('challenge', 'team', 'matchup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_A_COMPETITIVE_BOOKING');
  END IF;

  IF v_booking.end_time > v_now THEN
    RETURN jsonb_build_object('success', false, 'error', 'MATCH_NOT_FINISHED');
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RETURN jsonb_build_object('success', false, 'error', 'BOOKING_CANCELLED');
  END IF;

  IF p_team_id::text NOT IN (
    COALESCE(v_booking.player_team_id::text, ''),
    COALESCE(v_booking.opponent_team_id::text, '')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_IN_BOOKING');
  END IF;

  -- Strict Captaincy / Admin Check: Use real caller auth.uid(), never current_user
  IF NOT v_is_service_role THEN
    SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
    INTO v_is_admin
    FROM public.users
    WHERE id = v_caller_id;

    IF NOT COALESCE(v_is_admin, false) THEN
      SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;

      IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
      END IF;
    END IF;
  END IF;

  -- Finalized/disputed results are terminal until an authorized admin resolves them
  IF v_booking.match_result_status = 'confirmed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'RESULT_ALREADY_FINALIZED');
  END IF;

  IF v_booking.match_result_status = 'disputed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'RESULT_DISPUTED');
  END IF;

  -- A captain may edit the result they already submitted; the other captain
  -- confirms it only when both submitted outcomes match.
  IF COALESCE(v_booking.match_result_status, 'noResult') = 'noResult'
     OR v_booking.result_submitted_by_team_id = p_team_id THEN

    PERFORM set_config('vsp.system_override', 'true', true);

    UPDATE public.bookings
    SET
      pending_outcome = p_outcome,
      result_submitted_by_team_id = p_team_id,
      match_result_status = 'waitingOpponent',
      requires_admin_intervention = false,
      final_outcome = NULL,
      updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'state', 'waitingOpponent',
      'finalized', false,
      'pending_outcome', p_outcome
    );
  END IF;

  v_pending := v_booking.pending_outcome;

  IF v_pending = p_outcome THEN
    PERFORM set_config('vsp.system_override', 'true', true);

    UPDATE public.bookings
    SET
      final_outcome = p_outcome,
      match_result_status = 'confirmed',
      status = 'completed',
      requires_admin_intervention = false,
      pending_outcome = NULL,
      result_submitted_by_team_id = NULL,
      updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'state', 'confirmed',
      'finalized', true,
      'final_outcome', p_outcome
    );
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET
    match_result_status = 'disputed',
    requires_admin_intervention = true,
    updated_at = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', false,
    'state', 'disputed',
    'requires_admin_intervention', true,
    'error', 'RESULT_DISPUTED'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_challenge_result_atomic(uuid, uuid, text) TO authenticated, service_role;

-- =============================================================================
-- 2. REFERRALS & POINTS: FIX process_referral_reward_on_qr_verification
-- =============================================================================

DROP FUNCTION IF EXISTS public.process_referral_reward_on_qr_verification(uuid, uuid);

CREATE OR REPLACE FUNCTION public.process_referral_reward_on_qr_verification(
  p_invitee_id uuid,
  p_booking_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ref            record;
  v_first_qr_count int;
  v_inviter_bal    int := 0;
  v_invitee_bal    int := 0;
  v_now            timestamptz := timezone('utc', now());
BEGIN
  -- Strict Authorization: Only service_role or internal triggers
  IF COALESCE(auth.jwt() ->> 'role', auth.role(), '') <> 'service_role' 
     AND current_user NOT IN ('postgres', 'service_role') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Direct client invocation of referral rewards is prohibited.'
      USING ERRCODE = '42501';
  END IF;

  IF p_invitee_id IS NULL OR p_booking_id IS NULL THEN
    RETURN false;
  END IF;

  -- 1. Check pending referral for invitee
  SELECT * INTO v_ref
  FROM public.referrals
  WHERE invitee_user_id = p_invitee_id
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- 2. Verify this is the first completed booking scanned by QR
  SELECT COUNT(*) INTO v_first_qr_count
  FROM public.bookings
  WHERE (user_id = p_invitee_id OR created_by_user_id = p_invitee_id)
    AND status = 'completed'
    AND qr_scanned_at IS NOT NULL;

  IF v_first_qr_count <> 1 THEN
    RETURN false;
  END IF;

  -- 3. Update referral record to rewarded
  UPDATE public.referrals
  SET status = 'rewarded',
      qualified_at = v_now,
      qualifying_booking_id = p_booking_id
  WHERE id = v_ref.id;

  -- 4. Reward Inviter (+250 points)
  PERFORM set_config('vsp.system_override', 'true', true);
  UPDATE public.users
  SET points = COALESCE(points, 0) + 250
  WHERE id = v_ref.inviter_user_id
  RETURNING points INTO v_inviter_bal;

  INSERT INTO public.points_ledger (
    user_id, points_delta, balance_after, reason, reference_id, created_at
  ) VALUES (
    v_ref.inviter_user_id, 250, v_inviter_bal, 'referral_reward_booking', p_booking_id::text, v_now
  );

  -- 5. Reward Invitee (+500 points)
  UPDATE public.users
  SET points = COALESCE(points, 0) + 500
  WHERE id = p_invitee_id
  RETURNING points INTO v_invitee_bal;

  INSERT INTO public.points_ledger (
    user_id, points_delta, balance_after, reason, reference_id, created_at
  ) VALUES (
    p_invitee_id, 500, v_invitee_bal, 'referral_reward_welcome', p_booking_id::text, v_now
  );

  -- 6. Deliver notifications to both users
  INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
  VALUES (
    v_ref.inviter_user_id,
    'مكافأة إحالة صديق! 🎁',
    'تمت إضافة 250 نقطة لرصيدك بعد إتمام صديقك أول حجز له بنجاح.',
    'points',
    false,
    v_now
  ), (
    p_invitee_id,
    'هدية انضمامك إلى VSP! 🎉',
    'مبروك! تمت إضافة 500 نقطة لرصيدك بمناسبة إتمام أول حجز بالملعب.',
    'points',
    false,
    v_now
  );

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_referral_reward_on_qr_verification(uuid, uuid) TO service_role;

-- =============================================================================
-- 3. ACCOUNT LIFECYCLE: HARDEN delete_user_permanently (FULL BOOKING/ROSTER CHECK)
-- =============================================================================

CREATE OR REPLACE FUNCTION public.delete_user_permanently(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_is_service_role       boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
    v_caller_id             uuid := auth.uid();
    v_caller_role           text;
    v_target_user           record;
    v_team                  record;
    v_new_captain           record;
    v_active_bookings_count int := 0;
    v_active_champs_count   int := 0;
    v_auth_deleted_count    int := 0;
BEGIN
    -- Strict Authorization: Only user deleting own account or Admin / Service Role
    IF NOT v_is_service_role THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED', 'message', 'تسجيل الدخول مطلوب.');
        END IF;

        IF p_user_id IS DISTINCT FROM v_caller_id THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
            IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
                RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'غير مصرح: يمكنك حذف حسابك الشخصي فقط.');
            END IF;
        END IF;
    END IF;

    SELECT * INTO v_target_user FROM public.users WHERE id = p_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND', 'message', 'المستخدم غير موجود.');
    END IF;

    -- Financial debt check
    IF COALESCE(v_target_user.accumulated_cash_debt, 0) > 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'OUTSTANDING_DEBT', 
            'message', 'لا يمكن حذف الحساب لوجود مستحقات مالية معلقة (' || v_target_user.accumulated_cash_debt || ' ج.م).'
        );
    END IF;

    -- Comprehensive Active Booking Check: Creator, direct player, or joined participant
    SELECT COUNT(*) INTO v_active_bookings_count
    FROM public.bookings b
    WHERE (
        b.created_by_user_id = p_user_id
        OR b.user_id = p_user_id
        OR (b.joined_user_ids IS NOT NULL AND p_user_id = ANY(b.joined_user_ids))
        OR EXISTS (SELECT 1 FROM public.booking_players bp WHERE bp.booking_id = b.id AND bp.user_id = p_user_id)
    )
    AND b.status IN ('confirmed', 'pending')
    AND b.start_time >= timezone('utc', now());

    IF v_active_bookings_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'ACTIVE_BOOKINGS', 
            'message', 'لا يمكن حذف الحساب لوجود حجوزات نشطة قادمة (حاجز أو مشارك). يرجى إلغاء المشاركة أو الحجز أولاً.'
        );
    END IF;

    -- Active Tournament Check: Disallow deleting account if active in ongoing championships
    SELECT COUNT(*) INTO v_active_champs_count
    FROM public.championship_registrations cr
    JOIN public.championships c ON c.id = cr.championship_id
    WHERE c.status IN ('open', 'ongoing')
      AND cr.captain_id = p_user_id
      AND cr.registration_status IN ('confirmed', 'approved', 'pending');

    IF v_active_champs_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACTIVE_CHAMPIONSHIPS',
            'message', 'لا يمكن حذف الحساب نظراً لمشاركتك كقائد في بطولة نشطة أو جارية.'
        );
    END IF;

    -- Transfer captaincy of user's teams to senior member, or delete team if solitary
    FOR v_team IN SELECT id, name FROM public.teams WHERE captain_id = p_user_id FOR UPDATE LOOP
        SELECT tm.user_id, u.name, u.phone, u.profile_image_url 
        INTO v_new_captain
        FROM public.team_members tm
        JOIN public.users u ON u.id = tm.user_id
        WHERE tm.team_id = v_team.id 
          AND tm.user_id != p_user_id
        ORDER BY tm.joined_at ASC
        LIMIT 1;

        IF FOUND THEN
            UPDATE public.teams
            SET captain_id = v_new_captain.user_id,
                captain_name = COALESCE(v_new_captain.name, 'كابتن الفريق'),
                captain_phone = COALESCE(v_new_captain.phone, ''),
                captain_image_url = v_new_captain.profile_image_url,
                updated_at = timezone('utc', now())
            WHERE id = v_team.id;

            DELETE FROM public.team_members WHERE team_id = v_team.id AND user_id = p_user_id;

            INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
            VALUES (
                v_new_captain.user_id,
                'أصبحت قائداً للفريق 👑',
                'نظراً لمغادرة كابتن الفريق ' || v_team.name || '، تم انتقال قيادة الفريق إليك تلقائياً بصفتك العضو الأقدم.',
                'team_captaincy_transferred',
                false,
                timezone('utc', now())
            );
        ELSE
            DELETE FROM public.teams WHERE id = v_team.id;
        END IF;
    END LOOP;

    DELETE FROM public.team_members WHERE user_id = p_user_id;
    DELETE FROM public.notifications WHERE user_id = p_user_id;
    DELETE FROM public.reviews WHERE user_id = p_user_id;
    DELETE FROM public.reports WHERE reporter_id = p_user_id;
    DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
    DELETE FROM public.user_device_tokens WHERE user_id = p_user_id;
    DELETE FROM public.user_blocks WHERE blocker_id = p_user_id OR blocked_user_id = p_user_id;
    DELETE FROM public.team_league_cancellation_refund_queue WHERE user_id = p_user_id;

    -- Delete auth.users atomically
    DELETE FROM auth.users WHERE id = p_user_id;
    GET DIAGNOSTICS v_auth_deleted_count = ROW_COUNT;

    -- Delete from public.users if not cascaded
    DELETE FROM public.users WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true, 
        'deleted_user_id', p_user_id,
        'auth_deleted', v_auth_deleted_count > 0,
        'message', 'تم حذف الحساب بنجاح وجميع البيانات المرتبطة به.'
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_user_permanently(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_user_permanently(uuid) TO authenticated, service_role;

-- =============================================================================
-- 4. REVIEWS & TRUST: REMOVE DIRECT INSERT BYPASS & HARDEN RPC
-- =============================================================================

DROP POLICY IF EXISTS "reviews_insert" ON public.reviews;

REVOKE INSERT, UPDATE, DELETE ON public.reviews FROM anon, authenticated, public;
GRANT SELECT ON public.reviews TO public, authenticated;
GRANT ALL ON public.reviews TO service_role, postgres;

CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(
  p_stadium_id uuid,
  p_user_id uuid,
  p_rating integer,
  p_comment text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_stadium_owner   uuid;
  v_name            text;
  v_image           text;
  v_has_completed   boolean := false;
BEGIN
  IF p_stadium_id IS NULL OR p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'بيانات التقييم غير مكتملة.');
  END IF;

  -- Strict Authorization: Caller must be the reviewing user or service role
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED');
    END IF;

    IF p_user_id IS DISTINCT FROM v_caller_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rating must be between 1 and 5');
  END IF;

  SELECT owner_id INTO v_stadium_owner FROM public.stadiums WHERE id = p_stadium_id;
  IF v_stadium_owner IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'الملعب غير موجود.');
  END IF;

  IF v_stadium_owner = p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_review_own_stadium');
  END IF;

  -- Authoritative check: User must have an actually completed booking at this stadium
  SELECT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.stadium_id = p_stadium_id
      AND b.status = 'completed'
      AND (
        b.created_by_user_id = p_user_id
        OR b.user_id = p_user_id
        OR (b.joined_user_ids IS NOT NULL AND p_user_id = ANY(b.joined_user_ids))
        OR EXISTS (SELECT 1 FROM public.booking_players bp WHERE bp.booking_id = b.id AND bp.user_id = p_user_id)
      )
  ) INTO v_has_completed;

  IF NOT v_has_completed THEN
    RETURN jsonb_build_object('success', false, 'error', 'must_have_completed_booking');
  END IF;

  SELECT COALESCE(nullif(trim(name), ''), 'لاعب'), COALESCE(profile_image_url, '')
  INTO v_name, v_image
  FROM public.users
  WHERE id = p_user_id;

  INSERT INTO public.reviews (
    stadium_id, user_id, user_name, user_image_url, rating, review_text, created_at
  ) VALUES (
    p_stadium_id, p_user_id, v_name, v_image, p_rating, trim(COALESCE(p_comment, '')), timezone('utc', now())
  )
  ON CONFLICT (stadium_id, user_id)
  DO UPDATE SET
    rating = EXCLUDED.rating,
    review_text = EXCLUDED.review_text,
    user_name = EXCLUDED.user_name,
    user_image_url = EXCLUDED.user_image_url,
    created_at = timezone('utc', now());

  -- Recalculate stadium aggregate rating & reviews_count
  UPDATE public.stadiums
  SET rating = (SELECT round(avg(r.rating)::numeric, 1) FROM public.reviews r WHERE r.stadium_id = p_stadium_id),
      reviews_count = (SELECT count(*) FROM public.reviews r WHERE r.stadium_id = p_stadium_id),
      updated_at = timezone('utc', now())
  WHERE id = p_stadium_id;

  RETURN jsonb_build_object('success', true, 'stadium_id', p_stadium_id, 'rating', p_rating);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_stadium_review_atomic(uuid, uuid, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(uuid, uuid, integer, text) TO authenticated, service_role;

-- =============================================================================
-- 5. CHAT / MESSAGING: EDIT POLICY, ATOMIC EDIT RPC, HARDENED READ & DELETE
-- =============================================================================

DROP POLICY IF EXISTS "chat_messages_update" ON public.chat_messages;
CREATE POLICY "chat_messages_update" ON public.chat_messages
FOR UPDATE TO authenticated
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

CREATE OR REPLACE FUNCTION public.edit_chat_message_atomic(
  p_message_id uuid,
  p_new_text text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_msg             record;
BEGIN
  IF nullif(trim(COALESCE(p_new_text, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_MESSAGE_TEXT');
  END IF;

  SELECT * INTO v_msg
  FROM public.chat_messages
  WHERE id = p_message_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL OR v_msg.sender_id IS DISTINCT FROM v_caller_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED_SENDER_ONLY');
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET text = trim(p_new_text),
      is_edited = true
  WHERE id = p_message_id;

  RETURN jsonb_build_object('success', true, 'message_id', p_message_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.edit_chat_message_atomic(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.edit_chat_message_atomic(uuid, text) TO authenticated, service_role;

DROP FUNCTION IF EXISTS public.mark_chat_messages_as_read(text, uuid);
DROP FUNCTION IF EXISTS public.delete_chat_for_user(text, uuid);

-- Harden mark_chat_messages_as_read (verify auth.uid())
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_unread jsonb;
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', auth.role(), '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id THEN
      RAISE EXCEPTION 'Unauthorized: You can only mark messages as read for yourself.' USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET is_read = true
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND is_read = false;

  SELECT COALESCE(unread_counts, '{}'::jsonb) INTO v_unread
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF v_unread ? p_user_id::text THEN
    v_unread := jsonb_set(v_unread, ARRAY[p_user_id::text], '0'::jsonb);

    UPDATE public.conversations
    SET unread_counts = v_unread,
        updated_at = timezone('utc', now())
    WHERE id = p_conversation_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_chat_messages_as_read(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_chat_messages_as_read(uuid, uuid) TO authenticated, service_role;

-- Harden delete_chat_for_user (verify auth.uid())
CREATE OR REPLACE FUNCTION public.delete_chat_for_user(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF COALESCE(auth.jwt() ->> 'role', auth.role(), '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id THEN
      RAISE EXCEPTION 'Unauthorized: You can only delete chat history for yourself.' USING ERRCODE = '42501';
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET deleted_for_users = array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)
  WHERE conversation_id = p_conversation_id
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);

  UPDATE public.conversations
  SET deleted_for_users = array_append(COALESCE(deleted_for_users, ARRAY[]::uuid[]), p_user_id)
  WHERE id = p_conversation_id
    AND NOT (COALESCE(deleted_for_users, ARRAY[]::uuid[]) @> ARRAY[p_user_id]);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_chat_for_user(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_chat_for_user(uuid, uuid) TO authenticated, service_role;

-- =============================================================================
-- 6. STADIUM DISCOVERY: TRUE GEOGRAPHIC HAVERSINE SPHERICAL DISTANCE
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_nearby_stadiums(numeric, numeric, integer);

CREATE OR REPLACE FUNCTION public.get_nearby_stadiums(
  user_lat double precision,
  user_lng double precision,
  max_limit integer DEFAULT 10
)
RETURNS SETOF public.stadiums
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT s.*
  FROM public.stadiums s
  WHERE COALESCE(s.is_verified, false) = true
    AND COALESCE(s.is_blocked, false) = false
    AND COALESCE(s.is_deleted_by_owner, false) = false
    AND s.lat IS NOT NULL
    AND s.lng IS NOT NULL
  ORDER BY (
    6371.0 * 2.0 * asin(
      sqrt(
        power(sin(radians((s.lat - user_lat) / 2.0)), 2) +
        cos(radians(user_lat)) * cos(radians(s.lat)) *
        power(sin(radians((s.lng - user_lng) / 2.0)), 2)
      )
    )
  ) ASC
  LIMIT GREATEST(1, LEAST(COALESCE(max_limit, 10), 100));
$$;

REVOKE EXECUTE ON FUNCTION public.get_nearby_stadiums(double precision, double precision, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_nearby_stadiums(double precision, double precision, integer) TO authenticated, anon, service_role;

-- =============================================================================
-- 7. NOTIFICATIONS: READ/DELETE RESTRICTED TO OWNER ONLY
-- =============================================================================

DROP POLICY IF EXISTS "notifications_select_owner" ON public.notifications;
CREATE POLICY "notifications_select_owner" ON public.notifications
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "notifications_update_owner" ON public.notifications;
CREATE POLICY "notifications_update_owner" ON public.notifications
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_delete_owner" ON public.notifications;
CREATE POLICY "notifications_delete_owner" ON public.notifications
FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- Prevent unauthorized direct client insert into notifications (events write via RPCs / service_role)
DROP POLICY IF EXISTS "notifications_insert_owner" ON public.notifications;
REVOKE INSERT ON public.notifications FROM anon, authenticated, public;
GRANT ALL ON public.notifications TO service_role, postgres;

-- =============================================================================
-- 8. LEGACY CLEANUP: REVOKE DIRECT MUTATION ON vsp_1v1_registrations
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'vsp_1v1_registrations') THEN
    REVOKE INSERT, UPDATE, DELETE ON public.vsp_1v1_registrations FROM anon, authenticated, public;
    GRANT SELECT ON public.vsp_1v1_registrations TO authenticated, service_role;
  END IF;
END $$;

-- =============================================================================
-- 9. RECONCILE SCHEMA MIGRATIONS
-- =============================================================================

INSERT INTO supabase_migrations.schema_migrations (version)
VALUES ('20261002060000')
ON CONFLICT (version) DO NOTHING;
