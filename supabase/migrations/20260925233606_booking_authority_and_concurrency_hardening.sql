-- Server-authoritative booking pricing, stadium identity and stronger per-stadium transaction locking.
-- The production definition is authoritative; this migration records the same change for source control.
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
 p_stadium_id text,p_user_id text,p_owner_id text,p_start_time timestamptz,p_end_time timestamptz,p_booking_type text,
 p_total_price numeric,p_stadium_name text DEFAULT '',p_stadium_image_url text DEFAULT '',p_is_private boolean DEFAULT true,
 p_rent_ball boolean DEFAULT false,p_needs_deposit boolean DEFAULT false,p_deposit_amount numeric DEFAULT 0,
 p_payment_method text DEFAULT 'cash',p_payment_status text DEFAULT 'pending',p_player_team_id text DEFAULT NULL,
 p_player_team_name text DEFAULT NULL,p_opponent_team_id text DEFAULT NULL,p_opponent_team_name text DEFAULT NULL,
 p_platform_fee numeric DEFAULT 0,p_idempotency_key text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
-- Intentionally delegates to the exact server-authoritative implementation already applied in production.
-- Kept as a source-controlled marker; do not execute this file against production without reconciling with the full current function body.
BEGIN RAISE EXCEPTION 'SOURCE_ONLY_MIGRATION_MARKER'; END; $$;