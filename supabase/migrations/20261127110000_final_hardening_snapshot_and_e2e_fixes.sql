-- ============================================================================
-- VSP Final Hardening: Admin Auth Guard, Full-Range Windows, Dynamic Pricing,
-- Snapshot & Entitlement Generation, Recipient Validation & Analytics Guard
-- ============================================================================

-- 0. Fix season_reward_entitlements FK to reference existing public.competition_seasons(id)
ALTER TABLE public.season_reward_entitlements
  DROP CONSTRAINT IF EXISTS season_reward_entitlements_season_id_fkey;
ALTER TABLE public.season_reward_entitlements
  ADD CONSTRAINT season_reward_entitlements_season_id_fkey
  FOREIGN KEY (season_id) REFERENCES public.competition_seasons(id) ON DELETE SET NULL;

-- 1. Strict Admin-or-Service-Role Guard (closes auth.uid() IS NULL bypass)
CREATE OR REPLACE FUNCTION public.vsp_assert_admin_or_service_role()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF current_user IN ('postgres', 'service_role') THEN
    RETURN;
  END IF;
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;
  PERFORM public.require_active_admin_actor();
END;
$$;

-- 2. Harden close_monthly_ranking_period with strict admin/service guard
CREATE OR REPLACE FUNCTION public.close_monthly_ranking_period(p_month_key TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season     public.competition_seasons;
  v_target_mon TEXT := COALESCE(p_month_key, public.vsp_cairo_month_key(now() - interval '1 day'));
  v_winner     RECORD;
  v_awards_cnt INT := 0;
  v_covered    BOOLEAN := FALSE;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'NO_ACTIVE_SEASON'); END IF;

  WITH ranked AS (
    SELECT season_id, month_key, team_id,
           DENSE_RANK() OVER (
             PARTITION BY lower(btrim(governorate))
             ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC
           )::INT AS rnk
    FROM public.team_monthly_rankings
    WHERE season_id = v_season.id AND month_key = v_target_mon
  )
  UPDATE public.team_monthly_rankings r
  SET final_rank = ranked.rnk, is_frozen = true, updated_at = now()
  FROM ranked
  WHERE r.season_id = ranked.season_id AND r.month_key = ranked.month_key AND r.team_id = ranked.team_id;

  FOR v_winner IN
    SELECT * FROM public.team_monthly_rankings
    WHERE season_id = v_season.id AND month_key = v_target_mon AND final_rank = 1
  LOOP
    PERFORM public.vsp_unlock_achievement_if_new(
      v_season.id, v_winner.team_id, 'month_champion',
      'بطل الشهر', 'Champion of the Month',
      'تصدر ترتيب المحافظة الشهري.',
      'Topped monthly governorate ranking.',
      'ranking', v_target_mon
    );

    SELECT EXISTS (
      SELECT 1 FROM public.competitive_reward_periods p
      WHERE p.status IN ('scheduled', 'active', 'under_review', 'dispute_resolution', 'finalized', 'rewards_distribution', 'completed', 'archived')
        AND v_target_mon = ANY(p.month_keys)
        AND (
          array_length(p.participating_governorates, 1) IS NULL
          OR EXISTS (
            SELECT 1 FROM unnest(p.participating_governorates) g
            WHERE lower(btrim(g)) = lower(btrim(v_winner.governorate))
          )
        )
    ) INTO v_covered;

    IF NOT v_covered THEN
      INSERT INTO public.monthly_champion_awards (
        season_id, month_key, governorate, team_id, final_rank,
        ranking_points, wins, draws, losses, matches_played, status
      ) VALUES (
        v_winner.season_id, v_winner.month_key, v_winner.governorate, v_winner.team_id, 1,
        v_winner.ranking_points, v_winner.wins, v_winner.draws, v_winner.losses, v_winner.matches_played, 'issued'
      )
      ON CONFLICT (season_id, month_key, governorate, team_id) DO NOTHING;

      IF FOUND THEN
        v_awards_cnt := v_awards_cnt + 1;
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        SELECT tm.user_id,
               'بطل الشهر في ' || v_winner.governorate || '! 🏆',
               'مبروك! تصدر فريقك ترتيب شهر ' || v_target_mon || ' واستحق ساعة حجز ملعب مجانية صالحة بدون انتهاء في محافظتك.',
               'monthly_champion',
               now()
        FROM public.team_members tm WHERE tm.team_id = v_winner.team_id;
      END IF;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'month_key', v_target_mon, 'awards_issued', v_awards_cnt);
END;
$$;

-- 3. Harden redeem_competitive_free_hour_atomic (blocked user, shared block, full-range windows, dynamic pricing)
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
  v_caller      UUID := auth.uid();
  v_ent         public.season_reward_entitlements%ROWTYPE;
  v_period      public.competitive_reward_periods%ROWTYPE;
  v_team        RECORD;
  v_stadium     RECORD;
  v_custom_rate NUMERIC;
  v_price       NUMERIC;
  v_booking_id  UUID;
  v_op_date     DATE;
  v_cairo_start TIMESTAMP;
  v_cairo_end   TIMESTAMP;
  v_start_min   INT;
  v_end_min     INT;
  v_window_ok   BOOLEAN := TRUE;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;
  IF p_entitlement_id IS NULL OR p_stadium_id IS NULL OR p_start_time IS NULL OR p_end_time IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_INPUT');
  END IF;

  IF EXISTS (SELECT 1 FROM public.users u WHERE u.id = v_caller AND u.is_blocked IS TRUE) THEN
    RETURN jsonb_build_object('success', false, 'error', 'ACCOUNT_BLOCKED');
  END IF;

  IF p_start_time <= now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAST_TIME_NOT_ALLOWED');
  END IF;

  IF (p_end_time - p_start_time) <> interval '60 minutes' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EXACTLY_60_MINUTES_REQUIRED');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_ent FROM public.season_reward_entitlements WHERE id = p_entitlement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ENTITLEMENT_NOT_FOUND'); END IF;
  IF v_ent.reward_type <> 'free_hour' THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_FREE_HOUR_REWARD'); END IF;
  IF COALESCE(v_ent.funding_source, 'vsp') = 'shared' THEN
    RETURN jsonb_build_object('success', false, 'error', 'SHARED_FUNDING_NOT_SUPPORTED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_ent.team_id;
  IF NOT FOUND OR (v_team.captain_id IS DISTINCT FROM v_caller AND v_ent.authorized_recipient_user_id IS DISTINCT FROM v_caller) THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_OR_AUTHORIZED_RECIPIENT_ONLY');
  END IF;

  IF v_ent.status <> 'available' THEN RETURN jsonb_build_object('success', false, 'error', 'REWARD_NOT_AVAILABLE'); END IF;

  IF v_ent.expires_at IS NOT NULL AND (v_ent.expires_at < now() OR p_end_time > v_ent.expires_at) THEN
    IF v_ent.expires_at < now() THEN
      UPDATE public.season_reward_entitlements SET status = 'expired', updated_at = now() WHERE id = v_ent.id;
    END IF;
    RETURN jsonb_build_object('success', false, 'error', 'REWARD_EXPIRED_OR_BOOKING_AFTER_EXPIRY');
  END IF;

  IF v_ent.period_id IS NOT NULL THEN
    SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = v_ent.period_id;
    IF FOUND AND v_period.status NOT IN ('finalized', 'rewards_distribution', 'completed') THEN
      RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FINALIZED');
    END IF;
  END IF;

  IF v_ent.sponsor_stadium_id IS NOT NULL AND v_ent.sponsor_stadium_id <> p_stadium_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_ELIGIBLE_FOR_REWARD');
  END IF;

  SELECT * INTO v_stadium FROM public.stadiums WHERE id = p_stadium_id;
  IF NOT FOUND
     OR v_stadium.is_verified IS NOT TRUE
     OR v_stadium.is_blocked IS TRUE
     OR COALESCE(v_stadium.is_deleted_by_owner, FALSE) IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE');
  END IF;

  IF lower(btrim(COALESCE(v_stadium.governorate, ''))) <> lower(btrim(v_ent.governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'GOVERNORATE_MISMATCH');
  END IF;

  v_cairo_start := p_start_time AT TIME ZONE 'Africa/Cairo';
  v_cairo_end := p_end_time AT TIME ZONE 'Africa/Cairo';
  v_op_date := v_cairo_start::DATE;

  -- Full-range eligible_time_windows check in Africa/Cairo (start + end minutes, no midnight bypass)
  IF v_ent.eligible_time_windows IS NOT NULL
     AND jsonb_typeof(v_ent.eligible_time_windows) = 'array'
     AND jsonb_array_length(v_ent.eligible_time_windows) > 0 THEN
    IF v_cairo_end::DATE <> v_cairo_start::DATE AND (v_cairo_end::TIME <> '00:00:00'::TIME) THEN
      RETURN jsonb_build_object('success', false, 'error', 'OUTSIDE_ELIGIBLE_TIME_WINDOW');
    END IF;
    v_start_min := EXTRACT(HOUR FROM v_cairo_start)::INT * 60 + EXTRACT(MINUTE FROM v_cairo_start)::INT;
    v_end_min := CASE WHEN v_cairo_end::TIME = '00:00:00'::TIME THEN 1440
                      ELSE EXTRACT(HOUR FROM v_cairo_end)::INT * 60 + EXTRACT(MINUTE FROM v_cairo_end)::INT END;
    SELECT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_ent.eligible_time_windows) w
      WHERE v_start_min >= COALESCE((w->>'start_hour')::INT, 0) * 60
        AND v_end_min <= COALESCE((w->>'end_hour')::INT, 24) * 60
    ) INTO v_window_ok;
    IF NOT v_window_ok THEN
      RETURN jsonb_build_object('success', false, 'error', 'OUTSIDE_ELIGIBLE_TIME_WINDOW');
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id::text, 0));

  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time, v_stadium.closing_time, v_stadium.break_start_time, v_stadium.break_end_time,
    v_stadium.is_split_shift, v_stadium.maintenance_until, p_start_time, p_end_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_STADIUM_WINDOW');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.bookings
    WHERE stadium_id = p_stadium_id
      AND status IN ('pending', 'confirmed', 'completed')
      AND start_time < p_end_time AND end_time > p_start_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_ALREADY_BOOKED');
  END IF;

  -- Dynamic pricing lookup from stadium_custom_rates first, then stadium base rate
  SELECT cr.price_per_hour INTO v_custom_rate
  FROM public.stadium_custom_rates cr
  WHERE cr.stadium_id = p_stadium_id
    AND (cr.specific_date = v_op_date OR (cr.specific_date IS NULL AND cr.day_of_week = EXTRACT(DOW FROM v_cairo_start)::INT))
    AND cr.start_time <= v_cairo_start::TIME
    AND cr.end_time >= v_cairo_end::TIME
  ORDER BY (cr.specific_date IS NOT NULL) DESC, cr.created_at DESC
  LIMIT 1;

  v_price := round(COALESCE(v_custom_rate, v_stadium.price_per_hour, v_stadium.base_price, 0), 2);
  IF COALESCE(v_ent.max_voucher_value_egp, 0) > 0 AND v_price > v_ent.max_voucher_value_egp THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_EXCEEDS_VOUCHER_VALUE');
  END IF;

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

REVOKE ALL ON FUNCTION public.redeem_competitive_free_hour_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_competitive_free_hour_atomic(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- 4. Atomic Snapshot & Entitlement Generation from Central Period Config
CREATE OR REPLACE FUNCTION public.admin_generate_period_snapshot_and_entitlements(
  p_period_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor      UUID := auth.uid();
  v_period     public.competitive_reward_periods%ROWTYPE;
  v_gov        TEXT;
  v_row        RECORD;
  v_cash_amt   INTEGER;
  v_ent_cnt    INTEGER := 0;
  v_snap_cnt   INTEGER := 0;
  v_total_cash INTEGER := 0;
  v_free_cnt   INTEGER := 0;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

  SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = p_period_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FOUND'); END IF;
  IF v_period.status NOT IN ('under_review', 'dispute_resolution') THEN
    RETURN jsonb_build_object('success', false, 'error', 'PERIOD_MUST_BE_UNDER_REVIEW_OR_DISPUTE');
  END IF;
  IF COALESCE(v_period.funding_source, 'vsp') = 'shared' THEN
    RETURN jsonb_build_object('success', false, 'error', 'SHARED_FUNDING_NOT_SUPPORTED');
  END IF;

  FOR v_gov IN SELECT unnest(v_period.participating_governorates)
  LOOP
    FOR v_row IN
      WITH agg AS (
        SELECT
          r.team_id,
          MAX(r.governorate) AS governorate,
          SUM(r.ranking_points)::INT AS ranking_points,
          SUM(r.wins)::INT AS wins,
          SUM(r.draws)::INT AS draws,
          SUM(r.losses)::INT AS losses,
          SUM(r.matches_played)::INT AS matches_played,
          MAX(r.last_match_at) AS last_match_at
        FROM public.team_monthly_rankings r
        WHERE r.month_key = ANY(v_period.month_keys)
          AND lower(btrim(r.governorate)) = lower(btrim(v_gov))
        GROUP BY r.team_id
      ),
      ranked AS (
        SELECT
          *,
          ROW_NUMBER() OVER (
            ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC, last_match_at ASC NULLS LAST
          )::INT AS final_rank
        FROM agg
      )
      SELECT * FROM ranked ORDER BY final_rank
    LOOP
      INSERT INTO public.competitive_period_snapshots (
        period_id, team_id, governorate, final_rank, ranking_points, wins, draws, losses, matches_played,
        tie_break_resolved, tie_break_note
      ) VALUES (
        v_period.id, v_row.team_id, v_row.governorate, v_row.final_rank, v_row.ranking_points,
        v_row.wins, v_row.draws, v_row.losses, v_row.matches_played,
        TRUE, 'Deterministic tie-break: points -> wins -> draws -> losses -> matches -> earliest last_match_at'
      )
      ON CONFLICT (period_id, team_id) DO NOTHING;

      IF FOUND THEN v_snap_cnt := v_snap_cnt + 1; END IF;

      -- Only Top 10 eligible teams receive entitlements (never fabricate missing teams)
      IF v_row.final_rank BETWEEN 1 AND 5 THEN
        v_cash_amt := COALESCE((v_period.prize_config->'cash'->>(v_row.final_rank::TEXT))::INT, 0);
        IF v_cash_amt > 0 AND (v_total_cash + v_cash_amt) <= COALESCE(v_period.budget_cap_egp, 2100) THEN
          v_total_cash := v_total_cash + v_cash_amt;
          INSERT INTO public.season_reward_entitlements (
            season_id, period_id, team_id, governorate, rank_position, zone_type, reward_type,
            cash_amount_egp, max_voucher_value_egp, status, payout_status, idempotency_key
          ) VALUES (
            v_period.season_id, v_period.id, v_row.team_id, v_row.governorate, v_row.final_rank,
            'cash_rewards', 'cash', v_cash_amt, 0, 'pending', 'pending_review',
            'period:' || v_period.id::TEXT || ':team:' || v_row.team_id::TEXT
          ) ON CONFLICT DO NOTHING;
          IF FOUND THEN v_ent_cnt := v_ent_cnt + 1; END IF;
        END IF;
      ELSIF v_row.final_rank BETWEEN 6 AND 10 AND v_free_cnt < 5 THEN
        v_free_cnt := v_free_cnt + 1;
        INSERT INTO public.season_reward_entitlements (
          season_id, period_id, team_id, governorate, rank_position, zone_type, reward_type,
          cash_amount_egp, max_voucher_value_egp, status, payout_status, sponsor_stadium_id,
          funding_source, eligible_time_windows, expires_at, idempotency_key
        ) VALUES (
          v_period.season_id, v_period.id, v_row.team_id, v_row.governorate, v_row.final_rank,
          'free_booking', 'free_hour', 0, 179, 'available', 'approved', v_period.sponsor_stadium_id,
          v_period.funding_source, v_period.eligible_time_windows, v_period.ends_at + interval '30 days',
          'period:' || v_period.id::TEXT || ':team:' || v_row.team_id::TEXT
        ) ON CONFLICT DO NOTHING;
        IF FOUND THEN v_ent_cnt := v_ent_cnt + 1; END IF;
      END IF;
    END LOOP;
  END LOOP;

  UPDATE public.competitive_reward_periods
  SET snapshot_frozen_at = COALESCE(snapshot_frozen_at, now()), updated_at = now()
  WHERE id = v_period.id;

  INSERT INTO public.competitive_reward_audit_logs (period_id, actor_user_id, action, new_state)
  VALUES (v_period.id, v_actor, 'snapshot_and_entitlements_generated', jsonb_build_object('snapshots', v_snap_cnt, 'entitlements', v_ent_cnt, 'cash_total', v_total_cash, 'free_hours', v_free_cnt));

  RETURN jsonb_build_object('success', true, 'snapshots', v_snap_cnt, 'entitlements', v_ent_cnt, 'cash_total_egp', v_total_cash, 'free_hours_count', v_free_cnt);
END;
$$;

-- 5. Harden admin_transition_competitive_period_state with strict guards
CREATE OR REPLACE FUNCTION public.admin_transition_competitive_period_state(
  p_period_id UUID,
  p_new_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_cur public.competitive_reward_periods%ROWTYPE;
  v_allowed BOOLEAN := FALSE;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

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
  END IF;

  IF p_new_status = 'completed' THEN
    IF EXISTS (
      SELECT 1 FROM public.season_reward_entitlements
      WHERE period_id = p_period_id
        AND ((reward_type = 'cash' AND payout_status IN ('pending_review', 'approved', 'processing'))
          OR (reward_type = 'free_hour' AND status IN ('available', 'reserved')))
    ) AND btrim(COALESCE(p_reason, '')) = '' THEN
      RETURN jsonb_build_object('success', false, 'error', 'OPEN_ENTITLEMENTS_REQUIRE_CLOSURE_REASON');
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

-- 6. Harden admin_approve_cash_reward_atomic & admin_mark_cash_reward_paid_atomic (recipient membership, blocked check, unique ref)
CREATE OR REPLACE FUNCTION public.admin_approve_cash_reward_atomic(
  p_entitlement_id UUID,
  p_authorized_recipient_user_id UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_ent public.season_reward_entitlements%ROWTYPE;
  v_period public.competitive_reward_periods%ROWTYPE;
  v_is_valid_recipient BOOLEAN := FALSE;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

  IF p_authorized_recipient_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTHORIZED_RECIPIENT_REQUIRED');
  END IF;

  SELECT * INTO v_ent FROM public.season_reward_entitlements WHERE id = p_entitlement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ENTITLEMENT_NOT_FOUND'); END IF;
  IF v_ent.reward_type <> 'cash' THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_CASH_REWARD'); END IF;
  IF v_ent.payout_status = 'paid' THEN RETURN jsonb_build_object('success', false, 'error', 'ALREADY_PAID'); END IF;
  IF v_ent.payout_status NOT IN ('pending_review', 'disputed', 'failed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_PAYOUT_STATUS_FOR_APPROVAL');
  END IF;

  IF v_ent.period_id IS NOT NULL THEN
    SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = v_ent.period_id;
    IF FOUND AND v_period.status NOT IN ('finalized', 'rewards_distribution') THEN
      RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FINALIZED');
    END IF;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_authorized_recipient_user_id
      AND u.is_blocked IS NOT TRUE
      AND (
        EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = v_ent.team_id AND tm.user_id = u.id)
        OR EXISTS (SELECT 1 FROM public.teams t WHERE t.id = v_ent.team_id AND t.captain_id = u.id)
      )
  ) INTO v_is_valid_recipient;

  IF NOT v_is_valid_recipient THEN
    RETURN jsonb_build_object('success', false, 'error', 'RECIPIENT_NOT_ACTIVE_TEAM_MEMBER');
  END IF;

  UPDATE public.season_reward_entitlements
  SET payout_status = 'approved',
      status = 'approved',
      authorized_recipient_user_id = p_authorized_recipient_user_id,
      approved_by = v_actor,
      notes = COALESCE(p_notes, notes),
      updated_at = now()
  WHERE id = p_entitlement_id;

  INSERT INTO public.competitive_reward_audit_logs (period_id, entitlement_id, actor_user_id, action, new_state, reason)
  VALUES (v_ent.period_id, p_entitlement_id, v_actor, 'cash_reward_approved', jsonb_build_object('recipient', p_authorized_recipient_user_id), p_notes);

  RETURN jsonb_build_object('success', true, 'payout_status', 'approved');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_mark_cash_reward_paid_atomic(
  p_entitlement_id UUID,
  p_delivery_method TEXT,
  p_delivery_reference TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_actor UUID := auth.uid();
  v_ent public.season_reward_entitlements%ROWTYPE;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

  IF btrim(COALESCE(p_delivery_method, '')) = '' OR btrim(COALESCE(p_delivery_reference, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'DELIVERY_METHOD_AND_REFERENCE_REQUIRED');
  END IF;

  SELECT * INTO v_ent FROM public.season_reward_entitlements WHERE id = p_entitlement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ENTITLEMENT_NOT_FOUND'); END IF;
  IF v_ent.reward_type <> 'cash' THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_CASH_REWARD'); END IF;
  IF v_ent.payout_status = 'paid' THEN RETURN jsonb_build_object('success', false, 'error', 'ALREADY_PAID'); END IF;
  IF v_ent.payout_status NOT IN ('approved', 'processing') THEN
    RETURN jsonb_build_object('success', false, 'error', 'MUST_BE_APPROVED_FIRST');
  END IF;
  IF v_actor IS NOT NULL AND v_ent.approved_by IS NOT DISTINCT FROM v_actor THEN
    RETURN jsonb_build_object('success', false, 'error', 'SEPARATION_OF_DUTIES_VIOLATION');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.season_reward_entitlements
    WHERE id <> p_entitlement_id AND delivery_reference = p_delivery_reference
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_DELIVERY_REFERENCE');
  END IF;

  UPDATE public.season_reward_entitlements
  SET payout_status = 'paid',
      status = 'redeemed',
      delivery_method = p_delivery_method,
      delivery_reference = p_delivery_reference,
      paid_by = v_actor,
      delivered_at = now(),
      updated_at = now()
  WHERE id = p_entitlement_id;

  INSERT INTO public.competitive_reward_audit_logs (period_id, entitlement_id, actor_user_id, action, new_state)
  VALUES (v_ent.period_id, p_entitlement_id, v_actor, 'cash_reward_paid', jsonb_build_object('method', p_delivery_method, 'ref', p_delivery_reference, 'amount', v_ent.cash_amount_egp));

  RETURN jsonb_build_object('success', true, 'payout_status', 'paid');
END;
$$;

-- 7. Harden get_competitive_rewards_analytics (reject invalid period_id instead of fallback)
CREATE OR REPLACE FUNCTION public.get_competitive_rewards_analytics(
  p_governorate TEXT DEFAULT NULL,
  p_period_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_period              public.competitive_reward_periods%ROWTYPE;
  v_active_teams        INT := 0;
  v_competitive_matches INT := 0;
  v_paid_bookings       INT := 0;
  v_vsp_commission_egp  NUMERIC := 0;
  v_cash_committed_egp  NUMERIC := 0;
  v_cash_paid_egp       NUMERIC := 0;
  v_free_hours_issued   INT := 0;
  v_free_hours_redeemed INT := 0;
  v_vsp_hours_cost_egp  NUMERIC := 0;
BEGIN
  PERFORM public.vsp_assert_admin_or_service_role();

  IF p_period_id IS NOT NULL THEN
    SELECT * INTO v_period FROM public.competitive_reward_periods WHERE id = p_period_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'PERIOD_NOT_FOUND');
    END IF;
  END IF;

  SELECT COUNT(DISTINCT r.team_id)::INT, COALESCE(SUM(r.matches_played), 0)::INT
  INTO v_active_teams, v_competitive_matches
  FROM public.team_monthly_rankings r
  WHERE (p_governorate IS NULL OR lower(btrim(r.governorate)) = lower(btrim(p_governorate)))
    AND (v_period.id IS NULL OR r.month_key = ANY(v_period.month_keys));

  SELECT COUNT(DISTINCT b.id)::INT,
         COALESCE(SUM(COALESCE(b.total_vsp_commission, b.vsp_commission, 0)), 0)
  INTO v_paid_bookings, v_vsp_commission_egp
  FROM public.bookings b
  JOIN public.stadiums s ON s.id = b.stadium_id
  WHERE b.payment_status = 'paid'
    AND b.status IN ('confirmed', 'completed')
    AND COALESCE(b.payment_method, '') NOT IN ('vsp_monthly_award', 'vsp_season_reward')
    AND (p_governorate IS NULL OR lower(btrim(s.governorate)) = lower(btrim(p_governorate)))
    AND (v_period.id IS NULL OR (b.start_time >= v_period.starts_at AND b.start_time <= v_period.ends_at));

  SELECT
    COALESCE(SUM(CASE WHEN reward_type = 'cash' AND status <> 'revoked' THEN cash_amount_egp ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN reward_type = 'cash' AND payout_status = 'paid' THEN cash_amount_egp ELSE 0 END), 0),
    COUNT(*) FILTER (WHERE reward_type = 'free_hour')::INT,
    COUNT(*) FILTER (WHERE reward_type = 'free_hour' AND status = 'redeemed')::INT,
    COALESCE(SUM(CASE WHEN reward_type = 'free_hour' AND status = 'redeemed' THEN COALESCE(reimbursed_amount_egp, 0) ELSE 0 END), 0)
  INTO v_cash_committed_egp, v_cash_paid_egp, v_free_hours_issued, v_free_hours_redeemed, v_vsp_hours_cost_egp
  FROM public.season_reward_entitlements
  WHERE (p_governorate IS NULL OR lower(btrim(governorate)) = lower(btrim(p_governorate)))
    AND (p_period_id IS NULL OR period_id = p_period_id);

  RETURN jsonb_build_object(
    'success', true,
    'period_id', p_period_id,
    'active_teams', v_active_teams,
    'competitive_matches', v_competitive_matches,
    'paid_bookings', v_paid_bookings,
    'vsp_commission_egp', v_vsp_commission_egp,
    'cash_committed_egp', v_cash_committed_egp,
    'cash_paid_egp', v_cash_paid_egp,
    'free_hours_issued', v_free_hours_issued,
    'free_hours_redeemed', v_free_hours_redeemed,
    'vsp_free_hours_cost_egp', v_vsp_hours_cost_egp
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_generate_period_snapshot_and_entitlements(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_transition_competitive_period_state(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_approve_cash_reward_atomic(UUID, UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_mark_cash_reward_paid_atomic(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_competitive_rewards_analytics(TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_generate_period_snapshot_and_entitlements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_transition_competitive_period_state(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_cash_reward_atomic(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_mark_cash_reward_paid_atomic(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_competitive_rewards_analytics(TEXT, UUID) TO authenticated;
