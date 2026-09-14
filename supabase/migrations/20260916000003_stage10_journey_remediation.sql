-- ============================================================================
-- VSP STAGE 10: END-TO-END JOURNEY REMEDIATION & TYPE INTEGRITY
-- File: 20260916000003_stage10_journey_remediation.sql
-- ============================================================================

-- 1. EXTEND bookings_payment_status_check TO ALLOW 'failed'
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_payment_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_payment_status_check 
  CHECK (payment_status = ANY (ARRAY['pending'::text, 'unpaid'::text, 'paid'::text, 'partially_paid'::text, 'refunded'::text, 'failed'::text]));

-- 2. FIX request_join_public_match TYPE CASTING & INTEGRITY
CREATE OR REPLACE FUNCTION public.request_join_public_match(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
    v_booking_uuid UUID;
    v_user_uuid UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Parse & validate UUIDs
    BEGIN
        v_booking_uuid := p_booking_id::UUID;
        v_user_uuid := p_user_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'INVALID_UUID_FORMAT: Invalid booking or user identifier'
            USING ERRCODE = '22P02';
    END;

    -- 2. Verify caller is joining for their own account
    IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
        IF auth.uid() IS NULL OR auth.uid() != v_user_uuid THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: You can only join public matches for your own account.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 3. Fetch and lock booking
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

    IF v_booking.status = 'completed' THEN
        RAISE EXCEPTION 'match_already_completed';
    END IF;

    -- 4. Check user blocked status
    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
    IF v_user_blocked IS TRUE THEN
        RAISE EXCEPTION 'user_blocked';
    END IF;

    -- 5. Capacity check
    v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
    IF COALESCE(v_booking.current_players, 0) >= v_capacity THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    -- 6. Check if already joined
    IF v_user_uuid = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[])) OR v_booking.created_by_user_id = v_user_uuid THEN
        RAISE EXCEPTION 'already_joined';
    END IF;

    -- 7. Conflict detection against active bookings for this user
    SELECT COUNT(*) INTO v_user_conflict
    FROM public.bookings
    WHERE status != 'cancelled'
      AND id != v_booking_uuid
      AND (created_by_user_id = v_user_uuid OR v_user_uuid = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[])))
      AND start_time < v_booking.end_time
      AND end_time > v_booking.start_time;

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    -- 8. Atomically append user to joined_user_ids (as uuid[]) and update player count
    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
        current_players = COALESCE(current_players, 0) + 1,
        updated_at = v_now
    WHERE id = v_booking_uuid;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'current_players', COALESCE(v_booking.current_players, 0) + 1
    );
END;
$$;


-- 3. DROP REDUNDANT DUPLICATE TRIGGER ON BOOKINGS
DROP TRIGGER IF EXISTS trg_match_completed ON public.bookings;
