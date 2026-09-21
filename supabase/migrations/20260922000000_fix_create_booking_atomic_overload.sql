-- Fix: Drop obsolete 20-parameter overload of create_booking_atomic
-- Prevents PostgREST RPC ambiguity error: "Could not choose the best candidate function between..."
-- The canonical 21-parameter function with optional idempotency key (p_idempotency_key) remains as the single RPC entrypoint.

DROP FUNCTION IF EXISTS public.create_booking_atomic(
    p_stadium_id text,
    p_user_id text,
    p_owner_id text,
    p_start_time timestamp with time zone,
    p_end_time timestamp with time zone,
    p_booking_type text,
    p_total_price numeric,
    p_stadium_name text,
    p_stadium_image_url text,
    p_is_private boolean,
    p_rent_ball boolean,
    p_needs_deposit boolean,
    p_deposit_amount numeric,
    p_payment_method text,
    p_payment_status text,
    p_player_team_id text,
    p_player_team_name text,
    p_opponent_team_id text,
    p_opponent_team_name text,
    p_platform_fee numeric
);

-- Ensure explicit permissions on the canonical 21-parameter function
GRANT EXECUTE ON FUNCTION public.create_booking_atomic(
    text, text, text, timestamp with time zone, timestamp with time zone,
    text, numeric, text, text, boolean, boolean, boolean, numeric,
    text, text, text, text, text, text, numeric, text
) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.create_booking_atomic(
    text, text, text, timestamp with time zone, timestamp with time zone,
    text, numeric, text, text, boolean, boolean, boolean, numeric,
    text, text, text, text, text, text, numeric, text
) FROM anon, public;
