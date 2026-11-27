-- ============================================================================
-- VSP P0-01..P0-04: Fix Admin Auth Bypass, Full Budget Enforcement,
-- Repeat-Opponent Anti-Fraud Cap, Snapshot-Backed Canonical Ranking & Lifecycle
-- ============================================================================

-- 1. P0 CRITICAL: Fix vsp_assert_admin_or_service_role (NEVER trust CURRENT_USER in SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.vsp_assert_admin_or_service_role()
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
BEGIN
  PERFORM public.require_active_admin_actor();
END;
$$;

-- 2. Canonical Competitive Ranking Engine (Single Source of Truth)
--    Reads frozen competitive_period_snapshots when period is finalized/completed/archived;
--    otherwise computes live standings from team_monthly_rankings + season/sport/repeat-opponent rules.
CREATE OR REPLACE FUNCTION public.get_canonical_competitive_ranking(
  p_period_id UUID DEFAULT NULL,
  p_governorate TEXT DEFAULT NULL,
  p_month_keys TEXT[] DEFAULT NULL,
  p_sport_type TEXT DEFAULT 'Football',
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
DECLARE
  v_period         public.competitive_reward_periods%ROWTYPE;
  v_months         TEXT[];
  v_season_id      UUID;
  v_max_repeat     INTEGER := 2;
  v_cash_cfg       JSONB := '{"1":500,"2":350,"3":250,"4":220,"5":180}'::JSONB;
  v_free_cap       NUMERIC := 120;
  v_teams          JSONB := '[]'::JSONB;
  v_is_finalized   BOOLEAN := FALSE;
BEGIN
  IF p_period_id IS NOT NULL THEN
    SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = p_period_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FOUND');
    END IF;
    v_months := v_period.month_keys;
    v_season_id := v_period.season_id;
    v_max_repeat := COALESCE(v_period.max_repeat_opponent_matches, 2);
    v_cash_cfg := COALESCE(v_period.prize_config->'cash', v_cash_cfg);
    v_free_cap := COALESCE((v_period.prize_config->>'voucher_value_cap_egp')::NUMERIC, 120);
    v_is_finalized := v_period.status IN ('finalized', 'rewards_distribution', 'completed', 'archived');
  ELSE
    IF p_month_keys IS NOT NULL AND array_length(p_month_keys, 1) > 0 THEN
      v_months := p_month_keys;
    ELSE
      v_months := ARRAY[
        public.vsp_cairo_month_key(now() - interval '1 month'),
        public.vsp_cairo_month_key(now())
      ];
    END IF;
    SELECT id INTO v_season_id FROM public.vsp_get_active_season();
  END IF;

  -- If period is finalized/completed/archived, serve ONLY from frozen Snapshot
  IF v_is_finalized THEN
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'rank', s.final_rank,
        'dense_rank', s.final_rank,
        'team_id', s.team_id,
        'team_name', t.name,
        'logo_url', COALESCE(t.logo_url, ''),
        'governorate', s.governorate,
        'sport_type', COALESCE(t.sport_type, 'Football'),
        'ranking_points', s.ranking_points,
        'matches_played', s.matches_played,
        'wins', s.wins,
        'draws', s.draws,
        'losses', s.losses,
        'current_shield', COALESCE(sp.current_shield, 'none'),
        'reward_zone', CASE WHEN s.final_rank <= 5 THEN 'cash_rewards' WHEN s.final_rank <= 10 THEN 'free_booking' ELSE 'competition' END,
        'expected_cash_egp', CASE WHEN s.final_rank <= 5 THEN COALESCE((v_cash_cfg->>(s.final_rank::TEXT))::INT, 0) ELSE 0 END,
        'needs_tie_review', NOT COALESCE(s.tie_break_resolved, true),
        'is_snapshot', true
      ) ORDER BY s.final_rank
    ), '[]'::JSONB)
    INTO v_teams
    FROM (
      SELECT * FROM public.competitive_period_snapshots
      WHERE period_id = p_period_id
        AND (p_governorate IS NULL OR btrim(p_governorate) = '' OR lower(btrim(governorate)) = lower(btrim(p_governorate)))
      ORDER BY final_rank
      LIMIT p_limit OFFSET p_offset
    ) s
    JOIN public.teams t ON t.id = s.team_id
    LEFT JOIN public.team_season_progress sp ON sp.team_id = s.team_id AND sp.season_id = v_season_id;

    RETURN jsonb_build_object(
      'success', true,
      'source', 'snapshot',
      'period_id', p_period_id,
      'month_keys', to_jsonb(v_months),
      'voucher_value_cap_egp', v_free_cap,
      'teams', v_teams
    );
  END IF;

  -- Live / Under-Review calculation from team_monthly_rankings + repeat-opponent penalty deduction
  WITH repeat_excess AS (
    SELECT
      o.team_id,
      COALESCE(SUM(GREATEST(0, o.matches_count - v_max_repeat)), 0)::INT AS excess_matches
    FROM public.team_season_opponents o
    WHERE (v_season_id IS NULL OR o.season_id = v_season_id)
    GROUP BY o.team_id
  ),
  agg AS (
    SELECT
      r.team_id,
      MAX(t.name) AS team_name,
      COALESCE(MAX(t.logo_url), '') AS logo_url,
      MAX(r.governorate) AS governorate,
      MAX(r.sport_type) AS sport_type,
      -- Deduct max 3 pts per excess repeat match beyond max_repeat_opponent_matches (floor at 0)
      GREATEST(0, SUM(r.ranking_points)::INT - (COALESCE(MAX(re.excess_matches), 0) * 3)) AS ranking_points,
      SUM(r.matches_played)::INT AS matches_played,
      SUM(r.wins)::INT AS wins,
      SUM(r.draws)::INT AS draws,
      SUM(r.losses)::INT AS losses,
      COALESCE(MAX(re.excess_matches), 0) AS repeat_excess_matches,
      COALESCE(MAX(sp.current_shield), 'none') AS current_shield
    FROM public.team_monthly_rankings r
    JOIN public.teams t ON t.id = r.team_id
    LEFT JOIN public.team_season_progress sp ON sp.team_id = r.team_id AND sp.season_id = r.season_id
    LEFT JOIN repeat_excess re ON re.team_id = r.team_id
    WHERE r.month_key = ANY(v_months)
      AND (v_season_id IS NULL OR r.season_id = v_season_id)
      AND (p_sport_type IS NULL OR btrim(p_sport_type) = '' OR lower(btrim(r.sport_type)) = lower(btrim(p_sport_type)))
      AND (p_governorate IS NULL OR btrim(p_governorate) = '' OR lower(btrim(r.governorate)) = lower(btrim(p_governorate)))
    GROUP BY r.team_id
  ),
  ranked AS (
    SELECT
      *,
      DENSE_RANK() OVER (
        ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC
      )::INT AS dense_rank,
      ROW_NUMBER() OVER (
        ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC, team_id ASC
      )::INT AS position_order
    FROM agg
  ),
  with_flags AS (
    SELECT
      *,
      (COUNT(*) OVER (PARTITION BY ranking_points, wins, draws, losses, matches_played) > 1) AS needs_tie_review,
      CASE
        WHEN position_order BETWEEN 1 AND 5 THEN 'cash_rewards'
        WHEN position_order BETWEEN 6 AND 10 THEN 'free_booking'
        ELSE 'competition'
      END AS reward_zone,
      CASE WHEN position_order BETWEEN 1 AND 5 THEN COALESCE((v_cash_cfg->>(position_order::TEXT))::INT, 0) ELSE 0 END AS expected_cash_egp
    FROM ranked
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'rank', position_order,
      'dense_rank', dense_rank,
      'team_id', team_id,
      'team_name', team_name,
      'logo_url', logo_url,
      'governorate', governorate,
      'sport_type', sport_type,
      'ranking_points', ranking_points,
      'matches_played', matches_played,
      'wins', wins,
      'draws', draws,
      'losses', losses,
      'repeat_excess_matches', repeat_excess_matches,
      'current_shield', current_shield,
      'reward_zone', reward_zone,
      'expected_cash_egp', expected_cash_egp,
      'needs_tie_review', needs_tie_review,
      'is_snapshot', false
    ) ORDER BY position_order
  ), '[]'::JSONB)
  INTO v_teams
  FROM (SELECT * FROM with_flags ORDER BY position_order LIMIT p_limit OFFSET p_offset) sub;

  RETURN jsonb_build_object(
    'success', true,
    'source', 'canonical_live',
    'period_id', p_period_id,
    'month_keys', to_jsonb(v_months),
    'max_repeat_opponent_matches', v_max_repeat,
    'voucher_value_cap_egp', v_free_cap,
    'teams', v_teams
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_canonical_competitive_ranking(UUID, TEXT, TEXT[], TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_canonical_competitive_ranking(UUID, TEXT, TEXT[], TEXT, INTEGER, INTEGER) TO authenticated;

-- 3. Unify Preview & Public RPCs to delegate to get_canonical_competitive_ranking
CREATE OR REPLACE FUNCTION public.get_bimonthly_ranking_preview(
  p_governorate TEXT DEFAULT NULL,
  p_month_keys TEXT[] DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
BEGIN
  RETURN public.get_canonical_competitive_ranking(NULL, p_governorate, p_month_keys, 'Football', p_limit, p_offset);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_competitive_leaderboard(
  p_governorate TEXT DEFAULT 'Aswan',
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
DECLARE
  v_period    public.competitive_reward_periods%ROWTYPE;
  v_canonical JSONB;
  v_rows      JSONB := '[]'::JSONB;
BEGIN
  SELECT * INTO v_period
  FROM public.competitive_reward_periods
  WHERE is_official_live IS TRUE
    AND status IN ('active', 'under_review', 'dispute_resolution', 'finalized', 'rewards_distribution', 'completed')
    AND (p_governorate IS NULL OR p_governorate = ANY(participating_governorates))
  ORDER BY starts_at DESC
  LIMIT 1;

  v_canonical := public.get_canonical_competitive_ranking(
    v_period.id, p_governorate, NULL, 'Football', LEAST(GREATEST(p_limit, 1), 50), 0
  );

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'rank', (elem->>'rank')::INT,
      'team_name', elem->>'team_name',
      'logo_url', elem->>'logo_url',
      'governorate', elem->>'governorate',
      'ranking_points', (elem->>'ranking_points')::INT,
      'wins', (elem->>'wins')::INT,
      'draws', (elem->>'draws')::INT,
      'losses', (elem->>'losses')::INT,
      'current_shield', elem->>'current_shield',
      'reward_zone', elem->>'reward_zone'
    )
  ), '[]'::JSONB)
  INTO v_rows
  FROM jsonb_array_elements(COALESCE(v_canonical->'teams', '[]'::JSONB)) elem;

  RETURN jsonb_build_object(
    'success', true,
    'period_code', COALESCE(v_period.period_code, 'preview'),
    'is_official', (v_period.id IS NOT NULL),
    'ends_at', v_period.ends_at,
    'teams', v_rows
  );
END;
$$;

-- 4. P0 Budget-Enforced, Config-Driven Snapshot & Entitlement Generation
CREATE OR REPLACE FUNCTION public.admin_generate_period_snapshot_and_entitlements(
  p_period_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
DECLARE
  v_actor        UUID := auth.uid();
  v_period       public.competitive_reward_periods%ROWTYPE;
  v_gov          TEXT;
  v_canonical    JSONB;
  v_elem         JSONB;
  v_rank         INTEGER;
  v_cash_amt     INTEGER;
  v_free_cap     NUMERIC;
  v_free_limit   INTEGER;
  v_expiry_days  INTEGER;
  v_cash_5       INTEGER;
  v_proj_cash    NUMERIC := 0;
  v_proj_free    INTEGER := 0;
  v_proj_total   NUMERIC := 0;
  v_snap_cnt     INTEGER := 0;
  v_ent_cnt      INTEGER := 0;
  v_tie_exists   BOOLEAN := FALSE;
BEGIN
  PERFORM public.require_active_admin_actor();

  SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = p_period_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FOUND'); END IF;
  IF v_period.status NOT IN ('under_review', 'dispute_resolution') THEN
    RETURN jsonb_build_object('success', false, 'error', 'PERIOD_MUST_BE_UNDER_REVIEW_OR_DISPUTE');
  END IF;
  IF COALESCE(v_period.funding_source, 'vsp') = 'shared' THEN
    RETURN jsonb_build_object('success', false, 'error', 'SHARED_FUNDING_NOT_SUPPORTED');
  END IF;

  IF EXISTS (SELECT 1 FROM public.season_reward_entitlements WHERE period_id = p_period_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ENTITLEMENTS_ALREADY_GENERATED');
  END IF;

  v_free_cap := COALESCE((v_period.prize_config->>'voucher_value_cap_egp')::NUMERIC, 120);
  v_free_limit := COALESCE((v_period.prize_config->>'free_hours_count')::INT, 5);
  v_expiry_days := COALESCE((v_period.prize_config->>'voucher_expiry_days')::INT, 30);
  v_cash_5 := COALESCE((v_period.prize_config->'cash'->>'5')::INT, 180);

  IF v_cash_5 <= v_free_cap THEN
    RETURN jsonb_build_object('success', false, 'error', 'RANK_5_CASH_MUST_EXCEED_FREE_HOUR_VALUE');
  END IF;

  -- Pass 1: Pre-validate full budget (Cash + VSP-funded Free Hours) BEFORE inserting ANY entitlement
  FOR v_gov IN SELECT unnest(v_period.participating_governorates)
  LOOP
    v_canonical := public.get_canonical_competitive_ranking(v_period.id, v_gov, v_period.month_keys, 'Football', 100, 0);
    FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_canonical->'teams', '[]'::JSONB))
    LOOP
      v_rank := (v_elem->>'rank')::INT;
      IF v_rank <= 10 AND COALESCE((v_elem->>'needs_tie_review')::BOOLEAN, FALSE) THEN
        v_tie_exists := TRUE;
      END IF;
      IF v_rank BETWEEN 1 AND 5 THEN
        v_proj_cash := v_proj_cash + COALESCE((v_period.prize_config->'cash'->>(v_rank::TEXT))::INT, 0);
      ELSIF v_rank BETWEEN 6 AND (5 + v_free_limit) THEN
        v_proj_free := v_proj_free + 1;
      END IF;
    END LOOP;
  END LOOP;

  v_proj_total := v_proj_cash + CASE WHEN v_period.funding_source = 'vsp' THEN (v_proj_free * v_free_cap) ELSE 0 END;
  IF v_proj_total > COALESCE(v_period.budget_cap_egp, 0) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'BUDGET_CAP_EXCEEDED',
      'projected_total_egp', v_proj_total,
      'budget_cap_egp', v_period.budget_cap_egp
    );
  END IF;

  -- Pass 2: Atomically insert Snapshot + Entitlements
  FOR v_gov IN SELECT unnest(v_period.participating_governorates)
  LOOP
    v_canonical := public.get_canonical_competitive_ranking(v_period.id, v_gov, v_period.month_keys, 'Football', 500, 0);
    FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_canonical->'teams', '[]'::JSONB))
    LOOP
      v_rank := (v_elem->>'rank')::INT;

      INSERT INTO public.competitive_period_snapshots (
        period_id, team_id, governorate, final_rank, ranking_points, wins, draws, losses, matches_played,
        tie_break_resolved, tie_break_note
      ) VALUES (
        v_period.id, (v_elem->>'team_id')::UUID, v_elem->>'governorate', v_rank,
        (v_elem->>'ranking_points')::INT, (v_elem->>'wins')::INT, (v_elem->>'draws')::INT,
        (v_elem->>'losses')::INT, (v_elem->>'matches_played')::INT,
        NOT COALESCE((v_elem->>'needs_tie_review')::BOOLEAN, FALSE),
        CASE WHEN COALESCE((v_elem->>'needs_tie_review')::BOOLEAN, FALSE) THEN 'REQUIRES_ADMIN_TIE_REVIEW' ELSE 'No tie at rank' END
      ) ON CONFLICT (period_id, team_id) DO UPDATE SET
        final_rank = EXCLUDED.final_rank,
        ranking_points = EXCLUDED.ranking_points,
        tie_break_resolved = EXCLUDED.tie_break_resolved,
        tie_break_note = EXCLUDED.tie_break_note;

      v_snap_cnt := v_snap_cnt + 1;

      IF v_rank BETWEEN 1 AND 5 THEN
        v_cash_amt := COALESCE((v_period.prize_config->'cash'->>(v_rank::TEXT))::INT, 0);
        IF v_cash_amt > 0 THEN
          INSERT INTO public.season_reward_entitlements (
            season_id, period_id, team_id, governorate, rank_position, zone_type, reward_type,
            cash_amount_egp, max_voucher_value_egp, status, payout_status, idempotency_key
          ) VALUES (
            v_period.season_id, v_period.id, (v_elem->>'team_id')::UUID, v_elem->>'governorate', v_rank,
            'cash_rewards', 'cash', v_cash_amt, 0, 'pending', 'pending_review',
            'period:' || v_period.id::TEXT || ':team:' || (v_elem->>'team_id')
          ) ON CONFLICT DO NOTHING;
          IF FOUND THEN v_ent_cnt := v_ent_cnt + 1; END IF;
        END IF;
      ELSIF v_rank BETWEEN 6 AND (5 + v_free_limit) THEN
        INSERT INTO public.season_reward_entitlements (
          season_id, period_id, team_id, governorate, rank_position, zone_type, reward_type,
          cash_amount_egp, max_voucher_value_egp, status, payout_status, sponsor_stadium_id,
          funding_source, eligible_time_windows, expires_at, idempotency_key
        ) VALUES (
          v_period.season_id, v_period.id, (v_elem->>'team_id')::UUID, v_elem->>'governorate', v_rank,
          'free_booking', 'free_hour', 0, v_free_cap::INT, 'available', 'approved', v_period.sponsor_stadium_id,
          v_period.funding_source, v_period.eligible_time_windows,
          v_period.ends_at + make_interval(days => v_expiry_days),
          'period:' || v_period.id::TEXT || ':team:' || (v_elem->>'team_id')
        ) ON CONFLICT DO NOTHING;
        IF FOUND THEN v_ent_cnt := v_ent_cnt + 1; END IF;
      END IF;
    END LOOP;
  END LOOP;

  UPDATE public.competitive_reward_periods
  SET snapshot_frozen_at = now(), updated_at = now()
  WHERE id = v_period.id;

  INSERT INTO public.competitive_reward_audit_logs (period_id, actor_user_id, action, new_state)
  VALUES (v_period.id, v_actor, 'snapshot_and_entitlements_generated', jsonb_build_object(
    'snapshots', v_snap_cnt, 'entitlements', v_ent_cnt,
    'cash_total_egp', v_proj_cash, 'free_hours_count', v_proj_free, 'projected_total_egp', v_proj_total,
    'tie_review_flagged', v_tie_exists
  ));

  RETURN jsonb_build_object(
    'success', true,
    'snapshots', v_snap_cnt,
    'entitlements', v_ent_cnt,
    'cash_total_egp', v_proj_cash,
    'free_hours_count', v_proj_free,
    'projected_total_egp', v_proj_total,
    'tie_review_flagged', v_tie_exists
  );
END;
$$;

-- 5. Tighten admin_transition_competitive_period_state:
--    - Cannot finalize with unresolved ties in Top 10 or missing entitlements
--    - Cannot complete with open unpaid cash or unredeemed/unexpired free-hour obligations
CREATE OR REPLACE FUNCTION public.admin_transition_competitive_period_state(
  p_period_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_cur public.competitive_reward_periods%ROWTYPE;
  v_allowed BOOLEAN := FALSE;
BEGIN
  PERFORM public.require_active_admin_actor();

  SELECT * INTO v_cur FROM public.competitive_reward_periods WHERE id = p_period_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FOUND'); END IF;

  v_allowed := CASE v_cur.status
    WHEN 'draft' THEN p_new_status IN ('scheduled', 'active', 'archived')
    WHEN 'scheduled' THEN p_new_status IN ('active', 'draft', 'archived')
    WHEN 'active' THEN p_new_status IN ('under_review')
    WHEN 'under_review' THEN p_new_status IN ('dispute_resolution', 'finalized')
    WHEN 'dispute_resolution' THEN p_new_status IN ('finalized', 'under_review')
    WHEN 'finalized' THEN p_new_status IN ('rewards_distribution')
    WHEN 'rewards_distribution' THEN p_new_status IN ('completed')
    WHEN 'completed' THEN p_new_status IN ('archived')
    ELSE FALSE
  END;

  IF NOT v_allowed THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_STATE_TRANSITION', 'from', v_cur.status, 'to', p_new_status);
  END IF;

  IF p_new_status = 'active' THEN
    IF array_length(v_cur.participating_governorates, 1) IS NULL OR COALESCE(v_cur.budget_cap_egp, 0) <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'GOVERNORATES_AND_BUDGET_REQUIRED');
    END IF;
    IF COALESCE(v_cur.funding_source, 'vsp') = 'shared' THEN
      RETURN jsonb_build_object('success', false, 'error', 'SHARED_FUNDING_NOT_SUPPORTED');
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.competitive_reward_periods o
      WHERE o.id <> v_cur.id AND o.status = 'active'
        AND o.participating_governorates && v_cur.participating_governorates
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'OVERLAPPING_ACTIVE_PERIOD_FOR_GOVERNORATE');
    END IF;
  END IF;

  IF p_new_status = 'finalized' THEN
    IF NOT EXISTS (SELECT 1 FROM public.competitive_period_snapshots WHERE period_id = p_period_id) THEN
      RETURN jsonb_build_object('success', false, 'error', 'SNAPSHOT_REQUIRED_BEFORE_FINALIZE');
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.competitive_period_snapshots
      WHERE period_id = p_period_id AND final_rank <= 10 AND tie_break_resolved IS NOT TRUE
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNRESOLVED_TOP_10_TIES_MUST_BE_REVIEWED');
    END IF;
  END IF;

  IF p_new_status = 'completed' THEN
    IF EXISTS (
      SELECT 1 FROM public.season_reward_entitlements
      WHERE period_id = p_period_id
        AND ((reward_type = 'cash' AND payout_status IN ('pending_review', 'approved', 'processing'))
          OR (reward_type = 'free_hour' AND status IN ('available', 'reserved')))
    ) THEN
      RETURN jsonb_build_object('success', false, 'error', 'OPEN_FINANCIAL_OR_VOUCHER_OBLIGATIONS_REMAIN');
    END IF;
  END IF;

  UPDATE public.competitive_reward_periods
  SET status = p_new_status,
      finalized_at = CASE WHEN p_new_status = 'finalized' THEN now() ELSE finalized_at END,
      finalized_by = CASE WHEN p_new_status = 'finalized' THEN v_actor ELSE finalized_by END,
      updated_at = now()
  WHERE id = p_period_id;

  INSERT INTO public.competitive_reward_audit_logs (period_id, actor_user_id, action, previous_state, new_state, reason)
  VALUES (p_period_id, v_actor, 'period_state_transition', jsonb_build_object('status', v_cur.status), jsonb_build_object('status', p_new_status), p_reason);

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;
