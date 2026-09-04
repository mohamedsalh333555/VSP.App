-- Migration: 202609050001_phase1_harden_critical_functions_and_auth.sql
-- Description: Fix IDOR vulnerabilities, add strict caller verification, and fix payout column name runtime error.

-- 1. cancel_booking_with_refund_atomic
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
    v_tx_id UUID;
    v_caller_role TEXT;
BEGIN
    SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 🔒 التحقق الصارم من هوية المستدعي (Authorization Check)
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً لإلغاء الحجز.');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (auth.uid() != v_booking.created_by_user_id)
           AND (auth.uid() != v_booking.owner_id)
           AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: يمكنك فقط إلغاء الحجوزات الخاصة بك أو بملاعبك.');
        END IF;
    END IF;

    -- Check 2-hour cutoff rule for players
    IF v_booking.start_time <= (timezone('utc'::text, now()) + INTERVAL '2 hours') THEN
        RETURN jsonb_build_object('success', false, 'message', 'لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من ساعتين وفقاً للائحة.');
    END IF;

    -- Calculate refund amount if online payment was made
    IF v_booking.payment_status = 'paid' OR v_booking.payment_status = 'confirmed' THEN
        v_refund_amount := COALESCE(v_booking.deposit_amount, v_booking.total_price, 0.00);
    END IF;

    -- Update booking status to cancelled
    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = CASE WHEN v_refund_amount > 0 THEN 'refunded' ELSE payment_status END,
        cancellation_reason = p_reason,
        cancelled_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_booking_id;

    -- Record refund transaction if applicable
    IF v_refund_amount > 0 THEN
        INSERT INTO public.transactions (
            user_id,
            booking_id,
            amount,
            type,
            status,
            payment_method,
            description,
            created_at
        ) VALUES (
            v_booking.created_by_user_id,
            p_booking_id,
            v_refund_amount,
            'refund',
            'completed',
            COALESCE(v_booking.payment_method, 'online'),
            'استرداد تلقائي لإلغاء الحجز قبل المهلة المحددة: ' || p_reason,
            timezone('utc'::text, now())
        ) RETURNING id INTO v_tx_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم إلغاء الحجز بنجاح.',
        'refund_amount', v_refund_amount,
        'booking_id', p_booking_id
    );
END;
$function$;

-- 2. owner_lock_slot_atomic
CREATE OR REPLACE FUNCTION public.owner_lock_slot_atomic(
    p_owner_id uuid,
    p_stadium_id uuid,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_reason text DEFAULT 'صيانة دورية'::text
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
    v_caller_role TEXT;
BEGIN
    SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Stadium not found');
    END IF;

    -- 🔒 التحقق الصارم من ملكية الملعب
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
        END IF;

        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();

        IF (v_stadium.owner_id != auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You can only lock slots for your own stadiums.');
        END IF;
    END IF;

    PERFORM 1 FROM public.stadiums WHERE id = p_stadium_id FOR UPDATE;

    SELECT COUNT(*) INTO v_overlap_count
    FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status != 'cancelled'
      AND p_start_time < end_time
      AND p_end_time > start_time;

    IF v_overlap_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Slot already booked or overlaps with an active match');
    END IF;

    INSERT INTO public.bookings (
        stadium_id,
        owner_id,
        created_by_user_id,
        start_time,
        end_time,
        booking_type,
        player_team_name,
        notes,
        total_price,
        deposit_paid,
        is_deposit_paid,
        is_paid,
        payment_status,
        payment_method,
        status,
        current_players,
        is_private,
        rent_ball,
        created_at,
        updated_at
    ) VALUES (
        p_stadium_id,
        v_stadium.owner_id,
        COALESCE(auth.uid(), p_owner_id),
        p_start_time,
        p_end_time,
        'maintenance',
        'قفل صيانة المالك',
        p_reason,
        0,
        0,
        false,
        true,
        'paid',
        'owner_block',
        'confirmed',
        0,
        true,
        false,
        v_now,
        v_now
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'message', 'Slot locked successfully'
    );
END;
$function$;

-- 3. request_owner_payout_settlement_atomic (Fix column name crash v_owner.full_name -> v_owner.name)
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
AS $function$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- التحقق من صلاحيات وهوية المالك
    IF auth.uid() IS NULL OR (auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout amount must be greater than zero');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout destination details are required');
    END IF;

    -- جلب بيانات المالك
    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Owner account not found');
    END IF;

    -- التحقق من عدم وجود طلب تسوية قيد المراجعة حالياً لمنع التكرار
    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل من قبل الإدارة. يرجى الانتظار حتى اكتماله.');
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
        p_amount,
        COALESCE(p_method, 'instapay'),
        p_destination,
        'pending',
        v_now,
        v_now
    ) RETURNING id INTO v_settlement_id;

    -- إدراج حركة قيد معلقة في جدول المعاملات
    INSERT INTO public.transactions (
        user_id,
        amount,
        type,
        payment_method,
        metadata,
        created_at
    ) VALUES (
        p_owner_id,
        p_amount,
        'payout_pending',
        COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, '')
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'message', 'تم تقديم طلب تسوية الأرباح بنجاح وجارٍ مراجعته من الإدارة المالية.'
    );
END;
$function$;

-- 4. delete_chat_for_user (IDOR protection)
CREATE OR REPLACE FUNCTION public.delete_chat_for_user(p_conversation_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != p_user_id) THEN
      RAISE EXCEPTION 'Unauthorized: You can only delete chat history for yourself.';
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
$function$;

-- 5. mark_chat_messages_as_read (IDOR protection)
CREATE OR REPLACE FUNCTION public.mark_chat_messages_as_read(p_conversation_id uuid, p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_unread jsonb;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != p_user_id) THEN
      RAISE EXCEPTION 'Unauthorized: You can only mark messages as read for yourself.';
    END IF;
  END IF;

  UPDATE public.chat_messages
  SET is_read = TRUE
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND is_read = FALSE;

  SELECT COALESCE(unread_counts, '{}'::jsonb) INTO v_unread
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF v_unread ? p_user_id::text THEN
    v_unread := jsonb_set(v_unread, ARRAY[p_user_id::text], '0'::jsonb);

    UPDATE public.conversations
    SET unread_counts = v_unread,
        updated_at = NOW()
    WHERE id = p_conversation_id;
  END IF;
END;
$function$;

-- 6. leave_public_match_atomic (IDOR protection)
CREATE OR REPLACE FUNCTION public.leave_public_match_atomic(p_booking_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking bookings%ROWTYPE;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != p_user_id) THEN
      RAISE EXCEPTION 'Unauthorized: You can only leave matches on your own behalf.';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF NOT (p_user_id = ANY(v_booking.joined_user_ids)) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  UPDATE bookings
  SET 
    current_players = GREATEST(0, current_players - 1),
    joined_user_ids = array_remove(joined_user_ids, p_user_id),
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$;

-- 7. update_host_spots_atomic (Caller must be host or owner)
CREATE OR REPLACE FUNCTION public.update_host_spots_atomic(p_booking_id uuid, p_user_id uuid, p_new_host_spots integer)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking bookings%ROWTYPE;
  v_joined_count integer;
  v_capacity integer;
BEGIN
  SELECT * INTO v_booking FROM bookings WHERE id = p_booking_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
      RAISE EXCEPTION 'Unauthorized: Only the host or owner can modify spots';
    END IF;
  END IF;

  v_joined_count := coalesce(cardinality(v_booking.joined_user_ids), 0);
  v_capacity := coalesce(v_booking.total_field_capacity, 10);

  IF (v_joined_count + p_new_host_spots) > v_capacity THEN
    RAISE EXCEPTION 'Exceeds total stadium capacity';
  END IF;

  UPDATE bookings
  SET 
    current_players = v_joined_count + p_new_host_spots,
    updated_at = timezone('utc'::text, now())
  WHERE id = p_booking_id;

  RETURN true;
END;
$function$;

-- 8. accept_join_request (Caller must be host or owner)
CREATE OR REPLACE FUNCTION public.accept_join_request(p_booking_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_user_uuid UUID;
BEGIN
    IF p_user_id ~ '^[0-9a-fA-F-]{36}$' THEN
        v_user_uuid := p_user_id::uuid;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'معرف المستخدم غير صالح.');
    END IF;

    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    -- 🔒 التحقق من أن المتصل هو منشئ التحدي أو صاحب الملعب
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: منشئ المباراة أو مالك الملعب فقط يمكنهما قبول اللاعبين.');
        END IF;
    END IF;

    IF v_booking.current_players >= COALESCE(v_booking.total_field_capacity, 10) THEN
        RETURN jsonb_build_object('success', false, 'message', 'اكتمل العدد المطلوب للمباراة بالفعل.');
    END IF;

    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids, ARRAY[]::text[]), p_user_id),
        joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'تم قبول اللاعب بنجاح.');
END;
$function$;

-- 9. reject_join_request (Caller must be host or owner)
CREATE OR REPLACE FUNCTION public.reject_join_request(p_booking_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المباراة غير موجودة.');
    END IF;

    -- 🔒 التحقق من الصلاحية
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF auth.uid() IS NULL OR (auth.uid() != v_booking.created_by_user_id AND auth.uid() != v_booking.owner_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح.');
        END IF;
    END IF;

    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'تم رفض الطلب بنجاح.');
END;
$function$;
