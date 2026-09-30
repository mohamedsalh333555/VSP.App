-- ==============================================================================
-- VSP Regular Championship Master Patch V3.6 (Definitive Sealed Execution Contract)
-- Migration: 20260930235900_vsp_championship_master_v3_6_patch.sql
-- ==============================================================================

-- 1. Helper: calculate_championship_effective_phase
CREATE OR REPLACE FUNCTION public.calculate_championship_effective_phase(p_championship_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_fixtures_count INT := 0;
BEGIN
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  IF NOT FOUND THEN RETURN 'not_found'; END IF;
  
  IF v_champ.status = 'cancelled' THEN RETURN 'cancelled';
  ELSIF v_champ.status = 'completed' THEN RETURN 'completed';
  ELSIF v_champ.status = 'ongoing' THEN RETURN 'ongoing';
  END IF;
  
  IF v_champ.status = 'open' THEN
    SELECT count(*)::INT INTO v_fixtures_count 
    FROM public.tournament_matches 
    WHERE championship_id = p_championship_id;
    
    IF v_champ.registration_locked_at IS NOT NULL AND v_fixtures_count > 0 THEN
      RETURN 'draw_ready';
    ELSIF v_champ.registration_locked_at IS NOT NULL 
       OR (v_champ.registration_closes_at IS NOT NULL AND now() >= v_champ.registration_closes_at)
       OR now() >= v_champ.start_date THEN
      RETURN 'registration_closed';
    ELSIF coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = false THEN
      RETURN 'draft';
    ELSIF coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = true THEN
      RETURN 'pending_approval';
    ELSE
      RETURN 'registration_open';
    END IF;
  END IF;
  
  RETURN 'unknown';
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_championship_effective_phase(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_championship_effective_phase(UUID) TO authenticated, service_role;

-- 2. Lock down calculate_tournament_checkout_amount_atomic
REVOKE ALL ON FUNCTION public.calculate_tournament_checkout_amount_atomic(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_tournament_checkout_amount_atomic(UUID) TO authenticated, service_role;

-- 3. create_championship_atomic with Stadium Maintenance, Overlap & Strict Deadline Checks
CREATE OR REPLACE FUNCTION public.create_championship_atomic(
  p_name TEXT,
  p_stadium_id UUID,
  p_type TEXT,
  p_sport_type TEXT,
  p_entry_fee NUMERIC,
  p_grand_prize NUMERIC,
  p_max_teams INT,
  p_min_players_per_team INT,
  p_max_players_per_team INT,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  p_registration_closes_at TIMESTAMPTZ,
  p_rules TEXT DEFAULT '',
  p_logo_url TEXT DEFAULT '',
  p_currency TEXT DEFAULT 'EGP',
  p_settings JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_id UUID := auth.uid();
  v_caller_role TEXT;
  v_is_admin BOOLEAN := false;
  v_stadium RECORD;
  v_champ_id UUID;
  v_reg_deadline TIMESTAMPTZ;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
  v_is_admin := v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder');

  -- 1. Stadium Validation
  SELECT id, owner_id, is_blocked, is_deleted_by_owner, maintenance_until, governorate, city
  INTO v_stadium
  FROM public.stadiums
  WHERE id = p_stadium_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_not_found');
  END IF;

  IF v_stadium.owner_id != v_caller_id AND NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_stadium_owner');
  END IF;

  IF coalesce(v_stadium.is_blocked, false) = true OR coalesce(v_stadium.is_deleted_by_owner, false) = true THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_not_available');
  END IF;

  -- Maintenance check
  IF v_stadium.maintenance_until IS NOT NULL AND v_stadium.maintenance_until > now() THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'stadium_under_maintenance',
      'maintenance_until', v_stadium.maintenance_until
    );
  END IF;

  -- 2. Parameters Validation
  IF trim(coalesce(p_name, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_name_required');
  END IF;

  IF p_max_teams < 2 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_max_teams');
  END IF;

  IF p_min_players_per_team < 1 OR p_max_players_per_team < p_min_players_per_team THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_player_limits');
  END IF;

  IF coalesce(p_entry_fee, 0) < 0 OR coalesce(p_grand_prize, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_financial_amounts');
  END IF;

  IF p_start_date >= p_end_date THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_championship_dates');
  END IF;

  v_reg_deadline := coalesce(p_registration_closes_at, p_start_date);
  -- Strict validation: Reject if registration closes after start_date
  IF v_reg_deadline > p_start_date THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_registration_deadline');
  END IF;

  -- 3. Stadium Scheduling Overlap Check
  IF EXISTS (
    SELECT 1 FROM public.championships
    WHERE stadium_id = p_stadium_id
      AND status IN ('open', 'ongoing')
      AND (start_date, end_date) OVERLAPS (p_start_date, p_end_date)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'stadium_has_overlapping_championship');
  END IF;

  INSERT INTO public.championships (
    name, stadium_id, owner_id, type, sport_type,
    entry_fee, grand_prize, currency, max_teams,
    min_players_per_team, max_players_per_team,
    start_date, end_date, registration_closes_at,
    rules, logo_url, governorate, status,
    is_approved, creation_fee_paid, settings,
    joined_teams, paid_teams, created_at, updated_at
  )
  VALUES (
    p_name, p_stadium_id, v_caller_id, coalesce(p_type, 'cup'), coalesce(p_sport_type, 'football'),
    round(coalesce(p_entry_fee, 0), 2), round(coalesce(p_grand_prize, 0), 2), coalesce(p_currency, 'EGP'), p_max_teams,
    p_min_players_per_team, p_max_players_per_team,
    p_start_date, p_end_date, v_reg_deadline,
    coalesce(p_rules, ''), coalesce(p_logo_url, ''), coalesce(v_stadium.governorate, ''), 'open',
    v_is_admin, false, coalesce(p_settings, '{}'::jsonb),
    ARRAY[]::TEXT[], ARRAY[]::TEXT[], now(), now()
  )
  RETURNING id INTO v_champ_id;

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', v_champ_id,
    'status', 'open',
    'effective_phase', CASE WHEN v_is_admin THEN 'registration_open' ELSE 'draft' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_championship_atomic(TEXT, UUID, TEXT, TEXT, NUMERIC, NUMERIC, INT, INT, INT, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_championship_atomic(TEXT, UUID, TEXT, TEXT, NUMERIC, NUMERIC, INT, INT, INT, TIMESTAMPTZ, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;

-- 4. join_championship_atomic (Lock-First Atomic Order)
DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID, BOOLEAN, UUID[], TEXT[], NUMERIC);
DROP FUNCTION IF EXISTS public.join_championship_atomic(UUID, UUID, UUID[], TEXT[]);

CREATE OR REPLACE FUNCTION public.join_championship_atomic(
  p_championship_id UUID,
  p_team_id UUID,
  p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
  p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_reg_id UUID;
  v_roster_id UUID;
  v_joined_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- 1. LOCK FIRST: Guarantee atomicity against concurrent mutations
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- 2. Phase Engine Check under Row Lock
  v_phase := public.calculate_championship_effective_phase(p_championship_id);
  IF v_phase != 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'current_phase', v_phase);
  END IF;

  IF coalesce(v_champ.entry_fee, 0) > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMENT_REQUIRED_USE_ORDER');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id AND registration_status = 'confirmed';

  IF v_joined_count >= v_champ.max_teams THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_FULL');
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.full_name, 'phone', v_captain.phone),
    'confirmed', 'exempt', 0.00, 0.00, coalesce(v_champ.currency, 'EGP')
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = 'confirmed',
    payment_status = 'exempt',
    updated_at = now()
  RETURNING id INTO v_reg_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_reg_id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[]))
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      updated_at = now()
  WHERE id = p_championship_id
    AND NOT (p_team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg_id,
    'payment_status', 'exempt',
    'registration_status', 'confirmed'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.join_championship_atomic(UUID, UUID, UUID[], TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, UUID[], TEXT[]) TO authenticated, service_role;

-- 5. create_tournament_order_atomic (Lock-First Order & registration_status = 'pending')
DROP FUNCTION IF EXISTS public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], NUMERIC);
DROP FUNCTION IF EXISTS public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], TEXT);

CREATE OR REPLACE FUNCTION public.create_tournament_order_atomic(
  p_championship_id UUID,
  p_team_id UUID,
  p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
  p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[],
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_joined_count INT;
  v_pricing RECORD;
  v_reg_id UUID;
  v_existing_order RECORD;
  v_order_id UUID;
  v_order_ref TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- 1. LOCK FIRST: Row lock before checking phase
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  -- 2. Phase Engine SSOT Check under Lock
  v_phase := public.calculate_championship_effective_phase(p_championship_id);
  IF v_phase != 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED', 'current_phase', v_phase);
  END IF;

  IF coalesce(v_champ.entry_fee, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'FREE_TOURNAMENT_USE_JOIN');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'team_not_found'); END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id AND registration_status = 'confirmed';

  IF v_joined_count >= v_champ.max_teams THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_FULL');
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  SELECT * INTO v_pricing FROM public.calculate_tournament_checkout_amount_atomic(p_championship_id);

  -- P0 Invariant: registration_status = 'pending' (NOT 'pending_payment')
  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.full_name, 'phone', v_captain.phone),
    'pending', 'pending', v_pricing.base_amount, v_pricing.gross_amount, v_pricing.currency
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = CASE 
      WHEN championship_registrations.registration_status = 'confirmed' THEN championship_registrations.registration_status
      ELSE 'pending'
    END,
    payment_status = CASE
      WHEN championship_registrations.payment_status = 'paid' THEN championship_registrations.payment_status
      ELSE 'pending'
    END,
    updated_at = now()
  RETURNING id INTO v_reg_id;

  -- Idempotency Check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT * INTO v_existing_order
    FROM public.tournament_orders
    WHERE championship_id = p_championship_id
      AND team_id = p_team_id
      AND idempotency_key = p_idempotency_key
      AND payment_status = 'pending';

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'existing_order', true,
        'order_id', v_existing_order.id,
        'order_reference', v_existing_order.order_reference,
        'gross_amount', v_existing_order.gross_amount
      );
    END IF;
  END IF;

  -- Reuse existing pending order if active
  SELECT * INTO v_existing_order
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id
    AND team_id = p_team_id
    AND payment_status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'existing_order', true,
      'order_id', v_existing_order.id,
      'order_reference', v_existing_order.order_reference,
      'gross_amount', v_existing_order.gross_amount
    );
  END IF;

  v_order_ref := 'TOURN_' || substring(replace(gen_random_uuid()::TEXT, '-', ''), 1, 12);

  INSERT INTO public.tournament_orders (
    order_reference, championship_id, team_id, captain_user_id,
    registration_id, idempotency_key, amount, base_amount,
    platform_fee_amount, gateway_fee_amount, gross_amount,
    currency, fee_policy_version, payment_status, player_ids, guest_names,
    created_at, updated_at
  )
  VALUES (
    v_order_ref, p_championship_id, p_team_id, auth.uid(),
    v_reg_id, p_idempotency_key, v_pricing.gross_amount, v_pricing.base_amount,
    v_pricing.platform_fee_amount, v_pricing.gateway_fee_amount, v_pricing.gross_amount,
    v_pricing.currency, v_pricing.fee_policy_version, 'pending',
    coalesce(p_player_ids, ARRAY[]::UUID[]), coalesce(p_guest_names, ARRAY[]::TEXT[]),
    now(), now()
  )
  RETURNING id, order_reference INTO v_order_id, v_order_ref;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_reference', v_order_ref,
    'base_amount', v_pricing.base_amount,
    'platform_fee_amount', v_pricing.platform_fee_amount,
    'gateway_fee_amount', v_pricing.gateway_fee_amount,
    'gross_amount', v_pricing.gross_amount,
    'currency', v_pricing.currency
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], TEXT) TO authenticated, service_role;

-- 6. confirm_tournament_order_atomic (Strict Pending Guard)
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
  p_order_reference TEXT,
  p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_order RECORD;
  v_champ RECORD;
  v_role TEXT;
  v_joined_count INT;
  v_roster_id UUID;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user <> 'postgres' THEN
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    IF coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
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
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_pending',
        registration_status = 'cancelled',
        updated_at = now()
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending'
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
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_pending',
        registration_status = 'rejected',
        notes = 'over_capacity',
        updated_at = now()
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending'
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
      updated_at = now()
  WHERE id = v_order.id;

  UPDATE public.championship_registrations
  SET registration_status = 'confirmed',
      payment_status = 'paid',
      gross_amount = v_order.gross_amount,
      updated_at = now()
  WHERE id = v_order.registration_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_order.registration_id, v_order.championship_id, v_order.team_id,
    to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])), now()
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
      updated_at = now()
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
    now(), now()
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

REVOKE ALL ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) TO authenticated, service_role;

-- 7. claim_next_cancellation_refund_atomic (Service Role Only with 15-Minute Crash Lease Recovery)
DROP FUNCTION IF EXISTS public.claim_next_cancellation_refund_atomic();

CREATE OR REPLACE FUNCTION public.claim_next_cancellation_refund_atomic()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_row RECORD;
BEGIN
  -- Strict Access Control: ONLY service_role or postgres internal caller
  IF coalesce(auth.role(), '') <> 'service_role' AND current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_cancellation_refund_atomic is restricted to service_role';
  END IF;

  -- 1. Select pending row OR abandoned processing row whose 15-minute lease expired
  SELECT * INTO v_row
  FROM public.cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- 2. If it crashed/timed-out 3 or more times, automatically escalate to manual review
  IF v_row.retry_count >= 3 THEN
    UPDATE public.cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Worker lease timed out 3 times; escalated to manual review',
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.order_id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.registration_id;

    RETURN jsonb_build_object(
      'found', false, 
      'escalated_to_manual_review', true, 
      'order_id', v_row.order_id
    );
  END IF;

  -- 3. Atomic Lease Claim
  UPDATE public.cancellation_refund_queue
  SET status = 'processing',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', row_to_json(v_row)
  );
END;
$$;

-- P0: STRICT RESTRICTION - ZERO anon or authenticated access
REVOKE ALL ON FUNCTION public.claim_next_cancellation_refund_atomic() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_next_cancellation_refund_atomic() TO service_role;

-- 8. crown_tournament_champion_atomic (Immutable Champion & Frozen Roster Trophies)
CREATE OR REPLACE FUNCTION public.crown_tournament_champion_atomic(
  p_championship_id UUID,
  p_champion_team_id UUID,
  p_champion_team_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_role TEXT;
  v_team_name TEXT;
  v_prize NUMERIC;
  v_trophy_title TEXT;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_member RECORD;
  v_roster_id UUID;
  v_awarded INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF v_champ.owner_id IS DISTINCT FROM auth.uid() AND coalesce(v_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 1. Immutable Champion Check: Once completed, champion CANNOT be changed
  IF v_champ.status = 'completed' THEN
    IF v_champ.champion_team_id = p_champion_team_id THEN
      RETURN jsonb_build_object('success', true, 'already_crowned', true, 'champion_team_id', p_champion_team_id);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'championship_already_completed_with_different_champion');
    END IF;
  END IF;

  IF v_champ.status != 'ongoing' THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_ongoing');
  END IF;

  -- 2. Team Must Be Confirmed
  IF NOT EXISTS (
    SELECT 1 FROM public.championship_registrations
    WHERE championship_id = p_championship_id
      AND team_id = p_champion_team_id
      AND registration_status = 'confirmed'
  ) AND NOT (p_champion_team_id::TEXT = ANY(coalesce(v_champ.paid_teams, ARRAY[]::TEXT[]))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'champion_team_not_confirmed');
  END IF;

  SELECT name INTO v_team_name FROM public.teams WHERE id = p_champion_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF p_champion_team_name IS NOT NULL AND trim(p_champion_team_name) != '' THEN
    v_team_name := p_champion_team_name;
  END IF;

  v_prize := coalesce(nullif(v_champ.prize_pool, 0), v_champ.grand_prize, 0);
  v_trophy_title := 'بطل بطولة ' || coalesce(v_champ.name, 'VSP');

  -- 3. Atomically Complete Championship
  UPDATE public.championships
  SET status = 'completed',
      champion_team_id = p_champion_team_id,
      champion_team_name = v_team_name,
      winner_team_id = p_champion_team_id,
      winner_team_name = v_team_name,
      updated_at = v_now
  WHERE id = p_championship_id;

  -- 4. Atomically Increment Wins, Points, and Award 'cup_winner' Badge
  UPDATE public.teams
  SET championships_won = coalesce(championships_won, 0) + 1,
      points = coalesce(points, 0) + 100,
      unlocked_badges = CASE
        WHEN 'cup_winner' = ANY(coalesce(unlocked_badges, ARRAY[]::TEXT[])) THEN unlocked_badges
        ELSE array_append(coalesce(unlocked_badges, ARRAY[]::TEXT[]), 'cup_winner')
      END,
      updated_at = v_now
  WHERE id = p_champion_team_id;

  -- 5. Award Player Trophies Strictly to the Frozen Championship Roster
  SELECT id INTO v_roster_id
  FROM public.championship_rosters
  WHERE championship_id = p_championship_id AND team_id = p_champion_team_id;

  IF v_roster_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.championship_roster_players WHERE roster_id = v_roster_id) THEN
    FOR v_member IN 
      SELECT player_id AS user_id FROM public.championship_roster_players WHERE roster_id = v_roster_id
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies 
        WHERE user_id = v_member.user_id AND championship_id = p_championship_id
      ) THEN
        INSERT INTO public.player_trophies(id, user_id, championship_id, title, prize_won, created_at)
        VALUES (gen_random_uuid(), v_member.user_id, p_championship_id, v_trophy_title, v_prize, v_now);
        v_awarded := v_awarded + 1;
      END IF;
    END LOOP;
  ELSE
    -- Graceful fallback for legacy records
    FOR v_member IN SELECT user_id FROM public.team_members WHERE team_id = p_champion_team_id LOOP
      IF NOT EXISTS (
        SELECT 1 FROM public.player_trophies 
        WHERE user_id = v_member.user_id AND championship_id = p_championship_id
      ) THEN
        INSERT INTO public.player_trophies(id, user_id, championship_id, title, prize_won, created_at)
        VALUES (gen_random_uuid(), v_member.user_id, p_championship_id, v_trophy_title, v_prize, v_now);
        v_awarded := v_awarded + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'champion_team_id', p_champion_team_id,
    'championship_id', p_championship_id,
    'trophies_awarded', v_awarded,
    'prize_awarded', v_prize
  );
END;
$$;

REVOKE ALL ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crown_tournament_champion_atomic(UUID, UUID, TEXT) TO authenticated, service_role;

-- 9. Ensure Sole Public Read Access on get_championship_public_state
REVOKE ALL ON FUNCTION public.get_championship_public_state(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_championship_public_state(UUID) TO anon, authenticated, service_role;
