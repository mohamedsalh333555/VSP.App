-- ============================================================
-- MIGRATION: 20260930090000_vsp_championship_lifecycle_policy
-- DATE     : 2026-09-30
--
-- IMPLEMENTS:
--   Phase 1: get_championship_actions   → Policy SSOT (what's allowed & why)
--   Phase 2: update_championship_atomic → State-gated safe edit
--   Phase 3: cancel_championship_atomic → Cancel with audit (routes to cancel_team_league for TL)
--   Phase 4: delete_championship_atomic → Hard delete ONLY when pre-participation
--   Phase 5: protect_championship_sensitive_fields → Add fixture-existence guard
--
-- STATE MACHINE:
--   open (0 teams) → open (1+ teams) → ongoing → completed
--   open → cancelled
--   (delete only from open + 0 teams + 0 matches + 0 payments)
-- ============================================================

BEGIN;

-- ============================================================
-- PHASE 1: get_championship_actions
-- The single source of truth for what any caller is allowed to do.
-- Flutter + any other surface calls this FIRST, then acts accordingly.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_championship_actions(p_championship_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_champ         RECORD;
  v_user_id       UUID    := auth.uid();
  v_is_owner      BOOLEAN := false;
  v_is_admin      BOOLEAN := false;
  v_is_tl         BOOLEAN := false;
  v_teams         INTEGER := 0;
  v_matches       INTEGER := 0;
  v_payments      INTEGER := 0;
  -- Outputs
  v_can_edit      BOOLEAN := false;
  v_can_basic     BOOLEAN := false;
  v_can_structure BOOLEAN := false;
  v_can_cancel    BOOLEAN := false;
  v_can_delete    BOOLEAN := false;
  v_reason        TEXT    := '';
  v_locked        TEXT[]  := ARRAY[]::TEXT[];
  v_editable      TEXT[]  := ARRAY[]::TEXT[];
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

  -- Non-owner & non-admin → no permissions
  IF NOT v_is_owner AND NOT v_is_admin THEN
    RETURN jsonb_build_object(
      'can_edit', false, 'can_edit_basic_info', false,
      'can_edit_structure', false, 'can_cancel', false,
      'can_delete', false, 'reason', 'not_authorized',
      'teams_count', 0, 'matches_count', 0, 'is_team_league', v_is_tl
    );
  END IF;

  -- Participation counts
  v_teams := COALESCE(array_length(v_champ.joined_teams, 1), 0);

  SELECT COUNT(*) INTO v_matches
  FROM public.tournament_matches
  WHERE championship_id = p_championship_id;

  SELECT COUNT(*) INTO v_payments
  FROM public.tournament_orders
  WHERE championship_id = p_championship_id AND payment_status = 'paid';

  -- For team_league, also count league payments
  IF v_is_tl THEN
    SELECT v_payments + COUNT(*) INTO v_payments
    FROM public.team_league_payments
    WHERE championship_id = p_championship_id AND payment_status = 'paid';
  END IF;

  -- ── State Machine ─────────────────────────────────────────
  IF v_champ.status = 'open' THEN
    IF v_teams = 0 AND v_matches = 0 AND v_payments = 0 THEN
      -- PRE-REGISTRATION: full freedom
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

    ELSIF v_teams > 0 AND v_matches = 0 THEN
      -- REGISTRATION STARTED: structure locked, basic edits allowed
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := true;
      v_can_delete    := false;
      v_reason        := 'registration_started';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','max_players_per_team',
                          'min_players_per_team','type','number_of_groups',
                          'qualifying_per_group','is_two_legs','is_back_and_forth',
                          'winning_points','draw_points','loss_points'];

    ELSIF v_matches > 0 THEN
      -- FIXTURES GENERATED: structure fully locked, no cancel/delete
      v_can_edit      := true;
      v_can_basic     := true;
      v_can_structure := false;
      v_can_cancel    := false;
      v_can_delete    := false;
      v_reason        := 'fixtures_generated';
      v_editable := ARRAY['name','logo_url','rules'];
      v_locked   := ARRAY['entry_fee','grand_prize','max_teams','type',
                          'number_of_groups','qualifying_per_group','is_two_legs',
                          'winning_points','draw_points','loss_points'];
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
                        'number_of_groups','start_date','winning_points',
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

  -- Admin override: can always edit basic info (but NOT structural after registration)
  IF v_is_admin THEN
    v_can_basic := v_can_basic OR (v_champ.status NOT IN ('cancelled'));
  END IF;

  RETURN jsonb_build_object(
    'can_edit',           v_can_edit,
    'can_edit_basic_info', v_can_basic,
    'can_edit_structure', v_can_structure,
    'can_cancel',         v_can_cancel,
    'can_delete',         v_can_delete,
    'reason',             v_reason,
    'editable_fields',    to_jsonb(v_editable),
    'locked_fields',      to_jsonb(v_locked),
    'teams_count',        v_teams,
    'matches_count',      v_matches,
    'payments_count',     v_payments,
    'is_team_league',     v_is_tl
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.get_championship_actions(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_championship_actions(uuid) TO authenticated;


-- ============================================================
-- PHASE 2: update_championship_atomic
-- Validates state, strips disallowed fields, applies allowed updates only.
-- All edit paths must go through here — no more direct .update().
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
  v_is_admin     BOOLEAN := false;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get allowed actions for this championship
  v_actions := public.get_championship_actions(p_championship_id);

  -- Must be allowed to edit
  IF NOT (v_actions->>'can_edit')::boolean AND NOT (v_actions->>'can_edit_basic_info')::boolean THEN
    RAISE EXCEPTION 'BLOCKED_BY_STATE: Championship editing is not allowed. Reason: %',
      v_actions->>'reason';
  END IF;

  -- Build the list of editable fields
  SELECT ARRAY(SELECT jsonb_array_elements_text(v_actions->'editable_fields')) INTO v_editable;

  SELECT EXISTS(
    SELECT 1 FROM public.users
    WHERE id = v_user_id AND role IN ('admin','co_founder','super_admin','cofounder')
  ) INTO v_is_admin;

  -- Strip any field NOT in the editable list (server enforces, not just UI)
  FOR v_key IN SELECT jsonb_object_keys(p_updates)
  LOOP
    IF v_key = ANY(v_editable) OR v_is_admin THEN
      v_safe_updates := v_safe_updates || jsonb_build_object(v_key, p_updates->v_key);
    END IF;
    -- Silently drop disallowed fields (no error — Flutter might pass extra fields)
  END LOOP;

  -- Nothing valid to update
  IF v_safe_updates = '{}'::JSONB THEN
    RETURN jsonb_build_object(
      'success', true,
      'updated_fields', '[]'::JSONB,
      'message', 'No allowed fields in request'
    );
  END IF;

  -- Add updated_at timestamp
  v_safe_updates := v_safe_updates || jsonb_build_object('updated_at', now());

  -- Apply the update
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
    'allowed_reason', v_actions->>'reason'
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.update_championship_atomic(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_championship_atomic(uuid, jsonb) TO authenticated;


-- ============================================================
-- PHASE 3: cancel_championship_atomic
-- Validates cancellability, sets status=cancelled, audit log.
-- For Team League: routes to cancel_team_league which handles refunds.
-- For regular: marks cancelled + marks pending refunds in tournament_orders.
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
  v_actions JSONB;
  v_champ   RECORD;
  v_user_id UUID := auth.uid();
  v_is_tl   BOOLEAN;
  v_refunded_count INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_actions := public.get_championship_actions(p_championship_id);

  IF NOT (v_actions->>'can_cancel')::boolean THEN
    RAISE EXCEPTION 'BLOCKED_BY_STATE: Cannot cancel championship in current state. Reason: %',
      v_actions->>'reason';
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;
  v_is_tl := COALESCE(v_champ.template_type, '') = 'team_league';

  IF v_is_tl THEN
    -- Route to existing cancel_team_league which already handles payments/refunds
    RETURN public.cancel_team_league(p_championship_id);
  END IF;

  -- Regular tournament cancellation
  -- 1. Mark all pending tournament_orders as refund_pending
  UPDATE public.tournament_orders
  SET payment_status = 'refund_pending',
      updated_at     = now()
  WHERE championship_id = p_championship_id
    AND payment_status  = 'paid';

  GET DIAGNOSTICS v_refunded_count = ROW_COUNT;

  -- 2. Set championship status to cancelled
  UPDATE public.championships
  SET status     = 'cancelled',
      updated_at = now()
  WHERE id = p_championship_id;

  -- 3. Audit
  INSERT INTO public.financial_audit_logs (
    event_type, championship_id, user_id, amount, metadata, created_at
  ) VALUES (
    'championship_cancelled',
    p_championship_id,
    v_user_id,
    0,
    jsonb_build_object(
      'reason',           p_reason,
      'teams_count',      v_actions->'teams_count',
      'payments_pending_refund', v_refunded_count
    ),
    now()
  ) ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'success',              true,
    'championship_id',      p_championship_id,
    'status',               'cancelled',
    'refund_orders_queued', v_refunded_count,
    'reason',               p_reason
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.cancel_championship_atomic(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_championship_atomic(uuid, text) TO authenticated;


-- ============================================================
-- PHASE 4: delete_championship_atomic
-- Hard delete ONLY allowed when:
--   status = 'open' AND teams = 0 AND matches = 0 AND payments = 0
-- Cleans up rosters + matches before deleting.
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
  v_actions JSONB;
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_actions := public.get_championship_actions(p_championship_id);

  -- Server enforces: can_delete must be true
  IF NOT (v_actions->>'can_delete')::boolean THEN
    RAISE EXCEPTION
      'BLOCKED_BY_STATE: Cannot delete championship. Reason: %. Teams: %, Matches: %, Payments: %',
      v_actions->>'reason',
      v_actions->>'teams_count',
      v_actions->>'matches_count',
      v_actions->>'payments_count';
  END IF;

  -- Clean up rosters (safe: these only exist in pre-registration)
  DELETE FROM public.championship_roster_players
  WHERE roster_id IN (
    SELECT id FROM public.championship_rosters WHERE championship_id = p_championship_id
  );

  DELETE FROM public.championship_roster_guests
  WHERE roster_id IN (
    SELECT id FROM public.championship_rosters WHERE championship_id = p_championship_id
  );

  DELETE FROM public.championship_rosters WHERE championship_id = p_championship_id;

  -- Clean up any orphan matches (should be 0 at this point, but defensive)
  DELETE FROM public.tournament_matches WHERE championship_id = p_championship_id;

  -- Delete the championship itself
  DELETE FROM public.championships WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success',         true,
    'championship_id', p_championship_id,
    'action',          'permanent_delete'
  );
END;
$$;

REVOKE ALL    ON FUNCTION public.delete_championship_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_championship_atomic(uuid) TO authenticated;


-- ============================================================
-- PHASE 5: Enhance protect_championship_sensitive_fields
-- ADD: block structural changes when tournament_matches exist.
-- This closes the gap where matches existed but trigger only checked teams.
-- ============================================================
CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller_role   TEXT;
  v_has_participants BOOLEAN := false;
  v_has_fixtures     BOOLEAN := false;
BEGIN
  -- Service role and postgres bypass (internal operations)
  IF current_user IN ('postgres','service_role') THEN
    RETURN NEW;
  END IF;

  -- Admin roles bypass
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin','co_founder','super_admin','cofounder') THEN
    RETURN NEW;
  END IF;

  -- INSERT: block pre-approved or pre-paid-fee flags
  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.is_approved, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Non-admin users cannot create pre-approved championships.';
    END IF;
    IF COALESCE(NEW.creation_fee_paid, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Creation fee status is server-authoritative.';
    END IF;
    RETURN NEW;
  END IF;

  -- UPDATE: check participation and fixture state
  v_has_participants := (
    cardinality(COALESCE(OLD.paid_teams,   ARRAY[]::TEXT[])) > 0 OR
    cardinality(COALESCE(OLD.joined_teams, ARRAY[]::TEXT[])) > 0 OR
    OLD.registration_locked_at IS NOT NULL
  );

  -- NEW: check if fixtures exist (blocks structural changes even if teams left)
  SELECT EXISTS(
    SELECT 1 FROM public.tournament_matches WHERE championship_id = OLD.id LIMIT 1
  ) INTO v_has_fixtures;

  -- Block changes to financial/roster/approval/result fields (always)
  IF NEW.is_approved          IS DISTINCT FROM OLD.is_approved          OR
     NEW.champion_team_id     IS DISTINCT FROM OLD.champion_team_id     OR
     NEW.winner_team_id       IS DISTINCT FROM OLD.winner_team_id       OR
     NEW.champion_user_id     IS DISTINCT FROM OLD.champion_user_id     OR
     NEW.paid_teams           IS DISTINCT FROM OLD.paid_teams           OR
     NEW.joined_teams         IS DISTINCT FROM OLD.joined_teams         OR
     NEW.prize_pool           IS DISTINCT FROM OLD.prize_pool           OR
     NEW.creation_fee_paid    IS DISTINCT FROM OLD.creation_fee_paid    OR
     NEW.creation_payment_id  IS DISTINCT FROM OLD.creation_payment_id  OR
     NEW.prize_delivered       IS DISTINCT FROM OLD.prize_delivered      OR
     NEW.prize_delivered_at   IS DISTINCT FROM OLD.prize_delivered_at   OR
     NEW.prize_delivered_by   IS DISTINCT FROM OLD.prize_delivered_by   OR
     NEW.prize_delivery_notes IS DISTINCT FROM OLD.prize_delivery_notes OR
     NEW.registration_locked_at IS DISTINCT FROM OLD.registration_locked_at THEN
    RAISE EXCEPTION 'Security Alert: Championship financial, roster, approval and result fields are server-authoritative.';
  END IF;

  -- Block structural changes after teams join OR after fixtures generated
  IF (v_has_participants OR v_has_fixtures) AND (
     NEW.entry_fee            IS DISTINCT FROM OLD.entry_fee            OR
     NEW.grand_prize          IS DISTINCT FROM OLD.grand_prize          OR
     NEW.max_teams            IS DISTINCT FROM OLD.max_teams            OR
     NEW.min_players_per_team IS DISTINCT FROM OLD.min_players_per_team OR
     NEW.max_players_per_team IS DISTINCT FROM OLD.max_players_per_team OR
     NEW.type                 IS DISTINCT FROM OLD.type                 OR
     NEW.number_of_groups     IS DISTINCT FROM OLD.number_of_groups     OR
     NEW.qualifying_per_group IS DISTINCT FROM OLD.qualifying_per_group OR
     NEW.is_two_legs          IS DISTINCT FROM OLD.is_two_legs          OR
     NEW.is_back_and_forth    IS DISTINCT FROM OLD.is_back_and_forth    OR
     NEW.winning_points       IS DISTINCT FROM OLD.winning_points       OR
     NEW.draw_points          IS DISTINCT FROM OLD.draw_points          OR
     NEW.loss_points          IS DISTINCT FROM OLD.loss_points
  ) THEN
    RAISE EXCEPTION 'Security Alert: Championship structure cannot change after registration or fixture generation. Fixtures exist: %', v_has_fixtures;
  END IF;

  -- Team League SSOT: these fields are always locked regardless of state
  IF OLD.template_type = 'team_league' AND (
     NEW.entry_fee         IS DISTINCT FROM OLD.entry_fee         OR
     NEW.max_teams         IS DISTINCT FROM OLD.max_teams         OR
     NEW.winning_points    IS DISTINCT FROM OLD.winning_points    OR
     NEW.draw_points       IS DISTINCT FROM OLD.draw_points       OR
     NEW.loss_points       IS DISTINCT FROM OLD.loss_points       OR
     NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth OR
     NEW.number_of_groups  IS DISTINCT FROM OLD.number_of_groups  OR
     NEW.is_two_legs       IS DISTINCT FROM OLD.is_two_legs       OR
     NEW.grand_prize       IS DISTINCT FROM OLD.grand_prize
  ) THEN
    RAISE EXCEPTION 'Security Alert: Team League structure is always fixed — cannot override VSP rules.';
  END IF;

  RETURN NEW;
END;
$$;


-- ============================================================
-- VERIFICATION
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_championship_actions'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: get_championship_actions'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'update_championship_atomic'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: update_championship_atomic'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'cancel_championship_atomic'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: cancel_championship_atomic'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'delete_championship_atomic'
  ) THEN RAISE EXCEPTION 'VERIFY FAILED: delete_championship_atomic'; END IF;

  RAISE NOTICE 'ALL LIFECYCLE VERIFICATIONS PASSED';
END;
$$;

COMMIT;
