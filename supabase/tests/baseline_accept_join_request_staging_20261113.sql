-- Read-only captured deployed function definition on staging 2026-11-13.
-- This intentionally vulnerable baseline is used ONLY in ephemeral CI DB.
-- NEVER deploy this fixture.
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
