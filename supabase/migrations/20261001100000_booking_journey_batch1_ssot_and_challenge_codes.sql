-- =============================================================================
-- VSP Booking Journey Rebuild — Batch 1: SSOT + Challenge Code System
-- Migration: 20261001100000
-- Date: 2026-10-01
-- Changes:
--   1. Fix booking_type constraint to SSOT: personal | open_join | challenge only
--   2. Fix booking status constraint to include 'expired'
--   3. Fix challenge_status column constraint (new model)
--   4. Create team_challenge_codes table (single-use challenge codes)
--   5. Rebuild protect_booking_sensitive_fields trigger (add missing fields)
--   6. Upgrade request_join_public_match to enforce booking_type = 'open_join'
--   7. Upgrade leave_public_match_atomic to block post-match edits
--   8. Upgrade create_booking_atomic to accept p_initial_players + p_total_capacity
--   9. New RPC: create_challenge_booking_atomic (full atomic challenge flow)
--  10. New RPC: generate_team_challenge_code (for captain's code screen)
--  11. New RPC: lookup_challenge_code (verify code before booking)
--  12. Seed active codes for all existing teams
-- =============================================================================

-- 1. Normalize booking_type constraint to 3 canonical values
ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_booking_type_check;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_booking_type_check
    CHECK (booking_type IN ('personal', 'open_join', 'challenge'));

-- 2. Add 'expired' to booking status
ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_status_check
    CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled', 'expired'));

-- 3. Normalize challenge_status (new independent state machine)
ALTER TABLE public.bookings
  DROP CONSTRAINT IF EXISTS bookings_challenge_status_check;

ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_challenge_status_check
    CHECK (challenge_status IS NULL OR challenge_status IN (
      'ready', 'confirmed', 'completed', 'cancelled', 'expired'
    ));

-- 4. Create team_challenge_codes table
CREATE TABLE IF NOT EXISTS public.team_challenge_codes (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id            uuid        NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  code               text        NOT NULL UNIQUE,
  status             text        NOT NULL DEFAULT 'active'
                                   CHECK (status IN ('active', 'used', 'expired')),
  used_in_booking_id uuid        REFERENCES public.bookings(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT timezone('utc', now()),
  used_at            timestamptz,
  expires_at         timestamptz
);

CREATE INDEX IF NOT EXISTS idx_challenge_codes_team
  ON public.team_challenge_codes(team_id);
CREATE INDEX IF NOT EXISTS idx_challenge_codes_active_code
  ON public.team_challenge_codes(code) WHERE status = 'active';

ALTER TABLE public.team_challenge_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "challenge_codes_read" ON public.team_challenge_codes;
CREATE POLICY "challenge_codes_read"
  ON public.team_challenge_codes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "challenge_codes_service_write" ON public.team_challenge_codes;
CREATE POLICY "challenge_codes_service_write"
  ON public.team_challenge_codes FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

REVOKE INSERT, UPDATE, DELETE ON public.team_challenge_codes FROM authenticated, anon;
GRANT SELECT ON public.team_challenge_codes TO authenticated;

-- 5. Helper: generate unique VSP-XXXXX code
CREATE OR REPLACE FUNCTION public._generate_unique_challenge_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_code text;
  v_try  int := 0;
BEGIN
  LOOP
    v_code := 'VSP-' || upper(
      translate(
        substring(md5(gen_random_uuid()::text), 1, 5),
        '01IOil', 'ABCDEF'
      )
    );
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.team_challenge_codes WHERE code = v_code AND status = 'active'
    );
    v_try := v_try + 1;
    IF v_try > 30 THEN RAISE EXCEPTION 'code_generation_exhausted'; END IF;
  END LOOP;
  RETURN v_code;
END;
$fn$;

-- 6. RPC: generate_team_challenge_code
CREATE OR REPLACE FUNCTION public.generate_team_challenge_code(p_team_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_caller   uuid := auth.uid();
  v_team     record;
  v_code     text;
  v_code_id  uuid;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  IF v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  -- Return existing active code
  SELECT code, id INTO v_code, v_code_id
  FROM public.team_challenge_codes
  WHERE team_id = p_team_id AND status = 'active'
  ORDER BY created_at DESC LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success',   true,
      'code',      v_code,
      'code_id',   v_code_id,
      'team_id',   p_team_id,
      'team_name', v_team.name
    );
  END IF;

  -- Generate fresh code
  v_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at)
  VALUES (p_team_id, v_code, 'active', timezone('utc', now()))
  RETURNING id INTO v_code_id;

  RETURN jsonb_build_object(
    'success',   true,
    'code',      v_code,
    'code_id',   v_code_id,
    'team_id',   p_team_id,
    'team_name', v_team.name
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.generate_team_challenge_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_team_challenge_code(uuid) TO authenticated;

-- 7. RPC: lookup_challenge_code
CREATE OR REPLACE FUNCTION public.lookup_challenge_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_caller         uuid := auth.uid();
  v_entry          record;
  v_team           record;
  v_members        int;
  v_caller_team_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  SELECT * INTO v_entry
  FROM public.team_challenge_codes
  WHERE code = upper(trim(p_code)) AND status = 'active';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CODE_INVALID_OR_USED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  SELECT COUNT(*) INTO v_members FROM public.team_members WHERE team_id = v_entry.team_id;

  SELECT id INTO v_caller_team_id
  FROM public.teams WHERE captain_id = v_caller LIMIT 1;

  IF v_caller_team_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN');
  END IF;

  IF v_caller_team_id = v_entry.team_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM');
  END IF;

  RETURN jsonb_build_object(
    'success',              true,
    'opponent_team_id',     v_entry.team_id,
    'opponent_team_name',   v_team.name,
    'opponent_captain',     v_team.captain_name,
    'opponent_logo_url',    v_team.logo_url,
    'member_count',         v_members,
    'caller_team_id',       v_caller_team_id,
    'code_id',              v_entry.id
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.lookup_challenge_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lookup_challenge_code(text) TO authenticated;

-- 8. RPC: create_challenge_booking_atomic
CREATE OR REPLACE FUNCTION public.create_challenge_booking_atomic(
  p_challenge_code  text,
  p_stadium_id      text,
  p_start_time      timestamptz,
  p_end_time        timestamptz,
  p_payment_method  text    DEFAULT 'cash',
  p_rent_ball       boolean DEFAULT false,
  p_idempotency_key text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_caller           uuid := auth.uid();
  v_caller_team      record;
  v_code_entry       record;
  v_opponent_team    record;
  v_stadium          record;
  v_caller_members   int;
  v_opponent_members int;
  v_duration_hours   numeric;
  v_price            numeric;
  v_ball_price       numeric := 0;
  v_final_status     text;
  v_final_is_paid    boolean;
  v_locked_until     timestamptz;
  v_conflict_count   int;
  v_new_booking_id   uuid;
  v_new_code         text;
  v_new_code_id      uuid;
  v_existing_id      uuid;
  v_existing_status  text;
  v_now              timestamptz := timezone('utc', now());
BEGIN
  IF v_caller IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.bookings
    WHERE idempotency_key = p_idempotency_key AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true);
    END IF;
  END IF;

  SELECT t.* INTO v_caller_team FROM public.teams t WHERE t.captain_id = v_caller LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN');
  END IF;

  SELECT * INTO v_code_entry
  FROM public.team_challenge_codes
  WHERE code = upper(trim(p_challenge_code)) AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_INVALID_OR_USED');
  END IF;

  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM');
  END IF;

  SELECT COUNT(*) INTO v_caller_members FROM public.team_members WHERE team_id = v_caller_team.id;
  SELECT COUNT(*) INTO v_opponent_members FROM public.team_members WHERE team_id = v_opponent_team.id;

  IF v_caller_members < 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'YOUR_TEAM_NEEDS_5_MEMBERS', 'count', v_caller_members);
  END IF;
  IF v_opponent_members < 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NEEDS_5_MEMBERS', 'count', v_opponent_members);
  END IF;

  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TIME_RANGE');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_FOUND'); END IF;
  IF COALESCE(v_stadium.is_deleted_by_owner, false) THEN RETURN jsonb_build_object('success', false, 'error', 'STADIUM_DELETED'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE');
  END IF;

  v_price := ROUND(COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0) * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_price := v_price + v_ball_price;
  END IF;
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_PRICE_NOT_SET');
  END IF;

  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, 'cash')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status  := 'pending';
    v_final_is_paid := false;
    v_locked_until  := v_now + INTERVAL '5 minutes';
  ELSE
    v_final_status  := 'confirmed';
    v_final_is_paid := false;
    v_locked_until  := NULL;
  END IF;

  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type,
    total_price, platform_fee, vsp_commission, gateway_fee,
    stadium_name, stadium_image_url,
    is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids,
    locked_until, idempotency_key,
    created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, v_caller, v_caller, v_stadium.owner_id,
    p_start_time, p_end_time, 'challenge',
    v_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    true, p_rent_ball,
    COALESCE(v_stadium.needs_deposit, false),
    CASE WHEN COALESCE(v_stadium.needs_deposit, false) THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END,
    0,
    lower(COALESCE(p_payment_method, 'cash')), 'pending',
    v_final_status, v_final_is_paid,
    v_caller_team.id, v_caller_team.name,
    v_opponent_team.id, v_opponent_team.name,
    'confirmed',
    ARRAY[v_caller],
    v_locked_until, p_idempotency_key,
    v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  UPDATE public.team_challenge_codes
  SET status = 'used', used_at = v_now, used_in_booking_id = v_new_booking_id
  WHERE id = v_code_entry.id;

  v_new_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at)
  VALUES (v_opponent_team.id, v_new_code, 'active', v_now)
  RETURNING id INTO v_new_code_id;

  RETURN jsonb_build_object(
    'success',            true,
    'booking_id',         v_new_booking_id,
    'status',             v_final_status,
    'challenge_status',   'confirmed',
    'total_price',        v_price,
    'locked_until',       v_locked_until,
    'player_team_id',     v_caller_team.id,
    'player_team_name',   v_caller_team.name,
    'opponent_team_id',   v_opponent_team.id,
    'opponent_team_name', v_opponent_team.name,
    'new_opponent_code',  v_new_code
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من مستخدم آخر.');
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_challenge_booking_atomic(text, text, timestamptz, timestamptz, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_challenge_booking_atomic(text, text, timestamptz, timestamptz, text, boolean, text) TO authenticated;

-- 9. Upgrade protect_booking_sensitive_fields
CREATE OR REPLACE FUNCTION public.protect_booking_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_is_admin boolean := false;
BEGIN
  IF COALESCE(auth.role(), '') = 'service_role'
     OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin'))
  THEN RETURN NEW; END IF;

  IF current_setting('vsp.system_override', true) = 'true'
     OR current_setting('vsp.internal_payment_call', true) = 'true'
  THEN RETURN NEW; END IF;

  IF auth.uid() IS NOT NULL THEN
    SELECT (role IN ('admin', 'co_founder', 'cofounder', 'super_admin'))
    INTO v_is_admin FROM public.users WHERE id = auth.uid();
  END IF;
  IF COALESCE(v_is_admin, false) THEN RETURN NEW; END IF;

  IF OLD.stadium_id IS DISTINCT FROM NEW.stadium_id
     OR OLD.owner_id IS DISTINCT FROM NEW.owner_id
     OR OLD.user_id IS DISTINCT FROM NEW.user_id
     OR OLD.created_by_user_id IS DISTINCT FROM NEW.created_by_user_id
     OR OLD.start_time IS DISTINCT FROM NEW.start_time
     OR OLD.end_time IS DISTINCT FROM NEW.end_time
     OR OLD.booking_type IS DISTINCT FROM NEW.booking_type
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Booking core identity is server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_BOOKING_CORE_UPDATE'; END IF;

  IF OLD.status IS DISTINCT FROM NEW.status THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Booking status must be changed via atomic RPCs.'
      USING errcode='42501', detail='UNAUTHORIZED_STATUS_UPDATE';
  END IF;

  IF OLD.payment_status IS DISTINCT FROM NEW.payment_status
     OR OLD.is_paid IS DISTINCT FROM NEW.is_paid
     OR OLD.is_deposit_paid IS DISTINCT FROM NEW.is_deposit_paid
     OR OLD.deposit_paid IS DISTINCT FROM NEW.deposit_paid
     OR OLD.deposit_amount IS DISTINCT FROM NEW.deposit_amount
     OR OLD.payment_method IS DISTINCT FROM NEW.payment_method
     OR OLD.payment_transaction_id IS DISTINCT FROM NEW.payment_transaction_id
     OR OLD.paymob_txn_id IS DISTINCT FROM NEW.paymob_txn_id
     OR OLD.paymob_order_id IS DISTINCT FROM NEW.paymob_order_id
     OR OLD.paymob_transaction_id IS DISTINCT FROM NEW.paymob_transaction_id
     OR OLD.webhook_verified IS DISTINCT FROM NEW.webhook_verified
     OR OLD.webhook_processed_at IS DISTINCT FROM NEW.webhook_processed_at
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Payment state is managed by payment workflows only.'
    USING errcode='42501', detail='UNAUTHORIZED_PAYMENT_STATE_UPDATE'; END IF;

  IF OLD.total_price IS DISTINCT FROM NEW.total_price
     OR OLD.platform_fee IS DISTINCT FROM NEW.platform_fee
     OR OLD.vsp_commission IS DISTINCT FROM NEW.vsp_commission
     OR OLD.gateway_fee IS DISTINCT FROM NEW.gateway_fee
     OR OLD.refund_amount IS DISTINCT FROM NEW.refund_amount
     OR OLD.refund_transaction_id IS DISTINCT FROM NEW.refund_transaction_id
     OR OLD.refunded_at IS DISTINCT FROM NEW.refunded_at
     OR OLD.refund_payment_method IS DISTINCT FROM NEW.refund_payment_method
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Financial booking fields are immutable from the client.'
    USING errcode='42501', detail='UNAUTHORIZED_FINANCIAL_UPDATE'; END IF;

  IF OLD.cancelled_at IS DISTINCT FROM NEW.cancelled_at
     OR OLD.cancellation_reason IS DISTINCT FROM NEW.cancellation_reason
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Cancellation records are server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_CANCELLATION_UPDATE'; END IF;

  IF OLD.joined_user_ids IS DISTINCT FROM NEW.joined_user_ids
     OR OLD.current_players IS DISTINCT FROM NEW.current_players
     OR OLD.initial_players_count IS DISTINCT FROM NEW.initial_players_count
     OR OLD.total_field_capacity IS DISTINCT FROM NEW.total_field_capacity
     OR OLD.pending_user_ids IS DISTINCT FROM NEW.pending_user_ids
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Player list must be managed via join/leave RPCs.'
    USING errcode='42501', detail='UNAUTHORIZED_PLAYER_LIST_UPDATE'; END IF;

  IF OLD.player_team_id IS DISTINCT FROM NEW.player_team_id
     OR OLD.opponent_team_id IS DISTINCT FROM NEW.opponent_team_id
     OR OLD.challenge_status IS DISTINCT FROM NEW.challenge_status
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Challenge team fields are server-authoritative.'
    USING errcode='42501', detail='UNAUTHORIZED_CHALLENGE_TEAM_UPDATE'; END IF;

  IF OLD.match_result_status IS DISTINCT FROM NEW.match_result_status
     OR OLD.final_outcome IS DISTINCT FROM NEW.final_outcome
     OR OLD.pending_outcome IS DISTINCT FROM NEW.pending_outcome
     OR OLD.result_submitted_by_team_id IS DISTINCT FROM NEW.result_submitted_by_team_id
  THEN RAISE EXCEPTION 'PERMISSION_DENIED: Match result fields must be submitted via result RPCs.'
    USING errcode='42501', detail='UNAUTHORIZED_RESULT_UPDATE'; END IF;

  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_protect_booking_sensitive_fields ON public.bookings;
CREATE TRIGGER trg_protect_booking_sensitive_fields
  BEFORE UPDATE ON public.bookings FOR EACH ROW
  EXECUTE FUNCTION public.protect_booking_sensitive_fields();

-- 10. Upgrade create_booking_atomic: add p_initial_players + p_total_capacity
CREATE OR REPLACE FUNCTION public.create_booking_atomic(
  p_stadium_id         text,
  p_user_id            text,
  p_owner_id           text,
  p_start_time         timestamptz,
  p_end_time           timestamptz,
  p_booking_type       text,
  p_total_price        numeric,
  p_stadium_name       text    DEFAULT '',
  p_stadium_image_url  text    DEFAULT '',
  p_is_private         boolean DEFAULT true,
  p_rent_ball          boolean DEFAULT false,
  p_needs_deposit      boolean DEFAULT false,
  p_deposit_amount     numeric DEFAULT 0,
  p_payment_method     text    DEFAULT 'cash',
  p_payment_status     text    DEFAULT 'pending',
  p_player_team_id     text    DEFAULT NULL,
  p_player_team_name   text    DEFAULT NULL,
  p_opponent_team_id   text    DEFAULT NULL,
  p_opponent_team_name text    DEFAULT NULL,
  p_platform_fee       numeric DEFAULT 0,
  p_idempotency_key    text    DEFAULT NULL,
  p_initial_players    int     DEFAULT 1,
  p_total_capacity     int     DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_stadium              record;
  v_caller               uuid := auth.uid();
  v_caller_role          text;
  v_duration_hours       numeric;
  v_calculated_price     numeric;
  v_hourly_rate          numeric;
  v_ball_price           numeric := 0;
  v_final_total_price    numeric;
  v_final_needs_deposit  boolean;
  v_final_deposit_amount numeric;
  v_final_deposit_paid   numeric := 0;
  v_final_status         text;
  v_final_is_paid        boolean;
  v_locked_until         timestamptz;
  v_active_cash_count    int := 0;
  v_conflict_count       int := 0;
  v_user_blocked         boolean;
  v_no_show_count        int;
  v_new_booking_id       uuid;
  v_existing_id          uuid;
  v_existing_status      text;
  v_now                  timestamptz := timezone('utc', now());
  v_initial_players      int;
  v_capacity             int;
  v_normalized_type      text;
BEGIN
  v_normalized_type := CASE lower(COALESCE(p_booking_type, ''))
    WHEN 'personal'  THEN 'personal'
    WHEN 'open_join' THEN 'open_join'
    WHEN 'openjoin'  THEN 'open_join'
    WHEN 'challenge' THEN 'challenge'
    ELSE 'personal'
  END;

  IF v_normalized_type = 'challenge' THEN
    RETURN jsonb_build_object('success', false, 'error', 'USE_CHALLENGE_RPC',
      'message', 'حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.');
  END IF;

  IF v_caller IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  IF v_caller IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller;
    IF v_caller::text <> p_user_id
       AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin')
       AND current_user NOT IN ('postgres', 'service_role')
    THEN RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.'); END IF;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.bookings
    WHERE idempotency_key = p_idempotency_key AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success', true, 'booking_id', v_existing_id,
        'status', v_existing_status, 'idempotent', true);
    END IF;
  END IF;

  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.'); END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.'); END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.'); END IF;
  IF v_stadium.is_deleted_by_owner THEN RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف.'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id::text = p_user_id;
  IF COALESCE(v_user_blocked, false) THEN RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً.'); END IF;
  IF lower(COALESCE(p_payment_method, '')) = 'cash'
     AND v_no_show_count >= (SELECT cash_no_show_limit FROM public.platform_business_rules WHERE id = 1)
  THEN RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي. يرجى السداد إلكترونياً.'); END IF;

  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') AND end_time > v_now;
  IF lower(COALESCE(p_payment_method, '')) = 'cash' AND v_active_cash_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي قائم. يجب لعبه أولاً أو الدفع إلكترونياً.');
  END IF;

  v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
  v_final_deposit_amount := CASE WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END;

  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_calculated_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_calculated_price := v_calculated_price + v_ball_price;
  END IF;
  IF v_calculated_price <= 0 THEN RETURN jsonb_build_object('success', false, 'message', 'تسعيرة الملعب غير صحيحة.'); END IF;
  v_final_total_price := v_calculated_price;

  IF lower(COALESCE(p_payment_method, '')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status  := 'pending';
    v_final_is_paid := false;
    v_locked_until  := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status  := 'confirmed';
    v_final_is_paid := false;
    v_locked_until  := NULL;
  END IF;

  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;
  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  v_initial_players := CASE
    WHEN v_normalized_type = 'open_join' THEN GREATEST(1, LEAST(COALESCE(p_initial_players, 1), 50))
    ELSE 1
  END;
  v_capacity := CASE
    WHEN v_normalized_type = 'open_join' THEN GREATEST(v_initial_players, COALESCE(p_total_capacity, 10))
    ELSE NULL
  END;

  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type, total_price, vsp_commission, gateway_fee, platform_fee,
    stadium_name, stadium_image_url, is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key, created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, p_user_id::uuid, p_user_id::uuid, v_stadium.owner_id,
    p_start_time, p_end_time, v_normalized_type,
    v_final_total_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    p_is_private, p_rent_ball,
    v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
    lower(COALESCE(p_payment_method, 'cash')), 'pending', v_final_status, v_final_is_paid,
    CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
    p_player_team_name,
    CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
    p_opponent_team_name,
    ARRAY[p_user_id::uuid], v_initial_players, v_initial_players, v_capacity,
    v_locked_until, p_idempotency_key, v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success',             true,
    'booking_id',          v_new_booking_id,
    'status',              v_final_status,
    'total_price',         v_final_total_price,
    'needs_deposit',       v_final_needs_deposit,
    'deposit_amount',      v_final_deposit_amount,
    'initial_players',     v_initial_players,
    'requires_full_online', (v_active_cash_count > 0 AND lower(COALESCE(p_payment_method, '')) IN ('paymob', 'card', 'wallet', 'online')),
    'locked_until',        v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$fn$;

REVOKE ALL ON FUNCTION public.create_booking_atomic FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_booking_atomic TO authenticated, service_role;

-- 11. Upgrade request_join_public_match: enforce open_join type
CREATE OR REPLACE FUNCTION public.request_join_public_match(p_booking_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_booking       record;
  v_user_conflict int;
  v_user_blocked  boolean;
  v_capacity      int;
  v_booking_uuid  uuid;
  v_user_uuid     uuid;
  v_now           timestamptz := timezone('utc', now());
BEGIN
  BEGIN
    v_booking_uuid := p_booking_id::uuid;
    v_user_uuid    := p_user_id::uuid;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'INVALID_UUID_FORMAT' USING ERRCODE = '22P02';
  END;

  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF auth.uid() IS NULL OR auth.uid() <> v_user_uuid THEN
      RAISE EXCEPTION 'PERMISSION_DENIED' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_uuid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'match_not_found'; END IF;

  -- SSOT gate: only open_join bookings allow joining
  IF COALESCE(v_booking.booking_type, '') <> 'open_join' THEN
    RAISE EXCEPTION 'not_an_open_join_match';
  END IF;

  IF v_booking.is_private IS TRUE THEN RAISE EXCEPTION 'match_not_public'; END IF;
  IF v_booking.status = 'cancelled' THEN RAISE EXCEPTION 'match_cancelled'; END IF;
  IF v_booking.status = 'completed' THEN RAISE EXCEPTION 'match_already_completed'; END IF;
  IF v_booking.end_time <= v_now THEN RAISE EXCEPTION 'match_expired'; END IF;

  SELECT is_blocked INTO v_user_blocked FROM public.users WHERE id = v_user_uuid;
  IF v_user_blocked IS TRUE THEN RAISE EXCEPTION 'user_blocked'; END IF;

  v_capacity := COALESCE(v_booking.total_field_capacity, v_booking.max_players, 10);
  IF COALESCE(v_booking.current_players, 0) >= v_capacity THEN RAISE EXCEPTION 'match_is_full'; END IF;

  IF v_user_uuid = ANY(COALESCE(v_booking.joined_user_ids, ARRAY[]::uuid[]))
     OR v_booking.created_by_user_id = v_user_uuid THEN
    RAISE EXCEPTION 'already_joined';
  END IF;

  SELECT COUNT(*) INTO v_user_conflict
  FROM public.bookings
  WHERE status <> 'cancelled' AND id <> v_booking_uuid
    AND (created_by_user_id = v_user_uuid OR v_user_uuid = ANY(COALESCE(joined_user_ids, ARRAY[]::uuid[])))
    AND start_time < v_booking.end_time AND end_time > v_booking.start_time;
  IF v_user_conflict > 0 THEN RAISE EXCEPTION 'time_conflict'; END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET joined_user_ids = array_append(COALESCE(joined_user_ids, ARRAY[]::uuid[]), v_user_uuid),
      current_players = COALESCE(current_players, 0) + 1,
      updated_at = v_now
  WHERE id = v_booking_uuid;

  RETURN jsonb_build_object(
    'success',         true,
    'booking_id',      p_booking_id,
    'current_players', COALESCE(v_booking.current_players, 0) + 1,
    'host_user_id',    v_booking.created_by_user_id
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.request_join_public_match(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_join_public_match(text, text) TO authenticated;

-- 12. Upgrade leave_public_match_atomic: block post-match exit
CREATE OR REPLACE FUNCTION public.leave_public_match_atomic(p_booking_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_booking record;
  v_now     timestamptz := timezone('utc', now());
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
      RAISE EXCEPTION 'Unauthorized: You can only leave matches on your own behalf.';
    END IF;
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;

  IF v_booking.status IN ('completed', 'cancelled', 'expired') THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a % booking.', v_booking.status;
  END IF;

  IF v_booking.end_time <= v_now THEN
    RAISE EXCEPTION 'LEAVE_BLOCKED: Cannot leave a match that has already ended.';
  END IF;

  IF NOT (p_user_id = ANY(v_booking.joined_user_ids)) THEN
    RAISE EXCEPTION 'User is not a joined participant in this match';
  END IF;

  IF v_booking.created_by_user_id = p_user_id THEN
    RAISE EXCEPTION 'HOST_CANNOT_LEAVE: The host cannot leave. Cancel the booking instead.';
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  UPDATE public.bookings
  SET current_players = GREATEST(0, current_players - 1),
      joined_user_ids = array_remove(joined_user_ids, p_user_id),
      updated_at = v_now
  WHERE id = p_booking_id;

  RETURN true;
END;
$fn$;

REVOKE ALL ON FUNCTION public.leave_public_match_atomic(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_public_match_atomic(uuid, uuid) TO authenticated;

-- 13. Seed active challenge codes for existing teams that lack one
DO $$
DECLARE
  r     record;
  v_code text;
BEGIN
  FOR r IN
    SELECT t.id AS team_id
    FROM public.teams t
    WHERE NOT EXISTS (
      SELECT 1 FROM public.team_challenge_codes c
      WHERE c.team_id = t.id AND c.status = 'active'
    )
  LOOP
    v_code := 'VSP-' || upper(substring(md5(r.team_id::text || random()::text), 1, 5));
    BEGIN
      INSERT INTO public.team_challenge_codes(team_id, code, status)
      VALUES (r.team_id, v_code, 'active')
      ON CONFLICT (code) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- skip on any unexpected error; cron/manual refresh will handle it
    END;
  END LOOP;
END;
$$;
