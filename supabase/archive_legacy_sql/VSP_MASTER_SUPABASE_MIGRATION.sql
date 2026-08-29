-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — MASTER FIXED SUPABASE MIGRATION (100% TYPE-SAFE)
-- ==============================================================================

-- 0. Championships Approval Gate
ALTER TABLE public.championships
ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;

UPDATE public.championships c
SET is_approved = TRUE
WHERE EXISTS (
  SELECT 1 FROM public.users u
  WHERE u.id::text = c.owner_id::text
  AND u.verification_status = 'approved'
);

-- ==============================================================================
-- 0.5. VSP OWNER SUBSCRIPTION PLANS & PLATFORM FEE
-- ==============================================================================

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS subscription_plan TEXT DEFAULT 'free_trial',
ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS total_platform_fees NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS p2p_instapay TEXT,
ADD COLUMN IF NOT EXISTS p2p_vodafone TEXT,
ADD COLUMN IF NOT EXISTS p2p_bank TEXT,
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS no_show_count INT DEFAULT 0;

ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS platform_fee NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_paid NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_deposit_paid BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS needs_deposit BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS payment_transaction_id TEXT,
ADD COLUMN IF NOT EXISTS paymob_txn_id TEXT,
ADD COLUMN IF NOT EXISTS paymob_order_id TEXT,
ADD COLUMN IF NOT EXISTS webhook_processed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS webhook_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'EGP',
ADD COLUMN IF NOT EXISTS host_name TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS host_avatar_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS player_team_logo_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS opponent_team_logo_url TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS player_phone TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS unread_counts JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS last_message TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS deleted_for_users TEXT[] DEFAULT ARRAY[]::text[],
ADD COLUMN IF NOT EXISTS pending_user_ids TEXT[] DEFAULT ARRAY[]::text[],
ADD COLUMN IF NOT EXISTS is_official_match BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_dispute_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS dispute_photo_url TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS reschedule_status TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS proposed_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS proposed_end_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS emergency_cancel_status TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS emergency_reason TEXT,
ADD COLUMN IF NOT EXISTS emergency_downtime_hours INT,
ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS refund_amount NUMERIC DEFAULT 0;

ALTER TABLE public.stadiums
ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS needs_deposit BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_deleted_by_owner BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS opening_time TEXT DEFAULT '04:00 PM',
ADD COLUMN IF NOT EXISTS closing_time TEXT DEFAULT '03:00 AM',
ADD COLUMN IF NOT EXISTS images TEXT[] DEFAULT ARRAY[]::text[],
ADD COLUMN IF NOT EXISTS maintenance_until TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS maintenance_reason TEXT,
ADD COLUMN IF NOT EXISTS last_emergency_closure_at TIMESTAMPTZ;

ALTER TABLE public.tournament_matches 
ADD COLUMN IF NOT EXISTS goal_details JSONB DEFAULT '[]'::jsonb;

-- Initialize trial period for existing owners
UPDATE public.users
SET
  trial_ends_at = COALESCE(created_at, NOW()) + INTERVAL '90 days',
  subscription_plan = 'free_trial'
WHERE role = 'owner'
  AND (subscription_plan IS NULL OR subscription_plan = 'free_trial');

-- Review constraints
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS unique_user_stadium_review;
ALTER TABLE public.reviews ADD CONSTRAINT unique_user_stadium_review UNIQUE (user_id, stadium_id);

-- Drop legacy exclusion constraint on bookings
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_stadium_id_start_time_end_time_excl;

-- =========================================================================
-- 1. DROP ALL CONFLICTING ROUTINE OVERLOADS FIRST
-- =========================================================================
DROP FUNCTION IF EXISTS public.create_booking_atomic(UUID, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, NUMERIC, TEXT, TEXT, UUID, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS public.create_booking_atomic(TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.create_booking_atomic(TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, DOUBLE PRECISION, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, DOUBLE PRECISION, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT);

DROP FUNCTION IF EXISTS public.process_paymob_webhook(TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, JSONB);

DROP FUNCTION IF EXISTS public.request_join_public_match(UUID, UUID);
DROP FUNCTION IF EXISTS public.request_join_public_match(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.request_join_public_match(TEXT, UUID);
DROP FUNCTION IF EXISTS public.request_join_public_match(UUID, TEXT);

DROP FUNCTION IF EXISTS public.accept_join_request(UUID, UUID);
DROP FUNCTION IF EXISTS public.accept_join_request(TEXT, TEXT);

DROP FUNCTION IF EXISTS public.reject_join_request(UUID, UUID);
DROP FUNCTION IF EXISTS public.reject_join_request(TEXT, TEXT);

DROP FUNCTION IF EXISTS public.get_championship_standings(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.global_search(TEXT);
DROP FUNCTION IF EXISTS public.check_team_has_1v1_champion(TEXT);
DROP FUNCTION IF EXISTS public.apply_no_show_penalty(TEXT);
DROP FUNCTION IF EXISTS public.dispute_no_show_with_gps(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.dispute_no_show_with_gps(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS public.dispute_no_show_with_gps(UUID, UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

-- =========================================================================
-- 2. CREATE FUNCTION DEFINITIONS (STRICT CASTING)
-- =========================================================================

-- A. create_booking_atomic
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
    p_stadium_id TEXT,
    p_user_id TEXT,
    p_owner_id TEXT,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_booking_type TEXT,
    p_total_price NUMERIC,
    p_stadium_name TEXT DEFAULT '',
    p_stadium_image_url TEXT DEFAULT '',
    p_is_private BOOLEAN DEFAULT TRUE,
    p_rent_ball BOOLEAN DEFAULT FALSE,
    p_needs_deposit BOOLEAN DEFAULT FALSE,
    p_deposit_amount NUMERIC DEFAULT 0,
    p_payment_method TEXT DEFAULT 'cash',
    p_payment_status TEXT DEFAULT 'pending',
    p_player_team_id TEXT DEFAULT NULL,
    p_player_team_name TEXT DEFAULT NULL,
    p_opponent_team_id TEXT DEFAULT NULL,
    p_opponent_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conflict_count INT;
    v_new_booking_id UUID;
    v_stadium_verified BOOLEAN;
    v_stadium_blocked BOOLEAN;
    v_user_blocked BOOLEAN;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    SELECT is_verified, is_blocked INTO v_stadium_verified, v_stadium_blocked
    FROM public.stadiums WHERE id::text = p_stadium_id;

    IF v_stadium_verified IS NOT TRUE OR v_stadium_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
    END IF;

    SELECT is_blocked INTO v_user_blocked
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع الدعم الفني.');
    END IF;

    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الوقت محجوز بالفعل لمباراة أخرى.');
    END IF;

    INSERT INTO public.bookings (
        stadium_id, user_id, created_by_user_id, owner_id,
        start_time, end_time, booking_type, total_price,
        stadium_name, stadium_image_url, is_private, rent_ball,
        needs_deposit, deposit_amount, deposit_paid,
        payment_method, payment_status, status, is_paid,
        player_team_id, player_team_name, opponent_team_id, opponent_team_name,
        joined_user_ids, created_at, updated_at
    ) VALUES (
        CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
        p_user_id, p_user_id, p_owner_id,
        p_start_time, p_end_time, p_booking_type, p_total_price,
        p_stadium_name, p_stadium_image_url, p_is_private, p_rent_ball,
        p_needs_deposit, p_deposit_amount, CASE WHEN p_payment_status = 'paid' THEN p_deposit_amount ELSE 0 END,
        p_payment_method, p_payment_status,
        CASE WHEN p_payment_status = 'paid' OR p_payment_method = 'cash' THEN 'confirmed' ELSE 'pending' END,
        CASE WHEN p_payment_status = 'paid' THEN TRUE ELSE FALSE END,
        CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
        p_player_team_name,
        CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
        p_opponent_team_name,
        ARRAY[p_user_id], NOW(), NOW()
    )
    RETURNING id INTO v_new_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'message', 'تم تأكيد الحجز بنجاح.'
    );
END;
$$;

-- B. Webhook Logs Table
CREATE TABLE IF NOT EXISTS public.webhook_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL DEFAULT 'paymob',
  event_type TEXT NOT NULL,
  txn_id TEXT,
  order_id TEXT,
  booking_id UUID,
  payload JSONB NOT NULL,
  signature_verified BOOLEAN DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'received',
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- C. process_paymob_webhook (Explicit UUID Cast)
CREATE OR REPLACE FUNCTION public.process_paymob_webhook(
  p_booking_id TEXT,
  p_txn_id TEXT,
  p_order_id TEXT,
  p_success BOOLEAN,
  p_signature_verified BOOLEAN,
  p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_clean_id TEXT;
  v_existing_booking RECORD;
  v_already_processed BOOLEAN;
BEGIN
  v_clean_id := split_part(p_booking_id, '_', 1);

  INSERT INTO public.webhook_logs (
    provider, event_type, txn_id, order_id, booking_id, payload, signature_verified, status
  )
  VALUES (
    'paymob',
    CASE WHEN p_success THEN 'payment_success' ELSE 'payment_failed' END,
    p_txn_id, p_order_id, 
    CASE WHEN v_clean_id ~ '^[0-9a-fA-F-]{36}$' THEN v_clean_id::uuid ELSE NULL END, 
    p_payload, p_signature_verified,
    CASE WHEN p_signature_verified THEN 'processed' ELSE 'unverified' END
  );

  IF p_txn_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bookings
      WHERE paymob_txn_id = p_txn_id
        AND status = 'confirmed'
    ) INTO v_already_processed;

    IF v_already_processed THEN
      RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'duplicate_webhook_ignored',
        'booking_id', v_clean_id
      );
    END IF;
  END IF;

  SELECT * INTO v_existing_booking
  FROM public.bookings
  WHERE id::text = v_clean_id
  FOR UPDATE;

  IF v_existing_booking.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', 'booking_not_found',
      'message', 'No booking found matching the provided ID.'
    );
  END IF;

  IF p_success THEN
    UPDATE public.bookings
    SET
      status = 'confirmed',
      is_paid = TRUE,
      payment_status = 'paid',
      payment_method = 'paymob_card',
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_processed_at = NOW(),
      webhook_verified = p_signature_verified,
      updated_at = NOW()
    WHERE id::text = v_clean_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'confirmed',
      'booking_id', v_clean_id
    );
  ELSE
    UPDATE public.bookings
    SET
      status = 'cancelled',
      is_paid = FALSE,
      payment_status = 'failed',
      paymob_txn_id = p_txn_id,
      paymob_order_id = p_order_id,
      webhook_processed_at = NOW(),
      webhook_verified = p_signature_verified,
      notes = COALESCE(notes, '') || E'\n[SYSTEM: Payment declined via Paymob Webhook]',
      updated_at = NOW()
    WHERE id::text = v_clean_id;

    RETURN jsonb_build_object(
      'success', TRUE,
      'status', 'cancelled',
      'booking_id', v_clean_id
    );
  END IF;
END;
$$;

-- D. request_join_public_match
CREATE OR REPLACE FUNCTION public.request_join_public_match(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
    v_user_conflict INT;
    v_user_blocked BOOLEAN;
    v_capacity INT;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'match_cancelled';
    END IF;

    SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id::text = p_user_id;
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
    WHERE status = 'confirmed'
      AND (user_id::text = p_user_id OR created_by_user_id::text = p_user_id OR p_user_id = ANY(joined_user_ids::text[]))
      AND id::text != p_booking_id
      AND (
          (v_booking.start_time >= start_time AND v_booking.start_time < end_time) OR
          (v_booking.end_time > start_time AND v_booking.end_time <= end_time) OR
          (v_booking.start_time <= start_time AND v_booking.end_time >= end_time)
      );

    IF v_user_conflict > 0 THEN
        RAISE EXCEPTION 'time_conflict';
    END IF;

    UPDATE public.bookings
    SET joined_user_ids = array_append(COALESCE(joined_user_ids::text[], ARRAY[]::text[]), p_user_id),
        pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Joined match instantly.'
    );
END;
$$;

-- E. accept_join_request
CREATE OR REPLACE FUNCTION public.accept_join_request(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.bookings
    WHERE id::text = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'match_not_found';
    END IF;

    IF v_booking.current_players >= COALESCE(v_booking.total_field_capacity, 10) THEN
        RAISE EXCEPTION 'match_is_full';
    END IF;

    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        joined_user_ids = array_append(COALESCE(joined_user_ids::text[], ARRAY[]::text[]), p_user_id),
        current_players = current_players + 1,
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Player accepted successfully.');
END;
$$;

-- F. reject_join_request
CREATE OR REPLACE FUNCTION public.reject_join_request(
    p_booking_id TEXT,
    p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.bookings
    SET pending_user_ids = array_remove(COALESCE(pending_user_ids::text[], ARRAY[]::text[]), p_user_id),
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Request rejected.');
END;
$$;

-- G. get_championship_standings
CREATE OR REPLACE FUNCTION public.get_championship_standings(
    p_championship_id TEXT,
    p_group_name TEXT DEFAULT NULL
)
RETURNS TABLE (
    team_id TEXT,
    team_name TEXT,
    played INT,
    won INT,
    drawn INT,
    lost INT,
    goals_for INT,
    goals_against INT,
    goal_difference INT,
    points INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH matches_data AS (
        SELECT 
            home_team_id AS t_id,
            home_team_name AS t_name,
            home_score AS gf,
            away_score AS ga,
            CASE 
                WHEN home_score > away_score THEN 3
                WHEN home_score = away_score THEN 1
                ELSE 0 
            END AS pts,
            CASE WHEN home_score > away_score THEN 1 ELSE 0 END AS w,
            CASE WHEN home_score = away_score THEN 1 ELSE 0 END AS d,
            CASE WHEN home_score < away_score THEN 1 ELSE 0 END AS l
        FROM public.tournament_matches
        WHERE championship_id::text = p_championship_id
          AND status = 'completed'
          AND (p_group_name IS NULL OR group_name = p_group_name)

        UNION ALL

        SELECT 
            away_team_id AS t_id,
            away_team_name AS t_name,
            away_score AS gf,
            home_score AS ga,
            CASE 
                WHEN away_score > home_score THEN 3
                WHEN away_score = home_score THEN 1
                ELSE 0 
            END AS pts,
            CASE WHEN away_score > home_score THEN 1 ELSE 0 END AS w,
            CASE WHEN away_score = home_score THEN 1 ELSE 0 END AS d,
            CASE WHEN away_score < home_score THEN 1 ELSE 0 END AS l
        FROM public.tournament_matches
        WHERE championship_id::text = p_championship_id
          AND status = 'completed'
          AND (p_group_name IS NULL OR group_name = p_group_name)
    )
    SELECT 
        m.t_id::text AS team_id,
        MAX(m.t_name)::text AS team_name,
        COUNT(*)::int AS played,
        SUM(m.w)::int AS won,
        SUM(m.d)::int AS drawn,
        SUM(m.l)::int AS lost,
        SUM(m.gf)::int AS goals_for,
        SUM(m.ga)::int AS goals_against,
        (SUM(m.gf) - SUM(m.ga))::int AS goal_difference,
        SUM(m.pts)::int AS points
    FROM matches_data m
    WHERE m.t_id IS NOT NULL
    GROUP BY m.t_id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC;
END;
$$;

-- H. global_search
CREATE OR REPLACE FUNCTION public.global_search(search_term TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stadiums JSONB;
    v_teams JSONB;
    v_championships JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]'::jsonb) INTO v_stadiums
    FROM public.stadiums s
    WHERE s.name ILIKE '%' || search_term || '%' OR s.location ILIKE '%' || search_term || '%';

    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_teams
    FROM public.teams t
    WHERE t.name ILIKE '%' || search_term || '%';

    SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO v_championships
    FROM public.championships c
    WHERE c.name ILIKE '%' || search_term || '%';

    RETURN jsonb_build_object(
        'stadiums', v_stadiums,
        'teams', v_teams,
        'championships', v_championships
    );
END;
$$;

-- I. check_team_has_1v1_champion
CREATE OR REPLACE FUNCTION public.check_team_has_1v1_champion(p_team_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_has_champion BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.team_members tm
        JOIN public.vsp_1vs1_players p ON p.id::text = tm.user_id::text
        WHERE tm.team_id::text = p_team_id
          AND p.rank = 1
    ) INTO v_has_champion;

    RETURN v_has_champion;
END;
$$;

-- J. dispute_no_show_with_gps
CREATE OR REPLACE FUNCTION public.dispute_no_show_with_gps(
    p_booking_id TEXT,
    p_player_id TEXT,
    p_lat NUMERIC,
    p_lng NUMERIC,
    p_accuracy NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_end_time TIMESTAMPTZ;
    v_stadium_lat DOUBLE PRECISION;
    v_stadium_lng DOUBLE PRECISION;
    v_dist_meters DOUBLE PRECISION;
    v_diff_minutes INT;
BEGIN
    SELECT b.end_time, s.lat, s.lng
    INTO v_end_time, v_stadium_lat, v_stadium_lng
    FROM public.bookings b
    JOIN public.stadiums s ON s.id::text = b.stadium_id::text
    WHERE b.id::text = p_booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'booking_not_found';
    END IF;

    v_diff_minutes := EXTRACT(EPOCH FROM (NOW() - v_end_time)) / 60;
    IF v_diff_minutes > 60 THEN
        RAISE EXCEPTION 'dispute_window_expired';
    END IF;

    IF p_accuracy > 50 THEN
        RAISE EXCEPTION 'gps_accuracy_too_low';
    END IF;

    v_dist_meters := 6371000 * acos(
        LEAST(1.0, GREATEST(-1.0,
            cos(radians(v_stadium_lat)) * cos(radians(p_lat::double precision)) *
            cos(radians(p_lng::double precision) - radians(v_stadium_lng)) +
            sin(radians(v_stadium_lat)) * sin(radians(p_lat::double precision))
        ))
    );

    IF v_dist_meters > (150.0 + p_accuracy::double precision) THEN
        RAISE EXCEPTION 'not_at_stadium';
    END IF;

    UPDATE public.users
    SET no_show_count = GREATEST(0, COALESCE(no_show_count, 1) - 1),
        is_blocked = FALSE,
        updated_at = NOW()
    WHERE id::text = p_player_id;

    UPDATE public.bookings
    SET notes = COALESCE(notes, '') || ' [DISPUTE_APPROVED_GPS: ' || round(v_dist_meters::numeric) || 'm]',
        updated_at = NOW()
    WHERE id::text = p_booking_id;

    RETURN TRUE;
END;
$$;

-- K. auto_reconcile_past_bookings
CREATE OR REPLACE FUNCTION public.auto_reconcile_past_bookings()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.bookings
  SET
    is_paid = true,
    payment_status = 'paid',
    status = 'completed',
    updated_at = NOW()
  WHERE
    end_time < NOW()
    AND status != 'cancelled'
    AND (is_paid = false OR status != 'completed');
END;
$$;

-- L. calculate_elo_on_match_completion (Trigger)
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    home_elo INT;
    away_elo INT;
    new_home_elo INT;
    new_away_elo INT;
    outcome FLOAT;
BEGIN
    IF NEW.status = 'completed' 
       AND OLD.status != 'completed' 
       AND NEW.booking_type = 'challenge' 
       AND NEW.final_outcome IS NOT NULL 
       AND COALESCE(NEW.elo_processed, false) = false THEN
        
        SELECT COALESCE(points, 1000) INTO home_elo FROM public.teams WHERE id::text = NEW.player_team_id::text;
        SELECT COALESCE(points, 1000) INTO away_elo FROM public.teams WHERE id::text = NEW.opponent_team_id::text;

        IF home_elo IS NOT NULL AND away_elo IS NOT NULL THEN
            IF NEW.final_outcome = 'homeWin' THEN outcome := 1.0;
            ELSIF NEW.final_outcome = 'draw' THEN outcome := 0.5;
            ELSE outcome := 0.0;
            END IF;

            new_home_elo := round(home_elo + 32 * (outcome - (1 / (1 + power(10, (away_elo - home_elo)::float / 400)))));
            new_away_elo := round(away_elo + 32 * ((1 - outcome) - (1 / (1 + power(10, (home_elo - away_elo)::float / 400)))));

            UPDATE public.teams 
            SET points = GREATEST(0, new_home_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                trend = (CASE WHEN outcome > 0.0 THEN 'up' ELSE 'down' END)
            WHERE id::text = NEW.player_team_id::text;

            UPDATE public.teams 
            SET points = GREATEST(0, new_away_elo), 
                matches_played = matches_played + 1,
                wins = wins + (CASE WHEN outcome = 0.0 THEN 1 ELSE 0 END),
                draws = draws + (CASE WHEN outcome = 0.5 THEN 1 ELSE 0 END),
                losses = losses + (CASE WHEN outcome = 1.0 THEN 1 ELSE 0 END),
                trend = (CASE WHEN outcome < 1.0 THEN 'up' ELSE 'down' END)
            WHERE id::text = NEW.opponent_team_id::text;

            NEW.elo_processed := true;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_elo ON public.bookings;
CREATE TRIGGER trg_calculate_elo
BEFORE UPDATE OF status, final_outcome ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.calculate_elo_on_match_completion();

-- =========================================================================
-- 3. TYPE-SAFE ROW LEVEL SECURITY POLICIES (100% EXPLICIT TEXT CASTS)
-- =========================================================================

ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stadiums ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.championships ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.tournament_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.reviews ENABLE ROW LEVEL SECURITY;

-- Public Select
DROP POLICY IF EXISTS "Public can view stadiums" ON public.stadiums;
CREATE POLICY "Public can view stadiums" ON public.stadiums FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view championships" ON public.championships;
CREATE POLICY "Public can view championships" ON public.championships FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public teams read access" ON public.teams;
CREATE POLICY "Public teams read access" ON public.teams FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public team members read access" ON public.team_members;
CREATE POLICY "Public team members read access" ON public.team_members FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view tournament matches" ON public.tournament_matches;
CREATE POLICY "Public can view tournament matches" ON public.tournament_matches FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public can view reviews" ON public.reviews;
CREATE POLICY "Public can view reviews" ON public.reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can read own and public profile" ON public.users;
CREATE POLICY "Users can read own and public profile" ON public.users FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update only their own profile" ON public.users;
CREATE POLICY "Users can update only their own profile" ON public.users FOR UPDATE 
USING (auth.uid()::text = id::text) 
WITH CHECK (auth.uid()::text = id::text);

-- Bookings Policies (TYPE-SAFE FIX)
DROP POLICY IF EXISTS "Users can view bookings they are part of or public" ON public.bookings;
CREATE POLICY "Users can view bookings they are part of or public" ON public.bookings FOR SELECT 
USING (
  auth.uid()::text = user_id::text OR 
  auth.uid()::text = owner_id::text OR 
  auth.uid()::text = created_by_user_id::text OR 
  is_private = false OR 
  auth.uid()::text = ANY(COALESCE(joined_user_ids::text[], ARRAY[]::text[]))
);

DROP POLICY IF EXISTS "Users can insert their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can insert bookings" ON public.bookings;
CREATE POLICY "Users can insert bookings" ON public.bookings FOR INSERT 
WITH CHECK (
  auth.uid() IS NOT NULL
);

DROP POLICY IF EXISTS "Users and Owners can update relevant bookings" ON public.bookings;
DROP POLICY IF EXISTS "Participants can update their booking" ON public.bookings;
CREATE POLICY "Participants can update their booking" ON public.bookings FOR UPDATE 
USING (
  auth.uid()::text = user_id::text OR 
  auth.uid()::text = owner_id::text OR 
  auth.uid()::text = created_by_user_id::text
);

DROP POLICY IF EXISTS "Users and Owners can delete relevant bookings" ON public.bookings;
CREATE POLICY "Users and Owners can delete relevant bookings" ON public.bookings FOR DELETE 
USING (
  auth.uid()::text = user_id::text OR 
  auth.uid()::text = created_by_user_id::text OR 
  auth.uid()::text = owner_id::text
);

-- Chat Messages (TYPE-SAFE FIX)
DROP POLICY IF EXISTS "Participants can read chat messages" ON public.chat_messages;
CREATE POLICY "Participants can read chat messages" ON public.chat_messages FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.bookings 
    WHERE bookings.id::text = chat_messages.booking_id::text 
    AND (
      bookings.user_id::text = auth.uid()::text OR 
      bookings.owner_id::text = auth.uid()::text OR 
      bookings.created_by_user_id::text = auth.uid()::text OR
      auth.uid()::text = ANY(COALESCE(bookings.joined_user_ids::text[], ARRAY[]::text[]))
    )
  )
);

DROP POLICY IF EXISTS "Participants can send chat messages" ON public.chat_messages;
CREATE POLICY "Participants can send chat messages" ON public.chat_messages FOR INSERT 
WITH CHECK (auth.uid()::text = sender_id::text);

-- Notifications
DROP POLICY IF EXISTS "Users can only read own notifications" ON public.notifications;
CREATE POLICY "Users can only read own notifications" ON public.notifications FOR SELECT 
USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE 
USING (auth.uid()::text = user_id::text);

NOTIFY pgrst, 'reload schema';
