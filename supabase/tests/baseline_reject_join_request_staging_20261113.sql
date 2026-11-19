-- Original staging RPC body captured read-only 2026-11-13.
-- Security-negative test fixture ONLY. NEVER DEPLOY THIS FUNCTION.
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
