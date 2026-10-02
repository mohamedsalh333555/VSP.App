-- =============================================================================
-- Migration: 20261002080000_player_journeys_final_closure_fixes.sql
-- Description: Final Closure Fixes for 10 Player Journeys:
--   1. confirm_tournament_order_atomic authorization hardening (No player self-confirmation)
--   2. Matchup / Head-to-Head SSOT lockdown against direct mutations
--   3. Notifications table lockdown (Revoke direct client INSERTs, consolidate owner policies)
--   4. Unify submit_stadium_review_atomic to single canonical signature (Eliminate overloads)
-- =============================================================================

-- =============================================================================
-- 1. TOURNAMENT PAYMENT AUTHORIZATION: HARDEN confirm_tournament_order_atomic
-- =============================================================================

CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
  p_order_reference text, 
  p_paymob_transaction_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', auth.role(), '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_caller_role     text;
  v_order           RECORD;
  v_champ           RECORD;
  v_joined_count    INT;
  v_roster_id       UUID;
BEGIN
  -- Strict Authorization: Only service_role (e.g. paymob webhook) OR Admin/Co-founder
  -- Classic Security Definer Fix: NEVER use current_user which resolves to 'postgres'
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'تسجيل الدخول مطلوب.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'UNAUTHORIZED_ADMIN_OR_SERVICE_ROLE_ONLY', 
        'message', 'غير مصرح: تأكيد سداد البطولات مقتصر على السيرفر أو إدارة التطبيق فقط.'
      );
    END IF;
  END IF;

  -- Transaction ID is strictly mandatory
  IF p_paymob_transaction_id IS NULL OR trim(p_paymob_transaction_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMOB_TRANSACTION_ID_REQUIRED');
  END IF;

  SELECT * INTO v_order 
  FROM public.tournament_orders 
  WHERE order_reference = p_order_reference 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'tournament_order_not_found');
  END IF;

  -- 1. Idempotent Success
  IF v_order.payment_status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'order_id', v_order.id);
  END IF;

  -- 2. Strict Source Guard: ONLY 'pending' can be confirmed!
  IF v_order.payment_status <> 'pending' THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'invalid_order_status_for_confirmation', 
      'current_status', v_order.payment_status
    );
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = v_order.championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- If championship was cancelled while payment was pending in gateway
  IF v_champ.status = 'cancelled' THEN
    UPDATE public.tournament_orders
    SET payment_status = 'refund_pending',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_pending',
        registration_status = 'cancelled',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending', timezone('utc', now()), timezone('utc', now())
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_cancelled_payment_refunded',
      'needs_refund', true,
      'amount', v_order.gross_amount,
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Capacity & Open Status Check
  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = v_order.championship_id AND registration_status = 'confirmed';

  IF v_champ.status != 'open' OR v_joined_count >= v_champ.max_teams THEN
    UPDATE public.tournament_orders
    SET payment_status = 'failed_over_capacity',
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_pending',
        registration_status = 'rejected',
        notes = 'over_capacity',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending', timezone('utc', now()), timezone('utc', now())
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_full_or_closed_refund_queued',
      'needs_refund', true,
      'amount', v_order.gross_amount,
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Transition to Paid
  UPDATE public.tournament_orders
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      updated_at = timezone('utc', now())
  WHERE id = v_order.id;

  UPDATE public.championship_registrations
  SET registration_status = 'confirmed',
      payment_status = 'paid',
      gross_amount = v_order.gross_amount,
      updated_at = timezone('utc', now())
  WHERE id = v_order.registration_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_order.registration_id, v_order.championship_id, v_order.team_id,
    to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])), timezone('utc', now())
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[]))
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF v_order.player_ids IS NOT NULL AND array_length(v_order.player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(v_order.player_ids);
  END IF;

  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      prize_pool = coalesce(prize_pool, 0) + coalesce(v_order.base_amount, v_order.amount),
      updated_at = timezone('utc', now())
  WHERE id = v_order.championship_id
    AND NOT (v_order.team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  INSERT INTO public.transactions (
    championship_id, user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
  )
  VALUES (
    v_order.championship_id, v_order.captain_user_id, v_order.gross_amount, 'digital', 'paymob', 'completed',
    'رسوم اشتراك في بطولة: ' || v_champ.name,
    jsonb_build_object(
      'order_id', v_order.id,
      'order_reference', v_order.order_reference,
      'paymob_transaction_id', p_paymob_transaction_id,
      'base_amount', v_order.base_amount,
      'platform_fee_amount', v_order.platform_fee_amount,
      'gateway_fee_amount', v_order.gateway_fee_amount,
      'gross_amount', v_order.gross_amount
    ),
    timezone('utc', now()), timezone('utc', now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'payment_status', 'paid',
    'registration_status', 'confirmed',
    'joined_count', v_joined_count + 1
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_tournament_order_atomic(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(text, text) TO authenticated, service_role;

-- =============================================================================
-- 2. MATCHUP / HEAD-TO-HEAD: REVOKE DIRECT MUTATIONS & ENFORCE AUTHORITATIVE RPCS
-- =============================================================================

DROP POLICY IF EXISTS "Server and booking host can manage matchup teams" ON public.matchup_teams;

-- Ensure RLS is active on all matchup tables
ALTER TABLE public.matchup_teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.matchup_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_head_to_head ENABLE ROW LEVEL SECURITY;

-- Revoke direct mutation rights from public / authenticated
REVOKE INSERT, UPDATE, DELETE ON public.matchup_teams FROM anon, authenticated, public;
REVOKE INSERT, UPDATE, DELETE ON public.matchup_results FROM anon, authenticated, public;
REVOKE INSERT, UPDATE, DELETE ON public.team_head_to_head FROM anon, authenticated, public;

-- Keep read permissions
GRANT SELECT ON public.matchup_teams TO authenticated, anon;
GRANT SELECT ON public.matchup_results TO authenticated, anon;
GRANT SELECT ON public.team_head_to_head TO authenticated, anon;

-- Full access to service_role and postgres
GRANT ALL ON public.matchup_teams TO service_role, postgres;
GRANT ALL ON public.matchup_results TO service_role, postgres;
GRANT ALL ON public.team_head_to_head TO service_role, postgres;

CREATE OR REPLACE FUNCTION public.confirm_matchup_atomic(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_teams_count int;
  v_mode text;
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User not authenticated';
  END IF;

  SELECT id, created_by_user_id, user_id, status, matchup_closed_at, start_time, end_time
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found';
  END IF;

  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) <> v_caller_id THEN
    RAISE EXCEPTION 'Forbidden: Only the booking creator can confirm the matchup';
  END IF;

  IF v_booking.matchup_closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Matchup is already closed';
  END IF;

  IF v_booking.status = 'cancelled' THEN
    RAISE EXCEPTION 'Cannot confirm a cancelled booking';
  END IF;

  IF v_booking.end_time <= timezone('utc', now()) THEN
    RAISE EXCEPTION 'Cannot confirm a matchup after the booking has ended';
  END IF;

  SELECT count(*) INTO v_teams_count
  FROM public.matchup_teams
  WHERE booking_id = p_booking_id;

  IF v_teams_count < 2 THEN
    RAISE EXCEPTION 'Cannot confirm matchup: At least 2 teams must be added';
  END IF;

  v_mode := CASE WHEN v_teams_count = 2 THEN 'duo' ELSE 'winner_stays' END;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET matchup_mode = v_mode,
      updated_at = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'teams_count', v_teams_count,
    'matchup_mode', v_mode
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_matchup_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_matchup_atomic(uuid) TO authenticated, service_role;

-- =============================================================================
-- 3. NOTIFICATIONS: REVOKE DIRECT CLIENT INSERTS & UNIFY POLICIES
-- =============================================================================

DROP POLICY IF EXISTS "notifications_insert_secure" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_owner" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_owner" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete_owner" ON public.notifications;
DROP POLICY IF EXISTS "Admins full access" ON public.notifications;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Revoke direct mutation privileges from client
REVOKE INSERT, UPDATE, DELETE ON public.notifications FROM anon, authenticated, public;
GRANT SELECT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role, postgres;

-- Restrict SELECT to notification owner or admin
CREATE POLICY "notifications_select_owner" ON public.notifications
FOR SELECT TO authenticated
USING (user_id = auth.uid() OR is_admin_or_cofounder(auth.uid()));

-- Restrict UPDATE to notification owner (e.g. is_read)
CREATE POLICY "notifications_update_owner" ON public.notifications
FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Restrict DELETE to notification owner or admin
CREATE POLICY "notifications_delete_owner" ON public.notifications
FOR DELETE TO authenticated
USING (user_id = auth.uid() OR is_admin_or_cofounder(auth.uid()));

-- Only Admins/Co-founders can insert directly from client, regular users MUST NOT insert
CREATE POLICY "notifications_insert_admin_only" ON public.notifications
FOR INSERT TO authenticated
WITH CHECK (is_admin_or_cofounder(auth.uid()));

-- =============================================================================
-- 4. REVIEWS: REMOVE COMPETING OVERLOADS & UNIFY INTO SINGLE CANONICAL SIGNATURE
-- =============================================================================

DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(uuid, uuid, integer, text);
DROP FUNCTION IF EXISTS public.submit_stadium_review_atomic(uuid, uuid, text, text, integer, text);

CREATE OR REPLACE FUNCTION public.submit_stadium_review_atomic(
  p_stadium_id uuid,
  p_user_id uuid,
  p_rating integer,
  p_comment text DEFAULT NULL,
  p_user_name text DEFAULT NULL,
  p_user_image_url text DEFAULT NULL
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

  -- Pull canonical identity from public.users with fallback to parameters
  SELECT COALESCE(nullif(trim(name), ''), nullif(trim(p_user_name), ''), 'لاعب'),
         COALESCE(profile_image_url, nullif(trim(p_user_image_url), ''), '')
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

REVOKE ALL ON FUNCTION public.submit_stadium_review_atomic(uuid, uuid, integer, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_stadium_review_atomic(uuid, uuid, integer, text, text, text) TO authenticated, service_role;
