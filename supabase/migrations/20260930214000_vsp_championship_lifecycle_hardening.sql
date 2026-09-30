-- ============================================================
-- MIGRATION: 20260930214000_vsp_championship_lifecycle_hardening
-- DATE     : 2026-09-30
--
-- FIXES:
--   1. Async Refund Obligations: cancel_championship_atomic marks
--      orders 'refund_requested' without blocking on Paymob.
--   2. Finalize Cancellation Refund: finalize_championship_cancellation_refund_atomic
--      handles Paymob callback (success -> refunded, fail -> refund_failed_manual_review).
--   3. Historical Delete Guard: checks all historical orders, payments,
--      matches, rosters, audits, and transactions before delete.
--   4. Explicit No-op Rejection: update_championship_atomic returns
--      success=false + code=NO_EDITABLE_FIELDS if only locked fields sent.
--   5. Unified SSOT: Admin respects lifecycle competition rules (no structure bypass).
--   6. Status Transition SSOT: transition_championship_status_atomic
--      replaces direct table updates.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. get_championship_actions (Enhanced with complete historical proof)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_championship_actions(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_champ             RECORD;
  v_user_id           UUID    := auth.uid();
  v_is_owner          BOOLEAN := false;
  v_is_admin          BOOLEAN := false;
  v_is_tl             BOOLEAN := false;
  v_teams_current     INTEGER := 0;
  v_matches_count     INTEGER := 0;
  v_paid_orders_count INTEGER := 0;
  v_has_history       BOOLEAN := false;
  -- Outputs
  v_can_edit          BOOLEAN := false;
  v_can_basic         BOOLEAN := false;
  v_can_structure     BOOLEAN := false;
  v_can_cancel        BOOLEAN := false;
  v_can_delete        BOOLEAN := false;
  v_reason            TEXT    := '';
  v_locked            TEXT[]  := ARRAY[]::TEXT[];
  v_editable          TEXT[]  := ARRAY[]::TEXT[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  -- Identity
  v_is_owner := (v_champ.owner_id = v_user_id);
  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND role IN ('admin','co_founder','super_admin','cofounder')
  ) INTO v_is_admin;
  v_is_tl := COALESCE(v_champ.template_type, '') = 'team_league';

  -- Non-owner & non-admin -> no permissions
  IF NOT v_is_owner AND NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'can_edit', false, 'can_edit_basic_info', false,
      'can_edit_structure', false, 'can_cancel', false,
      'can_delete', false, 'reason', 'not_authorized',
      'teams_count', 0, 'matches_count', 0, 'is_team_league', v_is_tl
    );
  END IF;

  -- Current active counts
  v_teams_current := COALESCE(array_length(v_champ.joined_teams, 1), 0);

  SELECT COUNT(*) INTO v_matches_count
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  SELECT COUNT(*) INTO v_paid_orders_count
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id AND payment_status IN ('paid', 'refund_requested');

  IF v_is_tl THEN
    SELECT v_paid_orders_count + COUNT(*) INTO v_paid_orders_count
    FROM public.team_league_payments
    WHERE championship_id = p_championship_id AND payment_status IN ('paid', 'refund_requested');
  END IF;

  -- ============================================================
  -- Historical Proof Check: Has this tournament EVER had ANY activity?
  -- Used strictly for delete permission.
  -- ============================================================
  v_has_history := (
    v_teams_current > 0 OR
    COALESCE(array_length(v_champ.paid_teams, 1), 0) > 0 OR
    v_matches_count > 0 OR
    EXISTS(SELECT 1 FROM public.championship_rosters WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.tournament_orders WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.team_league_payments WHERE championship_id = p_championship_id) OR
    EXISTS(SELECT 1 FROM public.financial_audit_logs WHERE (metadata->>'championship_id')::text = p_championship_id::text) OR
    EXISTS(SELECT 1 FROM public.transactions WHERE (metadata->>'championship_id')::text = p_championship_id::text)
  );

  -- ── State Machine ─────────────────────────────────────────
  IF v_champ.status = 'open' THEN
    IF NOT v_has_history THEN
      -- PRISTINE OPEN (No teams, no history, no orders)
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := NOT v_is_tl; -- Team League structure always locked
      v_can_cancel    := true;
      v_can_delete    := true;
      v_reason        := 'pre_registration';
      v_editable := CASE WHEN v_is_tl
        THEN ARRAY['name','logo_url','governorate','rules','start_date','end_date']
        ELSE ARRAY['name','logo_url','governorate','rules','start_date','end_date',
                   'entry_fee','grand_prize','max_teams','max_players_per_team',
                   'min_players_per_team','match_duration','type','number_of_groups',
                   'qualifying_per_group','is_two_legs','is_back_and_forth',
                   'winning_points','draw_points','loss_points']
      END;

    ELSIF v_matches_count = 0 THEN
      -- REGISTRATION STARTED OR HISTORICAL ACTIVITY EXISTS (matches not yet generated)
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := true;
      v_can_delete    := false; -- Locked by historical record
      v_reason        := 'registration_started';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','max_players_per_team',
                          'min_players_per_team','type','number_of_groups',
                          'qualifying_per_group','is_two_legs','is_back_and_forth',
                          'winning_points','draw_points','loss_points','start_date','end_date'];

    ELSE
      -- FIXTURES GENERATED
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := false;
      v_can_delete    := false;
      v_reason        := 'fixtures_generated';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','type',
                          'number_of_groups','qualifying_per_group','is_two_legs',
                          'winning_points','draw_points','loss_points','start_date','end_date'];
    END IF;

  ELSIF v_champ.status = 'ongoing' THEN
    v_can_edit      := true;
    v_can_basic     := true;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'competition_in_progress';
    v_editable := ARRAY['logo_url','rules'];
    v_locked   := ARRAY['entry_fee','grand_prize','max_teams','type',
                        'number_of_groups','start_date','end_date','winning_points',
                        'draw_points','loss_points','name'];

  ELSIF v_champ.status = 'completed' THEN
    v_can_edit      := false;
    v_can_basic     := false;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'competition_completed';

  ELSIF v_champ.status = 'cancelled' THEN
    v_can_edit      := false;
    v_can_basic     := false;
    v_can_structure := false;
    v_can_cancel    := false;
    v_can_delete    := false;
    v_reason        := 'already_cancelled';

  ELSE
    v_reason := 'unknown_status_' || COALESCE(v_champ.status,'null');
  END IF;

  RETURN jsonb_build_object(
    'can_edit',            v_can_edit,
    'can_edit_basic_info',  v_can_basic,
    'can_edit_structure',   v_can_structure,
    'can_cancel',          v_can_cancel,
    'can_delete',          v_can_delete,
    'reason',              v_reason,
    'editable_fields',     to_jsonb(v_editable),
    'locked_fields',       to_jsonb(v_locked),
    'teams_count',         v_teams_current,
    'matches_count',       v_matches_count,
    'paid_orders_count',   v_paid_orders_count,
    'has_history',         v_has_history,
    'is_team_league',      v_is_tl
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.get_championship_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_championship_actions(uuid) TO authenticated;


-- ============================================================
-- 2. update_championship_atomic (Explicit Rejection + Unified SSOT)
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_championship_atomic(
  p_championship_id uuid,
  p_updates         jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actions      JSONB;
  v_user_id      UUID := auth.uid();
  v_editable     TEXT[];
  v_key          TEXT;
  v_safe_updates JSONB := '{}'::JSONB;
  v_blocked_keys TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get authoritative actions from SSOT
  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_edit')::boolean AND NOT (v_actions->>'can_edit_basic_info')::boolean THEN
    RETURN jsonb_build_object(
      'success', false,
      'code',    'BLOCKED_BY_STATE',
      'reason',  v_actions->>'reason',
      'message', 'تعديل البطولة غير متاح في حالتها الحالية'
    );
  END IF;

  SELECT ARRAY(SELECT jsonb_array_elements_text(v_actions->'editable_fields')) INTO v_editable;

  -- Filter requested updates against editable fields (No admin bypass)
  FOR v_key IN SELECT jsonb_object_keys(p_updates)
  LOOP
    IF v_key = ANY(v_editable) THEN
      v_safe_updates := v_safe_updates || jsonb_build_object(v_key, p_updates->v_key);
    ELSE
      v_blocked_keys := array_append(v_blocked_keys, v_key);
    END IF;
  END LOOP;

  -- EXPLICIT REJECTION: If no allowed fields in updates, fail explicitly!
  IF v_safe_updates = '{}'::JSONB THEN
    RETURN jsonb_build_object(
      'success',        false,
      'code',           'NO_EDITABLE_FIELDS',
      'reason',         v_actions->>'reason',
      'blocked_fields', to_jsonb(v_blocked_keys),
      'message',        'التعديلات المطلوبة مقفولة في هذه المرحلة من البطولة'
    );
  END IF;

  v_safe_updates := v_safe_updates || jsonb_build_object('updated_at', now());

  UPDATE public.championships
  SET
    name                 = COALESCE((v_safe_updates->>'name')::TEXT,                 name),
    logo_url             = COALESCE((v_safe_updates->>'logo_url')::TEXT,             logo_url),
    rules                = COALESCE((v_safe_updates->>'rules')::TEXT,                rules),
    governorate          = COALESCE((v_safe_updates->>'governorate')::TEXT,          governorate),
    start_date           = COALESCE((v_safe_updates->>'start_date')::TIMESTAMPTZ,    start_date),
    end_date             = COALESCE((v_safe_updates->>'end_date')::TIMESTAMPTZ,      end_date),
    entry_fee            = COALESCE((v_safe_updates->>'entry_fee')::NUMERIC,         entry_fee),
    grand_prize          = COALESCE((v_safe_updates->>'grand_prize')::NUMERIC,       grand_prize),
    max_teams            = COALESCE((v_safe_updates->>'max_teams')::INTEGER,         max_teams),
    max_players_per_team = COALESCE((v_safe_updates->>'max_players_per_team')::INT,  max_players_per_team),
    min_players_per_team = COALESCE((v_safe_updates->>'min_players_per_team')::INT,  min_players_per_team),
    match_duration       = COALESCE((v_safe_updates->>'match_duration')::INTEGER,    match_duration),
    number_of_groups     = COALESCE((v_safe_updates->>'number_of_groups')::INTEGER,  number_of_groups),
    qualifying_per_group = COALESCE((v_safe_updates->>'qualifying_per_group')::INT,  qualifying_per_group),
    is_two_legs          = COALESCE((v_safe_updates->>'is_two_legs')::BOOLEAN,       is_two_legs),
    is_back_and_forth    = COALESCE((v_safe_updates->>'is_back_and_forth')::BOOLEAN, is_back_and_forth),
    winning_points       = COALESCE((v_safe_updates->>'winning_points')::INTEGER,    winning_points),
    draw_points          = COALESCE((v_safe_updates->>'draw_points')::INTEGER,       draw_points),
    loss_points          = COALESCE((v_safe_updates->>'loss_points')::INTEGER,       loss_points),
    updated_at           = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success',        true,
    'updated_fields', to_jsonb(ARRAY(SELECT jsonb_object_keys(v_safe_updates))),
    'blocked_fields', to_jsonb(v_blocked_keys),
    'allowed_reason', v_actions->>'reason'
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.update_championship_atomic(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_championship_atomic(uuid, jsonb) TO authenticated;


-- ============================================================
-- 3. cancel_championship_atomic (Async Obligations Architecture)
-- ============================================================
CREATE OR REPLACE FUNCTION public.cancel_championship_atomic(
  p_championship_id uuid,
  p_reason          text DEFAULT 'owner_initiated'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actions           JSONB;
  v_champ             RECORD;
  v_user_id           UUID := auth.uid();
  v_is_tl             BOOLEAN;
  v_obligations_count INTEGER := 0;
  v_orders_list       JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_cancel')::boolean THEN
    RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot cancel championship in current state. Reason: %',
      v_actions->>'reason';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  v_is_tl := COALESCE(v_champ.template_type, '') = 'team_league';

  IF v_is_tl THEN
    -- Route to team league cancel RPC
    RETURN public.cancel_team_league(p_championship_id);
  END IF;

  -- 1. Create refund obligations for all paid orders: mark 'refund_requested'
  UPDATE public.tournament_orders
  SET payment_status = 'refund_requested',
      updated_at     = now()
  WHERE championship_id = p_championship_id
    AND payment_status  = 'paid';

  GET DIAGNOSTICS v_obligations_count = ROW_COUNT;

  -- Collect obligations list for the async executor
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'order_reference', order_reference,
    'team_id', team_id,
    'captain_user_id', captain_user_id,
    'amount', amount,
    'paymob_transaction_id', paymob_transaction_id
  )), '[]'::JSONB) INTO v_orders_list
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id
    AND payment_status = 'refund_requested';

  -- 2. Transition championship to cancelled
  UPDATE public.championships
  SET status     = 'cancelled',
      updated_at = now()
  WHERE id = p_championship_id;

  -- 3. Audit trail
  INSERT INTO public.financial_audit_logs (
    action_type, owner_id, user_id, amount, fee, metadata, created_at
  ) VALUES (
    'championship_cancelled',
    v_champ.owner_id,
    v_user_id,
    0,
    0,
    jsonb_build_object(
      'championship_id',          p_championship_id,
      'reason',                   p_reason,
      'teams_count',              v_actions->'teams_count',
      'refund_obligations_count', v_obligations_count
    ),
    now()
  );

  RETURN jsonb_build_object(
    'success',                  true,
    'championship_id',          p_championship_id,
    'status',                   'cancelled',
    'refund_obligations_count', v_obligations_count,
    'refund_orders',            v_orders_list,
    'reason',                   p_reason
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.cancel_championship_atomic(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_championship_atomic(uuid, text) TO authenticated;


-- ============================================================
-- 4. finalize_championship_cancellation_refund_atomic
-- Called by Edge Function during async Paymob processing.
-- ============================================================
CREATE OR REPLACE FUNCTION public.finalize_championship_cancellation_refund_atomic(
  p_championship_id  uuid,
  p_order_reference  text,
  p_refund_success   boolean,
  p_refund_txn_id    text DEFAULT NULL,
  p_error_message    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_order    RECORD;
  v_champ    RECORD;
  v_now      TIMESTAMPTZ := now();
BEGIN
  IF current_user NOT IN ('postgres','service_role') AND COALESCE(auth.role(),'') <> 'service_role' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order
  FROM public.tournament_orders
  WHERE order_reference = p_order_reference AND championship_id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;

  IF p_refund_success THEN
    UPDATE public.tournament_orders
    SET payment_status = 'refunded',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    -- Record completed refund transaction
    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'completed',
      'استرداد رسوم اشتراك بطولة ملغاة: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id',        p_championship_id,
        'order_reference',        p_order_reference,
        'original_paymob_txn_id', v_order.paymob_transaction_id,
        'paymob_refund_id',       p_refund_txn_id,
        'amount',                 v_order.amount
      ),
      v_now, v_now
    );

    -- Financial audit log
    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'cancellation_refund_completed',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_refund_txn_id,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'status', 'refunded'
      ),
      v_now
    );

    RETURN jsonb_build_object('success', true, 'status', 'refunded', 'order_reference', p_order_reference);

  ELSE
    -- Refund failed with Paymob: flag for urgent manual admin review
    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'failed',
      'تعذر استرداد رسوم اشتراك بطولة ملغاة تلقائياً: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now, v_now
    );

    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'refund_failed_manual_review',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_order_reference,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now
    );

    RETURN jsonb_build_object('success', false, 'status', 'refund_failed_manual_review', 'error', p_error_message);
  END IF;
END;
$$;

REVOKE ALL    ON FUNCTION public.finalize_championship_cancellation_refund_atomic(uuid, text, boolean, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.finalize_championship_cancellation_refund_atomic(uuid, text, boolean, text, text) TO service_role;


-- ============================================================
-- 5. delete_championship_atomic (Historical Proof Enforcement)
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_championship_atomic(
  p_championship_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actions     JSONB;
  v_has_history BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_delete')::boolean THEN
    RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot delete championship. Active teams or historical records exist. Reason: %',
      v_actions->>'reason';
  END IF;

  -- Clean up any empty roster headers if they exist
  DELETE FROM public.championship_rosters WHERE championship_id = p_championship_id;

  -- Hard delete the pristine championship
  DELETE FROM public.championships WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success',         true,
    'championship_id', p_championship_id,
    'message',         'Championship permanently deleted'
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.delete_championship_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_championship_atomic(uuid) TO authenticated;


-- ============================================================
-- 6. transition_championship_status_atomic (State Machine SSOT)
-- Eliminates direct table update backdoors.
-- ============================================================
CREATE OR REPLACE FUNCTION public.transition_championship_status_atomic(
  p_championship_id uuid,
  p_new_status      text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_champ         RECORD;
  v_user_id       UUID := auth.uid();
  v_is_owner      BOOLEAN;
  v_is_admin      BOOLEAN;
  v_matches_count INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Championship not found';
  END IF;

  v_is_owner := (v_champ.owner_id = v_user_id);
  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND role IN ('admin','co_founder','super_admin','cofounder')
  ) INTO v_is_admin;

  IF NOT v_is_owner AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: only owner or admin can transition championship status';
  END IF;

  IF p_new_status = 'cancelled' THEN
    RAISE EXCEPTION 'Cancellation must go through cancel_championship_atomic';
  END IF;

  IF v_champ.status = p_new_status THEN
    RETURN jsonb_build_object('success', true, 'status', p_new_status, 'message', 'Already in requested status');
  END IF;

  -- Transition Guard:
  -- open -> ongoing: MUST have fixtures generated
  IF v_champ.status = 'open' AND p_new_status = 'ongoing' THEN
    SELECT COUNT(*) INTO v_matches_count
    FROM public.tournament_matches
    WHERE championship_id = p_championship_id;

    IF v_matches_count = 0 THEN
      RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot transition to ongoing without generated fixtures';
    END IF;

  -- ongoing -> completed: allowed
  ELSIF v_champ.status = 'ongoing' AND p_new_status = 'completed' THEN
    NULL;

  ELSE
    RAISE EXCEPTION 'INVALID_TRANSITION: Cannot transition championship from % to %',
      v_champ.status, p_new_status;
  END IF;

  UPDATE public.championships
  SET status     = p_new_status,
      updated_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

REVOKE ALL    ON FUNCTION public.transition_championship_status_atomic(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transition_championship_status_atomic(uuid, text) TO authenticated;

COMMIT;
