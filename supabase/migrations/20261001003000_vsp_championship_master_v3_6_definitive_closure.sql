-- ==============================================================================
-- Migration: 20261001003000_vsp_championship_master_v3_6_definitive_closure.sql
-- Description: V3.6 Definitive Architecture Closure for VSP Regular Championship
-- 1. Crash recovery lease columns: processing_started_at, locked_until
-- 2. DB Trigger for cross-team duplicate player prevention in same championship
-- 3. Hardened atomic RPCs: update_championship_roster_atomic, join_championship_atomic
-- 4. Idempotency key conflict safety in create_tournament_order_atomic
-- 5. Mandatory paymob_transaction_id guard in confirm_tournament_order_atomic
-- 6. Claim lease recovery & max retry escalation in claim_next_cancellation_refund_atomic
-- 7. DB trigger & pg_cron reconciliation for async cancellation refund worker
-- 8. Strict security privileges & grants
-- ==============================================================================

-- 1. Add crash recovery lease columns to cancellation_refund_queue
ALTER TABLE public.cancellation_refund_queue
  ADD COLUMN IF NOT EXISTS processing_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

-- 2. Database Invariant Trigger: Prevent a player from participating in two teams in the same championship
CREATE OR REPLACE FUNCTION public.check_roster_player_single_championship()
RETURNS TRIGGER AS $$
DECLARE
  v_champ_id UUID;
  v_team_id UUID;
BEGIN
  SELECT championship_id, team_id INTO v_champ_id, v_team_id
  FROM public.championship_rosters
  WHERE id = NEW.roster_id;

  IF v_champ_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 
      FROM public.championship_roster_players crp
      JOIN public.championship_rosters cr ON cr.id = crp.roster_id
      WHERE cr.championship_id = v_champ_id
        AND cr.team_id <> v_team_id
        AND crp.player_id = NEW.player_id
    ) THEN
      RAISE EXCEPTION 'PLAYER_ALREADY_IN_ANOTHER_TEAM: Player % is already in another team roster in championship %', NEW.player_id, v_champ_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_check_roster_player_single_championship ON public.championship_roster_players;
CREATE TRIGGER trg_check_roster_player_single_championship
BEFORE INSERT OR UPDATE ON public.championship_roster_players
FOR EACH ROW EXECUTE FUNCTION public.check_roster_player_single_championship();

-- 3. Hardened update_championship_roster_atomic
CREATE OR REPLACE FUNCTION public.update_championship_roster_atomic(
  p_championship_id UUID,
  p_team_id UUID,
  p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
  p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_champ RECORD;
  v_team RECORD;
  v_reg RECORD;
  v_roster_id UUID;
  v_player_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  -- Row lock first
  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- Freeze check: locked registration or past open phase
  IF v_champ.registration_locked_at IS NOT NULL OR v_champ.status IN ('ongoing', 'completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_frozen_registration_locked');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'team_not_found');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT * INTO v_reg FROM public.championship_registrations 
  WHERE championship_id = p_championship_id AND team_id = p_team_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_not_found');
  END IF;

  -- Duplicate player check inside p_player_ids
  IF coalesce(array_length(p_player_ids, 1), 0) > 0 THEN
    IF (SELECT count(DISTINCT pid) FROM unnest(p_player_ids) pid) <> array_length(p_player_ids, 1) THEN
      RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS_IN_ROSTER');
    END IF;
  END IF;

  -- Check team membership for each player_id
  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_members tm 
      WHERE tm.team_id = p_team_id AND tm.user_id = pid
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_team_player');
  END IF;

  -- Check player already registered with another team in the same championship
  IF EXISTS (
    SELECT 1 
    FROM public.championship_roster_players crp
    JOIN public.championship_rosters cr ON cr.id = crp.roster_id
    WHERE cr.championship_id = p_championship_id
      AND cr.team_id <> p_team_id
      AND crp.player_id = ANY(coalesce(p_player_ids, ARRAY[]::UUID[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_ALREADY_IN_ANOTHER_TEAM');
  END IF;

  -- Player count validation
  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_too_large', 'max_allowed', v_champ.max_players_per_team);
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_incomplete', 'min_required', v_champ.min_players_per_team);
  END IF;

  -- Upsert championship roster
  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_reg.id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  -- Synchronize roster players
  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  RETURN jsonb_build_object('success', true, 'roster_id', v_roster_id, 'player_count', v_player_count);
END;
$$;

-- 4. Hardened join_championship_atomic with All-in-One Transactional Integrity
CREATE OR REPLACE FUNCTION public.join_championship_atomic(
  p_championship_id UUID,
  p_team_id UUID,
  p_player_ids UUID[] DEFAULT ARRAY[]::UUID[],
  p_guest_names TEXT[] DEFAULT ARRAY[]::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_champ RECORD;
  v_phase TEXT;
  v_team RECORD;
  v_captain RECORD;
  v_reg_id UUID;
  v_roster_id UUID;
  v_joined_count INT;
  v_player_count INT;
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

  -- 3. Zero-fee check
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

  -- 4. Duplicate player check within p_player_ids
  IF coalesce(array_length(p_player_ids, 1), 0) > 0 THEN
    IF (SELECT count(DISTINCT pid) FROM unnest(p_player_ids) pid) <> array_length(p_player_ids, 1) THEN
      RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS_IN_ROSTER');
    END IF;
  END IF;

  -- 5. Team membership check
  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_members tm 
      WHERE tm.team_id = p_team_id AND tm.user_id = pid
    )
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TEAM_PLAYER_NOT_MEMBER');
  END IF;

  -- 6. Check player already registered with another team in this championship
  IF EXISTS (
    SELECT 1 
    FROM public.championship_roster_players crp
    JOIN public.championship_rosters cr ON cr.id = crp.roster_id
    WHERE cr.championship_id = p_championship_id
      AND cr.team_id <> p_team_id
      AND crp.player_id = ANY(coalesce(p_player_ids, ARRAY[]::UUID[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYER_ALREADY_IN_ANOTHER_TEAM');
  END IF;

  -- 7. Player count validation
  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_TOO_LARGE', 'max_allowed', v_champ.max_players_per_team);
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ROSTER_INCOMPLETE', 'min_required', v_champ.min_players_per_team);
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

  -- 8. Atomic Registration
  INSERT INTO public.championship_registrations (
    championship_id, team_id, captain_id, captain_snapshot,
    registration_status, payment_status, base_amount, gross_amount, currency,
    created_at, updated_at
  )
  VALUES (
    p_championship_id, p_team_id, v_team.captain_id,
    jsonb_build_object('id', v_captain.id, 'name', v_captain.full_name, 'phone', v_captain.phone),
    'confirmed', 'exempt', 0.00, 0.00, coalesce(v_champ.currency, 'EGP'),
    now(), now()
  )
  ON CONFLICT (championship_id, team_id) DO UPDATE SET
    registration_status = 'confirmed',
    payment_status = 'exempt',
    updated_at = now()
  RETURNING id INTO v_reg_id;

  -- 9. Atomic Roster
  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_reg_id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  -- 10. Atomic Roster Players
  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  -- 11. Update Championship Arrays
  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), p_team_id::TEXT),
      updated_at = now()
  WHERE id = p_championship_id
    AND NOT (p_team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  RETURN jsonb_build_object(
    'success', true,
    'registration_id', v_reg_id,
    'roster_id', v_roster_id,
    'payment_status', 'exempt',
    'registration_status', 'confirmed',
    'player_count', v_player_count
  );
END;
$$;

-- 5. Hardened create_tournament_order_atomic with Safe Idempotency Collision Handling
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
SET search_path = public
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

  -- Safe Idempotency Key Handling
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT * INTO v_existing_order
    FROM public.tournament_orders
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
      IF v_existing_order.payment_status = 'pending' THEN
        RETURN jsonb_build_object(
          'success', true,
          'existing_order', true,
          'order_id', v_existing_order.id,
          'order_reference', v_existing_order.order_reference,
          'gross_amount', v_existing_order.gross_amount
        );
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'IDEMPOTENCY_KEY_ALREADY_USED',
          'order_status', v_existing_order.payment_status,
          'order_reference', v_existing_order.order_reference
        );
      END IF;
    END IF;
  END IF;

  -- Reuse existing pending order if active for this team and championship
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

-- 6. Hardened confirm_tournament_order_atomic with Strict Transaction ID Check
CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(
  p_order_reference TEXT,
  p_paymob_transaction_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_pending',
        registration_status = 'cancelled',
        updated_at = now()
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending', now(), now()
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
      amount, currency, status, created_at, updated_at
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending', now(), now()
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
    registration_id, championship_id, team_id, guest_names, created_at, updated_at
  )
  VALUES (
    v_order.registration_id, v_order.championship_id, v_order.team_id,
    to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])), now(), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
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

-- 7. Hardened claim_next_cancellation_refund_atomic with Explicit Lease Management
CREATE OR REPLACE FUNCTION public.claim_next_cancellation_refund_atomic()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- 2. Max Retry Invariant: Escalate to failed_manual_review after 3 failed attempts
  IF v_row.retry_count >= 3 THEN
    UPDATE public.cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
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
      'queue_id', v_row.id
    );
  END IF;

  -- 3. Atomically transition to processing with 15-minute lease
  UPDATE public.cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'championship_id', v_row.championship_id,
      'order_id', v_row.order_id,
      'registration_id', v_row.registration_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', v_row.currency,
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$$;

-- 8. DB Trigger on cancellation_refund_queue to fire Edge Function worker server-to-server
CREATE OR REPLACE FUNCTION public.trigger_cancellation_refund_worker()
RETURNS TRIGGER AS $$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
BEGIN
  -- Obtain internal worker secret safely
  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name IN ('fcm_push', 'service_role')
  ORDER BY (name = 'service_role') DESC
  LIMIT 1;

  IF coalesce(v_secret, '') = '' THEN
    RAISE WARNING 'Internal worker secret is missing; refund worker push skipped safely.';
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body := jsonb_build_object('action', 'process_queue')
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Refund worker trigger exception (safe-bypass): %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_cancellation_refund_queue_worker ON public.cancellation_refund_queue;
CREATE TRIGGER trg_cancellation_refund_queue_worker
AFTER INSERT ON public.cancellation_refund_queue
FOR EACH ROW EXECUTE FUNCTION public.trigger_cancellation_refund_worker();

-- 9. pg_cron Reconciliation Job: Runs every 10 minutes to process queue even if trigger was missed
CREATE OR REPLACE FUNCTION public.reconcile_cancellation_refund_queue()
RETURNS VOID AS $$
DECLARE
  v_url TEXT := 'https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/process_tournament_refund';
  v_secret TEXT;
  v_has_pending BOOLEAN := false;
BEGIN
  SELECT EXISTS (
    SELECT 1 
    FROM public.cancellation_refund_queue
    WHERE status = 'pending'
       OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
       OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ) INTO v_has_pending;

  IF NOT v_has_pending THEN
    RETURN;
  END IF;

  SELECT secret INTO v_secret
  FROM public.internal_function_secrets
  WHERE name IN ('fcm_push', 'service_role')
  ORDER BY (name = 'service_role') DESC
  LIMIT 1;

  IF coalesce(v_secret, '') <> '' THEN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body := jsonb_build_object('action', 'process_queue')
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'reconcile_cancellation_refund_queue error: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Schedule pg_cron reconciliation job every 10 minutes if pg_cron is available
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Unschedule existing job if already present
    PERFORM cron.unschedule('reconcile_cancellation_refund_queue')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'reconcile_cancellation_refund_queue');

    PERFORM cron.schedule(
      'reconcile_cancellation_refund_queue',
      '*/10 * * * *',
      'SELECT public.reconcile_cancellation_refund_queue();'
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'pg_cron scheduling skipped: %', SQLERRM;
END;
$$;

-- 10. Strict Security Grants
REVOKE ALL ON FUNCTION public.claim_next_cancellation_refund_atomic() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_next_cancellation_refund_atomic() TO service_role;

REVOKE ALL ON FUNCTION public.calculate_tournament_checkout_amount_atomic(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_tournament_checkout_amount_atomic(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.calculate_championship_effective_phase(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_championship_effective_phase(UUID) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reconcile_cancellation_refund_queue() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_cancellation_refund_queue() TO service_role;

GRANT EXECUTE ON FUNCTION public.get_championship_public_state(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.join_championship_atomic(UUID, UUID, UUID[], TEXT[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_championship_roster_atomic(UUID, UUID, UUID[], TEXT[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_tournament_order_atomic(UUID, UUID, UUID[], TEXT[], TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_tournament_order_atomic(TEXT, TEXT) TO authenticated, service_role;
