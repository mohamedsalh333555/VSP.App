-- ============================================================================
-- VSP Competitive Rewards Lifecycle, Bimonthly Preview Sync, Anti-Fraud &
-- Cash / Free-Hour Entitlements (Idempotent Migration)
-- ============================================================================

-- 1. Central Competitive Reward Periods (2-month default, admin-managed)
CREATE TABLE IF NOT EXISTS public.competitive_reward_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id UUID REFERENCES public.competition_seasons(id) ON DELETE SET NULL,
  period_code TEXT NOT NULL UNIQUE,
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  month_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  participating_governorates TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  status TEXT NOT NULL DEFAULT 'draft' CHECK (
    status IN (
      'draft',
      'scheduled',
      'active',
      'under_review',
      'dispute_resolution',
      'finalized',
      'rewards_distribution',
      'completed',
      'archived'
    )
  ),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  prize_config JSONB NOT NULL DEFAULT '{"cash":{"1":500,"2":350,"3":250,"4":220,"5":180},"free_hour_ranks":[6,7,8,9,10],"cash_pool_egp":1500,"free_hours_count":5}'::JSONB,
  budget_cap_egp NUMERIC(10,2) NOT NULL DEFAULT 2100.00,
  sponsor_stadium_id UUID,
  funding_source TEXT NOT NULL DEFAULT 'vsp' CHECK (funding_source IN ('vsp', 'sponsor_stadium', 'shared')),
  eligible_time_windows JSONB NOT NULL DEFAULT '[]'::JSONB,
  max_repeat_opponent_matches INTEGER NOT NULL DEFAULT 2 CHECK (max_repeat_opponent_matches >= 1),
  is_official_live BOOLEAN NOT NULL DEFAULT FALSE,
  snapshot_frozen_at TIMESTAMPTZ,
  finalized_at TIMESTAMPTZ,
  finalized_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at)
);

-- 2. Extend season_reward_entitlements for Cash Payouts & Free-Hour Controls
ALTER TABLE public.season_reward_entitlements
  ADD COLUMN IF NOT EXISTS period_id UUID REFERENCES public.competitive_reward_periods(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS authorized_recipient_user_id UUID,
  ADD COLUMN IF NOT EXISTS payout_status TEXT DEFAULT 'pending_review' CHECK (
    payout_status IN ('pending_review', 'approved', 'processing', 'paid', 'failed', 'disputed', 'revoked')
  ),
  ADD COLUMN IF NOT EXISTS delivery_method TEXT,
  ADD COLUMN IF NOT EXISTS delivery_reference TEXT,
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by UUID,
  ADD COLUMN IF NOT EXISTS paid_by UUID,
  ADD COLUMN IF NOT EXISTS sponsor_stadium_id UUID,
  ADD COLUMN IF NOT EXISTS funding_source TEXT DEFAULT 'vsp' CHECK (funding_source IN ('vsp', 'sponsor_stadium', 'shared')),
  ADD COLUMN IF NOT EXISTS eligible_time_windows JSONB DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reimbursed_amount_egp NUMERIC(10,2) DEFAULT 0;

-- 3. Immutable Audit Log for Competitive Rewards & Tie-Break Decisions
CREATE TABLE IF NOT EXISTS public.competitive_reward_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id UUID REFERENCES public.competitive_reward_periods(id) ON DELETE CASCADE,
  entitlement_id UUID REFERENCES public.season_reward_entitlements(id) ON DELETE SET NULL,
  actor_user_id UUID,
  action TEXT NOT NULL,
  previous_state JSONB,
  new_state JSONB,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Frozen Ranking Snapshot per Period (prevents retroactive silent edits)
CREATE TABLE IF NOT EXISTS public.competitive_period_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id UUID NOT NULL REFERENCES public.competitive_reward_periods(id) ON DELETE CASCADE,
  team_id UUID NOT NULL,
  governorate TEXT NOT NULL,
  final_rank INTEGER NOT NULL CHECK (final_rank >= 1),
  ranking_points INTEGER NOT NULL,
  wins INTEGER NOT NULL DEFAULT 0,
  draws INTEGER NOT NULL DEFAULT 0,
  losses INTEGER NOT NULL DEFAULT 0,
  matches_played INTEGER NOT NULL DEFAULT 0,
  unique_opponents_count INTEGER NOT NULL DEFAULT 0,
  tie_break_resolved BOOLEAN NOT NULL DEFAULT FALSE,
  tie_break_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (period_id, team_id)
);

ALTER TABLE public.competitive_reward_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitive_reward_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competitive_period_snapshots ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'competitive_reward_periods' AND policyname = 'competitive_reward_periods_read_auth'
  ) THEN
    CREATE POLICY competitive_reward_periods_read_auth
      ON public.competitive_reward_periods FOR SELECT
      TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'competitive_period_snapshots' AND policyname = 'competitive_period_snapshots_read_auth'
  ) THEN
    CREATE POLICY competitive_period_snapshots_read_auth
      ON public.competitive_period_snapshots FOR SELECT
      TO authenticated USING (true);
  END IF;
END $$;

-- ============================================================================
-- 5. Bimonthly Ranking Preview RPCs (Synced from Staging, Security Invoker)
--    Single Source of Truth: aggregates existing team_monthly_rankings
-- ============================================================================

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
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_months TEXT[];
  v_teams  JSONB := '[]'::JSONB;
BEGIN
  IF p_month_keys IS NOT NULL AND array_length(p_month_keys, 1) > 0 THEN
    v_months := p_month_keys;
  ELSE
    v_months := ARRAY[
      public.vsp_cairo_month_key(now() - interval '1 month'),
      public.vsp_cairo_month_key(now())
    ];
  END IF;

  WITH agg AS (
    SELECT
      r.team_id,
      MAX(t.name) AS team_name,
      COALESCE(MAX(t.logo_url), '') AS logo_url,
      MAX(r.governorate) AS governorate,
      MAX(r.sport_type) AS sport_type,
      SUM(r.ranking_points)::INT AS ranking_points,
      SUM(r.matches_played)::INT AS matches_played,
      SUM(r.wins)::INT AS wins,
      SUM(r.draws)::INT AS draws,
      SUM(r.losses)::INT AS losses,
      MAX(r.last_match_at) AS last_match_at,
      COALESCE(MAX(sp.current_shield), 'none') AS current_shield
    FROM public.team_monthly_rankings r
    JOIN public.teams t ON t.id = r.team_id
    LEFT JOIN public.team_season_progress sp ON sp.team_id = r.team_id AND sp.season_id = r.season_id
    WHERE r.month_key = ANY(v_months)
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
        ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, last_match_at ASC NULLS LAST
      )::INT AS deterministic_rank
    FROM agg
  ),
  with_ties AS (
    SELECT
      *,
      (COUNT(*) OVER (PARTITION BY ranking_points, wins, draws, losses) > 1) AS needs_tie_review,
      CASE
        WHEN deterministic_rank BETWEEN 1 AND 5 THEN 'cash_rewards'
        WHEN deterministic_rank BETWEEN 6 AND 10 THEN 'free_booking'
        ELSE 'competition'
      END AS reward_zone,
      CASE deterministic_rank
        WHEN 1 THEN 500
        WHEN 2 THEN 350
        WHEN 3 THEN 250
        WHEN 4 THEN 220
        WHEN 5 THEN 180
        ELSE 0
      END AS expected_cash_egp
    FROM ranked
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'rank', deterministic_rank,
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
      'current_shield', current_shield,
      'reward_zone', reward_zone,
      'expected_cash_egp', expected_cash_egp,
      'needs_tie_review', needs_tie_review
    ) ORDER BY deterministic_rank
  ), '[]'::JSONB)
  INTO v_teams
  FROM (SELECT * FROM with_ties ORDER BY deterministic_rank LIMIT p_limit OFFSET p_offset) sub;

  RETURN jsonb_build_object(
    'success', true,
    'month_keys', to_jsonb(v_months),
    'cash_pool_egp', 1500,
    'free_hours_count', 5,
    'teams', v_teams
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_bimonthly_ranking_preview(TEXT, TEXT[], INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_bimonthly_ranking_preview(TEXT, TEXT[], INTEGER, INTEGER) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_team_competitive_progress_preview(
  p_team_id UUID,
  p_month_keys TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_preview JSONB;
  v_teams   JSONB;
  v_my      JSONB;
  v_rank    INT;
  v_pts     INT;
  v_target_rank INT;
  v_target_pts  INT;
BEGIN
  v_preview := public.get_bimonthly_ranking_preview(NULL, p_month_keys, 500, 0);
  v_teams := COALESCE(v_preview->'teams', '[]'::JSONB);

  SELECT elem INTO v_my
  FROM jsonb_array_elements(v_teams) elem
  WHERE (elem->>'team_id')::UUID = p_team_id
  LIMIT 1;

  IF v_my IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'in_ranking', false,
      'target_rank', 10,
      'points_gap', 1
    );
  END IF;

  v_rank := (v_my->>'rank')::INT;
  v_pts := (v_my->>'ranking_points')::INT;

  IF v_rank > 10 THEN
    v_target_rank := 10;
  ELSIF v_rank > 5 THEN
    v_target_rank := 5;
  ELSE
    v_target_rank := GREATEST(1, v_rank - 1);
  END IF;

  SELECT (elem->>'ranking_points')::INT INTO v_target_pts
  FROM jsonb_array_elements(v_teams) elem
  WHERE (elem->>'rank')::INT = v_target_rank
  LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'in_ranking', true,
    'team', v_my,
    'target_rank', v_target_rank,
    'points_gap', CASE WHEN v_target_pts IS NULL THEN 0 ELSE GREATEST(0, (v_target_pts - v_pts) + 1) END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_team_competitive_progress_preview(UUID, TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_competitive_progress_preview(UUID, TEXT[]) TO authenticated;

-- ============================================================================
-- 6. Public Safe Leaderboard RPC (for Website anon access — NO financial/PII)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_public_competitive_leaderboard(
  p_governorate TEXT DEFAULT 'Aswan',
  p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_period RECORD;
  v_months TEXT[];
  v_rows   JSONB := '[]'::JSONB;
BEGIN
  SELECT * INTO v_period
  FROM public.competitive_reward_periods
  WHERE status IN ('active', 'under_review', 'finalized', 'rewards_distribution')
    AND (p_governorate IS NULL OR p_governorate = ANY(participating_governorates) OR array_length(participating_governorates, 1) IS NULL)
  ORDER BY starts_at DESC
  LIMIT 1;

  IF v_period.id IS NOT NULL AND array_length(v_period.month_keys, 1) > 0 THEN
    v_months := v_period.month_keys;
  ELSE
    v_months := ARRAY[
      public.vsp_cairo_month_key(now() - interval '1 month'),
      public.vsp_cairo_month_key(now())
    ];
  END IF;

  WITH agg AS (
    SELECT
      r.team_id,
      MAX(t.name) AS team_name,
      COALESCE(MAX(t.logo_url), '') AS logo_url,
      MAX(r.governorate) AS governorate,
      SUM(r.ranking_points)::INT AS ranking_points,
      SUM(r.wins)::INT AS wins,
      SUM(r.draws)::INT AS draws,
      SUM(r.losses)::INT AS losses,
      COALESCE(MAX(sp.current_shield), 'none') AS current_shield,
      MAX(r.last_match_at) AS last_match_at
    FROM public.team_monthly_rankings r
    JOIN public.teams t ON t.id = r.team_id
    LEFT JOIN public.team_season_progress sp ON sp.team_id = r.team_id AND sp.season_id = r.season_id
    WHERE r.month_key = ANY(v_months)
      AND (p_governorate IS NULL OR btrim(p_governorate) = '' OR lower(btrim(r.governorate)) = lower(btrim(p_governorate)))
    GROUP BY r.team_id
  ),
  ranked AS (
    SELECT
      *,
      ROW_NUMBER() OVER (ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, last_match_at ASC NULLS LAST)::INT AS rank
    FROM agg
  )
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'rank', rank,
      'team_name', team_name,
      'logo_url', logo_url,
      'governorate', governorate,
      'ranking_points', ranking_points,
      'wins', wins,
      'draws', draws,
      'losses', losses,
      'current_shield', current_shield,
      'reward_zone', CASE WHEN rank <= 5 THEN 'cash_rewards' WHEN rank <= 10 THEN 'free_booking' ELSE 'competition' END
    ) ORDER BY rank
  ), '[]'::JSONB)
  INTO v_rows
  FROM (SELECT * FROM ranked ORDER BY rank LIMIT LEAST(GREATEST(p_limit, 1), 50)) sub;

  RETURN jsonb_build_object(
    'success', true,
    'period_code', COALESCE(v_period.period_code, 'preview'),
    'ends_at', v_period.ends_at,
    'teams', v_rows
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_competitive_leaderboard(TEXT, INTEGER) TO anon, authenticated;

-- ============================================================================
-- 7. Atomic Free-Hour Redemption for Competitive Season Entitlements
--    Supports both VSP-funded and Sponsor-Stadium-funded vouchers safely
-- ============================================================================
CREATE OR REPLACE FUNCTION public.redeem_competitive_free_hour_atomic(
  p_entitlement_id UUID,
  p_stadium_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller   UUID := auth.uid();
  v_ent      RECORD;
  v_team     RECORD;
  v_stadium  RECORD;
  v_dur_hr   NUMERIC;
  v_price    NUMERIC;
  v_booking_id UUID;
  v_op_date  DATE;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_ent FROM public.season_reward_entitlements WHERE id = p_entitlement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ENTITLEMENT_NOT_FOUND'); END IF;
  IF v_ent.reward_type <> 'free_hour' THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_FREE_HOUR_REWARD'); END IF;
  IF v_ent.status <> 'available' THEN RETURN jsonb_build_object('success', false, 'error', 'REWARD_NOT_AVAILABLE'); END IF;
  IF v_ent.expires_at IS NOT NULL AND v_ent.expires_at < now() THEN
    UPDATE public.season_reward_entitlements SET status = 'expired', updated_at = now() WHERE id = v_ent.id;
    RETURN jsonb_build_object('success', false, 'error', 'REWARD_EXPIRED');
  END IF;

  IF v_ent.sponsor_stadium_id IS NOT NULL AND v_ent.sponsor_stadium_id <> p_stadium_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_ELIGIBLE_FOR_REWARD');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_ent.team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  v_dur_hr := extract(epoch FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_dur_hr <= 0 OR v_dur_hr > 1.05 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EXACTLY_ONE_FREE_HOUR_ALLOWED');
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
  IF NOT FOUND OR v_stadium.is_active IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE');
  END IF;

  IF lower(btrim(COALESCE(v_stadium.governorate, ''))) <> lower(btrim(v_ent.governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'GOVERNORATE_MISMATCH');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id::text, 0));

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status IN ('pending', 'confirmed', 'completed')
      AND start_time < p_end_time AND end_time > p_start_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_ALREADY_BOOKED');
  END IF;

  v_price := LEAST(
    COALESCE(NULLIF(v_ent.max_voucher_value_egp, 0), 180),
    round(COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0), 2)
  );
  v_op_date := (p_start_time AT TIME ZONE 'Africa/Cairo')::DATE;

  INSERT INTO public.bookings (
    stadium_id, owner_id, user_id, created_by_user_id, stadium_name, stadium_image_url,
    start_time, end_time, operational_date, booking_type, player_team_id, player_team_name,
    is_private, total_price, deposit_paid, is_deposit_paid, is_paid, payment_status,
    payment_method, payment_source, payment_transaction_id, platform_fee, vsp_commission, gateway_fee,
    status, currency, is_verified_by_owner
  ) VALUES (
    p_stadium_id, v_stadium.owner_id, v_caller, v_caller, v_stadium.name, v_stadium.image_url,
    p_start_time, p_end_time, v_op_date, 'team', v_team.id, v_team.name,
    true, v_price, 0, true, true, 'paid',
    'vsp_season_reward', COALESCE(v_ent.funding_source, 'vsp'), 'SEASON_REWARD_' || v_ent.id::text, 0, 0, 0,
    'confirmed', 'EGP', true
  ) RETURNING id INTO v_booking_id;

  UPDATE public.season_reward_entitlements
  SET status = 'redeemed',
      reserved_booking_id = v_booking_id,
      redeemed_at = now(),
      reimbursed_amount_egp = CASE WHEN COALESCE(funding_source, 'vsp') = 'vsp' THEN v_price ELSE 0 END,
      updated_at = now()
  WHERE id = v_ent.id;

  -- Record owner financial credit ONLY when VSP funds the hour (sponsor_stadium absorbs its own slot)
  IF COALESCE(v_ent.funding_source, 'vsp') = 'vsp' THEN
    INSERT INTO public.transactions (
      user_id, booking_id, amount, type, status, payment_method, metadata, created_at, updated_at
    ) VALUES (
      v_stadium.owner_id, v_booking_id, v_price, 'vsp_season_reward_credit', 'completed', 'vsp_season_reward',
      jsonb_build_object('entitlement_id', v_ent.id, 'team_id', v_team.id, 'vsp_funded', true),
      now(), now()
    );
  END IF;

  INSERT INTO public.competitive_reward_audit_logs (period_id, entitlement_id, actor_user_id, action, new_state)
  VALUES (
    v_ent.period_id, v_ent.id, v_caller, 'free_hour_redeemed',
    jsonb_build_object('booking_id', v_booking_id, 'stadium_id', p_stadium_id, 'funding_source', v_ent.funding_source, 'covered_amount', v_price)
  );

  RETURN jsonb_build_object('success', true, 'booking_id', v_booking_id, 'covered_amount_egp', v_price);
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_competitive_free_hour_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
