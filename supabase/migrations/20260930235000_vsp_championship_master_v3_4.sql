-- ============================================================================
-- VSP CHAMPIONSHIP MASTER ARCHITECTURE & SPECIFICATION V3.4 (FINAL)
-- Migration: 20260930235000_vsp_championship_master_v3_4.sql
-- ============================================================================

-- STEP 1: Update existing constraints to permit valid target states
ALTER TABLE public.championships
  DROP CONSTRAINT IF EXISTS championships_status_check;

ALTER TABLE public.championships
  ADD CONSTRAINT championships_status_check
  CHECK (status = ANY (ARRAY['open'::text, 'ongoing'::text, 'completed'::text, 'cancelled'::text]));

ALTER TABLE public.tournament_orders
  DROP CONSTRAINT IF EXISTS tournament_orders_payment_status_check;

ALTER TABLE public.tournament_orders
  ADD CONSTRAINT tournament_orders_payment_status_check
  CHECK (payment_status = ANY (ARRAY[
    'pending'::text,
    'paid'::text,
    'failed'::text,
    'cancelled'::text,
    'failed_over_capacity'::text,
    'refund_pending'::text,
    'refunded'::text,
    'refund_failed_manual_review'::text
  ]));

-- STEP 2: Add columns to championships (Nullable initially)
ALTER TABLE public.championships
  ADD COLUMN IF NOT EXISTS stadium_id UUID REFERENCES public.stadiums(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS registration_closes_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'EGP';

-- STEP 3: Backfill all existing open championships before applying check constraint
UPDATE public.championships
SET registration_closes_at = start_date
WHERE status = 'open' AND registration_closes_at IS NULL;

UPDATE public.championships
SET registration_closes_at = start_date
WHERE status = 'open' AND registration_closes_at > start_date;

-- Target repair for test championship
UPDATE public.championships
SET stadium_id = '34af8a1c-3f83-4154-bdbc-b88d113c1b04',
    registration_locked_at = now()
WHERE id = '457f0e54-84b7-4951-b207-c8b7408683a4';

-- STEP 4: Add check constraint safely
ALTER TABLE public.championships
  DROP CONSTRAINT IF EXISTS chk_championship_open_deadline;

ALTER TABLE public.championships
  ADD CONSTRAINT chk_championship_open_deadline
  CHECK (status != 'open' OR (registration_closes_at IS NOT NULL AND registration_closes_at <= start_date));

-- STEP 5: Create championship_registrations table with composite uniqueness
CREATE TABLE IF NOT EXISTS public.championship_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  championship_id UUID NOT NULL REFERENCES public.championships(id) ON DELETE RESTRICT,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  captain_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  captain_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
  registration_status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (registration_status IN ('pending', 'confirmed', 'cancelled', 'cancelled_unpaid', 'rejected')),
  payment_status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (payment_status IN ('pending', 'paid', 'exempt', 'refund_pending', 'refunded', 'refund_failed_manual_review')),
  base_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  gross_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'EGP',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_champ_reg_team UNIQUE (championship_id, team_id),
  CONSTRAINT uq_champ_reg_composite UNIQUE (id, championship_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_champ_reg_lookup 
ON public.championship_registrations(championship_id, team_id, registration_status);

-- STEP 6: Update tournament_orders with financial columns, idempotency & invariants
ALTER TABLE public.tournament_orders
  ADD COLUMN IF NOT EXISTS registration_id UUID REFERENCES public.championship_registrations(id) ON DELETE RESTRICT,
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS base_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS platform_fee_amount NUMERIC(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS gateway_fee_amount NUMERIC(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS gross_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'EGP',
  ADD COLUMN IF NOT EXISTS fee_policy_version TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_tourn_orders_idempotency_key'
  ) THEN
    ALTER TABLE public.tournament_orders
      ADD CONSTRAINT uq_tourn_orders_idempotency_key UNIQUE (idempotency_key);
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_tourn_orders_active_pending
ON public.tournament_orders(registration_id)
WHERE registration_id IS NOT NULL AND payment_status = 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS uq_tourn_orders_paid
ON public.tournament_orders(registration_id)
WHERE registration_id IS NOT NULL AND payment_status = 'paid';

-- STEP 7: Update championship_rosters with Composite FK
ALTER TABLE public.championship_rosters
  ADD COLUMN IF NOT EXISTS registration_id UUID,
  ADD COLUMN IF NOT EXISTS is_frozen BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS frozen_at TIMESTAMPTZ;

-- Backfill existing rosters if any exist
UPDATE public.championship_rosters r
SET registration_id = cr.id
FROM public.championship_registrations cr
WHERE cr.championship_id = r.championship_id AND cr.team_id = r.team_id
  AND r.registration_id IS NULL;

-- Enforce composite foreign key constraint
ALTER TABLE public.championship_rosters
  DROP CONSTRAINT IF EXISTS fk_champ_roster_registration;

ALTER TABLE public.championship_rosters
  ADD CONSTRAINT fk_champ_roster_registration
  FOREIGN KEY (registration_id, championship_id, team_id)
  REFERENCES public.championship_registrations(id, championship_id, team_id)
  ON DELETE RESTRICT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_champ_roster_reg
ON public.championship_rosters(registration_id);

-- STEP 8: Create cancellation_refund_queue with RESTRICT and idempotency
CREATE TABLE IF NOT EXISTS public.cancellation_refund_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  championship_id UUID NOT NULL REFERENCES public.championships(id) ON DELETE RESTRICT,
  order_id UUID NOT NULL REFERENCES public.tournament_orders(id) ON DELETE RESTRICT,
  registration_id UUID NOT NULL REFERENCES public.championship_registrations(id) ON DELETE RESTRICT,
  paymob_transaction_id TEXT,
  amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  currency TEXT NOT NULL DEFAULT 'EGP',
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'processing', 'completed', 'failed_manual_review')),
  retry_count INT NOT NULL DEFAULT 0,
  failure_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  CONSTRAINT uq_refund_queue_order UNIQUE (order_id)
);

CREATE INDEX IF NOT EXISTS idx_refund_queue_status 
ON public.cancellation_refund_queue(status, created_at);

-- STEP 9: Enable RLS & Configure Access
ALTER TABLE public.championship_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cancellation_refund_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS championship_registrations_select ON public.championship_registrations;
CREATE POLICY championship_registrations_select ON public.championship_registrations
FOR SELECT TO authenticated
USING (
  captain_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.team_members tm 
    WHERE tm.team_id = championship_registrations.team_id AND tm.user_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM public.championships c 
    WHERE c.id = championship_registrations.championship_id AND c.owner_id = auth.uid()
  )
  OR public.is_admin_or_cofounder(auth.uid())
);

REVOKE INSERT, UPDATE, DELETE ON public.championship_registrations FROM anon, authenticated;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.cancellation_refund_queue FROM anon, authenticated, public;

-- STEP 10: Server RPC Functions

-- 1. calculate_tournament_checkout_amount_atomic
CREATE OR REPLACE FUNCTION public.calculate_tournament_checkout_amount_atomic(
  p_championship_id UUID
)
RETURNS TABLE (
  base_amount NUMERIC,
  platform_fee_amount NUMERIC,
  gateway_fee_amount NUMERIC,
  gross_amount NUMERIC,
  currency TEXT,
  fee_policy_version TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_entry_fee NUMERIC;
  v_currency TEXT;
  v_fee RECORD;
  v_base NUMERIC;
  v_vsp NUMERIC;
  v_gw NUMERIC;
  v_gross NUMERIC;
  v_version TEXT;
BEGIN
  SELECT coalesce(c.entry_fee, 0), coalesce(c.currency, 'EGP')
  INTO v_entry_fee, v_currency
  FROM public.championships c
  WHERE c.id = p_championship_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found: %', p_championship_id;
  END IF;

  IF v_entry_fee <= 0 THEN
    RETURN QUERY SELECT 0.00::NUMERIC, 0.00::NUMERIC, 0.00::NUMERIC, 0.00::NUMERIC, v_currency, 'free_policy'::TEXT;
    RETURN;
  END IF;

  SELECT booking_vsp_rate,
         coalesce(booking_paymob_local_rate, booking_paymob_rate, 0.0275) AS gw_rate,
         coalesce(booking_paymob_fixed_fee, 3.00) AS gw_fixed,
         updated_at
  INTO v_fee
  FROM public.platform_fee_config
  WHERE id = 1;

  v_base := round(v_entry_fee, 2);
  v_vsp  := round(v_base * coalesce(v_fee.booking_vsp_rate, 0.02), 2);
  v_gw   := round(v_base * v_fee.gw_rate + v_fee.gw_fixed, 2);
  v_gross := round(v_base + v_vsp + v_gw, 2);
  v_version := 'pfc_1_' || to_char(coalesce(v_fee.updated_at, now()), 'YYYYMMDDHH24MISS');

  RETURN QUERY SELECT v_base, v_vsp, v_gw, v_gross, v_currency, v_version;
END;
$$;

-- 2. get_championship_public_state
CREATE OR REPLACE FUNCTION public.get_championship_public_state(
  p_championship_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_stadium RECORD;
  v_fixtures_count INT;
  v_confirmed_teams_count INT;
  v_effective_phase TEXT;
  v_can_join BOOLEAN := false;
  v_join_block_reason TEXT := NULL;
  v_caller_id UUID := auth.uid();
  v_my_registrations JSONB := '[]'::JSONB;
  v_pricing RECORD;
  v_pricing_available BOOLEAN := false;
  v_caller_reg RECORD;
  v_caller_is_captain BOOLEAN := false;
BEGIN
  SELECT c.id, c.name, c.status, c.entry_fee, c.grand_prize, c.max_teams, c.owner_id,
         c.start_date, c.end_date, c.registration_closes_at, c.registration_locked_at,
         c.min_players_per_team, c.max_players_per_team, c.stadium_id, c.currency,
         c.type, c.rules, c.is_approved, c.creation_fee_paid
  INTO v_champ
  FROM public.championships c
  WHERE c.id = p_championship_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  SELECT s.id, s.name, s.location, s.governorate, s.city, s.lat, s.lng, s.image_url, s.images
  INTO v_stadium
  FROM public.stadiums s
  WHERE s.id = v_champ.stadium_id;

  SELECT count(*)::INT INTO v_fixtures_count
  FROM public.tournament_matches tm
  WHERE tm.championship_id = p_championship_id;

  SELECT count(*)::INT INTO v_confirmed_teams_count
  FROM public.championship_registrations cr
  WHERE cr.championship_id = p_championship_id
    AND cr.registration_status = 'confirmed';

  -- Phase Engine SSOT
  IF v_champ.status = 'cancelled' THEN
    v_effective_phase := 'cancelled';
  ELSIF v_champ.status = 'completed' THEN
    v_effective_phase := 'completed';
  ELSIF v_champ.status = 'ongoing' THEN
    v_effective_phase := 'ongoing';
  ELSIF v_champ.status = 'open' AND v_champ.registration_locked_at IS NOT NULL AND v_fixtures_count > 0 THEN
    v_effective_phase := 'draw_ready';
  ELSIF v_champ.status = 'open' AND (
    v_champ.registration_locked_at IS NOT NULL
    OR (v_champ.registration_closes_at IS NOT NULL AND now() >= v_champ.registration_closes_at)
    OR now() >= v_champ.start_date
  ) THEN
    v_effective_phase := 'registration_closed';
  ELSIF v_champ.status = 'open' AND coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = false THEN
    v_effective_phase := 'draft';
  ELSIF v_champ.status = 'open' AND coalesce(v_champ.is_approved, false) = false AND coalesce(v_champ.creation_fee_paid, false) = true THEN
    v_effective_phase := 'pending_approval';
  ELSE
    v_effective_phase := 'registration_open';
  END IF;

  -- Join Eligibility Engine
  IF v_caller_id IS NULL THEN
    v_can_join := false;
    v_join_block_reason := 'AUTH_REQUIRED';
  ELSIF v_effective_phase = 'cancelled' THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_CANCELLED';
  ELSIF v_effective_phase IN ('ongoing', 'completed') THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_STARTED';
  ELSIF v_effective_phase != 'registration_open' THEN
    v_can_join := false;
    v_join_block_reason := 'REGISTRATION_CLOSED';
  ELSIF v_confirmed_teams_count >= v_champ.max_teams THEN
    v_can_join := false;
    v_join_block_reason := 'CHAMPIONSHIP_FULL';
  ELSE
    SELECT EXISTS (SELECT 1 FROM public.teams WHERE captain_id = v_caller_id) INTO v_caller_is_captain;
    IF NOT v_caller_is_captain THEN
      v_can_join := false;
      v_join_block_reason := 'NOT_CAPTAIN';
    ELSE
      SELECT cr.registration_status, cr.payment_status
      INTO v_caller_reg
      FROM public.championship_registrations cr
      JOIN public.teams t ON t.id = cr.team_id
      WHERE cr.championship_id = p_championship_id
        AND t.captain_id = v_caller_id
        AND cr.registration_status NOT IN ('cancelled', 'cancelled_unpaid', 'rejected')
      LIMIT 1;

      IF FOUND THEN
        v_can_join := false;
        IF v_caller_reg.payment_status = 'pending' THEN
          v_join_block_reason := 'PAYMENT_PENDING';
        ELSE
          v_join_block_reason := 'TEAM_ALREADY_REGISTERED';
        END IF;
      ELSE
        v_can_join := true;
        v_join_block_reason := NULL;
      END IF;
    END IF;
  END IF;

  IF v_caller_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'registration_id', cr.id,
      'team_id', cr.team_id,
      'team_name', t.name,
      'team_logo_url', t.logo_url,
      'registration_status', cr.registration_status,
      'payment_status', cr.payment_status,
      'is_captain', (t.captain_id = v_caller_id),
      'can_manage_roster', (t.captain_id = v_caller_id AND v_champ.registration_locked_at IS NULL),
      'gross_amount', cr.gross_amount
    )), '[]'::JSONB)
    INTO v_my_registrations
    FROM public.championship_registrations cr
    JOIN public.teams t ON t.id = cr.team_id
    WHERE cr.championship_id = p_championship_id
      AND EXISTS (
        SELECT 1 FROM public.team_members tm 
        WHERE tm.team_id = cr.team_id AND tm.user_id = v_caller_id
      );
  END IF;

  SELECT * INTO v_pricing FROM public.calculate_tournament_checkout_amount_atomic(p_championship_id);
  v_pricing_available := (v_effective_phase = 'registration_open' AND v_can_join = true);

  RETURN jsonb_build_object(
    'success', true,
    'championship', jsonb_build_object(
      'id', v_champ.id,
      'name', v_champ.name,
      'status', v_champ.status,
      'effective_phase', v_effective_phase,
      'entry_fee', v_champ.entry_fee,
      'grand_prize', v_champ.grand_prize,
      'currency', coalesce(v_champ.currency, 'EGP'),
      'max_teams', v_champ.max_teams,
      'confirmed_teams_count', v_confirmed_teams_count,
      'min_players_per_team', v_champ.min_players_per_team,
      'max_players_per_team', v_champ.max_players_per_team,
      'start_date', v_champ.start_date,
      'end_date', v_champ.end_date,
      'registration_closes_at', v_champ.registration_closes_at,
      'registration_locked_at', v_champ.registration_locked_at,
      'rules', v_champ.rules,
      'stadium', CASE WHEN v_stadium.id IS NOT NULL THEN jsonb_build_object(
        'id', v_stadium.id,
        'name', v_stadium.name,
        'location', v_stadium.location,
        'governorate', v_stadium.governorate,
        'city', v_stadium.city,
        'lat', v_stadium.lat,
        'lng', v_stadium.lng,
        'image_url', v_stadium.image_url,
        'images', v_stadium.images
      ) ELSE NULL END
    ),
    'pricing', jsonb_build_object(
      'available', v_pricing_available,
      'base_amount', v_pricing.base_amount,
      'platform_fee_amount', v_pricing.platform_fee_amount,
      'gateway_fee_amount', v_pricing.gateway_fee_amount,
      'gross_amount', v_pricing.gross_amount,
      'currency', v_pricing.currency
    ),
    'capabilities', jsonb_build_object(
      'can_join', v_can_join,
      'join_block_reason', v_join_block_reason,
      'can_view_bracket', (v_fixtures_count > 0)
    ),
    'my_registrations', v_my_registrations
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_championship_public_state(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_championship_public_state(UUID) TO anon, authenticated;

-- 3. join_championship_atomic
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
  v_team RECORD;
  v_captain RECORD;
  v_reg_id UUID;
  v_roster_id UUID;
  v_joined_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED');
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

-- 4. create_tournament_order_atomic
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

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED');
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

  -- SSOT Pricing
  SELECT * INTO v_pricing FROM public.calculate_tournament_checkout_amount_atomic(p_championship_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, order_reference, gross_amount, payment_status
    INTO v_existing_order
    FROM public.tournament_orders
    WHERE idempotency_key = p_idempotency_key;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'success', true,
        'existing_order', true,
        'order_id', v_existing_order.id,
        'order_reference', v_existing_order.order_reference,
        'gross_amount', v_existing_order.gross_amount,
        'payment_status', v_existing_order.payment_status
      );
    END IF;
  END IF;

  SELECT id, full_name, phone INTO v_captain FROM public.users WHERE id = v_team.captain_id;

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
    base_amount = v_pricing.base_amount,
    gross_amount = v_pricing.gross_amount,
    currency = v_pricing.currency,
    updated_at = now()
  RETURNING id INTO v_reg_id;

  SELECT id, order_reference, gross_amount INTO v_existing_order
  FROM public.tournament_orders
  WHERE registration_id = v_reg_id AND payment_status = 'pending'
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF v_existing_order.id IS NOT NULL THEN
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

-- 5. confirm_tournament_order_atomic
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

  IF v_order.payment_status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'order_id', v_order.id);
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = v_order.championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  IF v_champ.status = 'cancelled' OR v_order.payment_status = 'cancelled' THEN
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
      'requires_refund', true,
      'amount', v_order.gross_amount,
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

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
      'requires_refund', true,
      'amount', v_order.gross_amount,
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

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
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[]))
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
    'سداد اشتراك بطولة',
    jsonb_build_object('order_reference', p_order_reference, 'paymob_transaction_id', p_paymob_transaction_id, 'registration_id', v_order.registration_id),
    now(), now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'registration_id', v_order.registration_id,
    'gross_amount', v_order.gross_amount
  );
END;
$$;

-- 6. start_championship_atomic
CREATE OR REPLACE FUNCTION public.start_championship_atomic(
  p_championship_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_confirmed_count INT;
  v_lock_time TIMESTAMPTZ := now();
  v_matches_count INT := 0;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  IF coalesce(v_champ.is_approved, false) != true THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_approved');
  END IF;

  IF coalesce(v_champ.creation_fee_paid, false) != true THEN
    RETURN jsonb_build_object('success', false, 'error', 'creation_fee_unpaid');
  END IF;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_already_locked_or_invalid_status');
  END IF;

  UPDATE public.championships
  SET registration_locked_at = v_lock_time,
      updated_at = v_lock_time
  WHERE id = p_championship_id;

  UPDATE public.championship_registrations
  SET registration_status = 'cancelled_unpaid',
      updated_at = v_lock_time
  WHERE championship_id = p_championship_id
    AND registration_status = 'pending'
    AND payment_status = 'pending';

  SELECT count(*)::INT INTO v_confirmed_count
  FROM public.championship_registrations
  WHERE championship_id = p_championship_id
    AND registration_status = 'confirmed';

  IF v_confirmed_count < 2 THEN
    RAISE EXCEPTION 'insufficient_confirmed_teams: %', v_confirmed_count;
  END IF;

  UPDATE public.championship_rosters
  SET is_frozen = true,
      frozen_at = v_lock_time
  WHERE championship_id = p_championship_id;

  PERFORM public.generate_tournament_bracket_fixtures_internal(p_championship_id);

  SELECT count(*)::INT INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'effective_phase', 'draw_ready',
    'confirmed_teams', v_confirmed_count,
    'matches_count', v_matches_count
  );
END;
$$;

-- 7. activate_championship_competition_atomic
CREATE OR REPLACE FUNCTION public.activate_championship_competition_atomic(
  p_championship_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_matches_count INT;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  SELECT count(*)::INT INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  IF v_champ.status != 'open' OR v_champ.registration_locked_at IS NULL OR v_matches_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_in_draw_ready_phase');
  END IF;

  UPDATE public.championships
  SET status = 'ongoing',
      updated_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'ongoing',
    'effective_phase', 'ongoing'
  );
END;
$$;

-- 8. cancel_championship_atomic
CREATE OR REPLACE FUNCTION public.cancel_championship_atomic(
  p_championship_id UUID,
  p_reason TEXT DEFAULT 'Cancelled by owner'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_order RECORD;
  v_refunds_count INT := 0;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  IF v_champ.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'terminal_status_cannot_cancel');
  END IF;

  UPDATE public.championships
  SET status = 'cancelled',
      registration_locked_at = coalesce(registration_locked_at, now()),
      updated_at = now()
  WHERE id = p_championship_id;

  UPDATE public.championship_registrations
  SET registration_status = 'cancelled',
      payment_status = CASE WHEN payment_status = 'paid' THEN 'refund_pending' ELSE payment_status END,
      updated_at = now()
  WHERE championship_id = p_championship_id;

  UPDATE public.tournament_orders
  SET payment_status = 'cancelled',
      updated_at = now()
  WHERE championship_id = p_championship_id
    AND payment_status = 'pending';

  FOR v_order IN 
    SELECT o.id, o.registration_id, o.gross_amount, o.currency, o.paymob_transaction_id
    FROM public.tournament_orders o
    WHERE o.championship_id = p_championship_id
      AND o.payment_status = 'paid'
      AND coalesce(o.gross_amount, 0) > 0
  LOOP
    UPDATE public.tournament_orders
    SET payment_status = 'refund_pending',
        updated_at = now()
    WHERE id = v_order.id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status
    )
    VALUES (
      p_championship_id, v_order.id, v_order.registration_id, v_order.paymob_transaction_id,
      v_order.gross_amount, coalesce(v_order.currency, 'EGP'), 'pending'
    )
    ON CONFLICT (order_id) DO NOTHING;

    v_refunds_count := v_refunds_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'cancelled',
    'effective_phase', 'cancelled',
    'queued_refunds_count', v_refunds_count
  );
END;
$$;

-- 9. update_championship_roster_atomic
CREATE OR REPLACE FUNCTION public.update_championship_roster_atomic(
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
  v_team RECORD;
  v_reg RECORD;
  v_roster_id UUID;
  v_player_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.registration_locked_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_frozen_registration_locked');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'team_not_found'); END IF;

  IF v_team.captain_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_CAPTAIN');
  END IF;

  SELECT * INTO v_reg FROM public.championship_registrations 
  WHERE championship_id = p_championship_id AND team_id = p_team_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'registration_not_found');
  END IF;

  v_player_count := coalesce(array_length(p_player_ids, 1), 0) + coalesce(array_length(p_guest_names, 1), 0);
  IF v_player_count > coalesce(v_champ.max_players_per_team, 999) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_too_large');
  END IF;
  IF v_player_count < coalesce(v_champ.min_players_per_team, 1) THEN
    RETURN jsonb_build_object('success', false, 'error', 'roster_incomplete');
  END IF;

  IF EXISTS (
    SELECT 1 FROM unnest(coalesce(p_player_ids, ARRAY[]::UUID[])) pid
    WHERE NOT EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = p_team_id AND tm.user_id = pid)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_team_player');
  END IF;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_reg.id, p_championship_id, p_team_id, to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])), now()
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(p_guest_names, ARRAY[]::TEXT[])),
    updated_at = now()
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF p_player_ids IS NOT NULL AND array_length(p_player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(p_player_ids);
  END IF;

  RETURN jsonb_build_object('success', true, 'roster_id', v_roster_id, 'player_count', v_player_count);
END;
$$;

-- STEP 11: Total elimination of legacy toggle
REVOKE ALL ON FUNCTION public.toggle_championship_team_payment_atomic(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.toggle_championship_team_payment_atomic(uuid, uuid, boolean);
