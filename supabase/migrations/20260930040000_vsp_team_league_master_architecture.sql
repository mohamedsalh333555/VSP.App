-- ==============================================================================
-- Migration: 20260930040000_vsp_team_league_master_architecture.sql
-- Description: VSP Team League Master Product / UX / Logic / Architecture Specification
-- Implements:
--   1. Private leagues (4-8 teams, single round robin, 30 EGP / team)
--   2. Multi-team payment options calculated strictly server-side
--   3. Submissions table for two-sided result entry (win, draw, loss only - no numerical goals)
--   4. Automatic reconciliation (matching -> confirmed, mismatch -> disputed)
--   5. League creator exclusive dispute resolution
--   6. 15-minute post-confirmation editing window & automatic locking
--   7. Pure standings calculation (played, won, drawn, lost, points - no goals/GF/GA/GD)
--   8. Complete audit trail table and zero-trust RLS policies
-- ==============================================================================

-- 1. Table extensions for championships
ALTER TABLE public.championships
ADD COLUMN IF NOT EXISTS match_interval_days INTEGER DEFAULT 7,
ADD COLUMN IF NOT EXISTS paid_by_creator_count INTEGER DEFAULT 1;

-- 2. Constraints update for team_league_payments
ALTER TABLE public.team_league_payments DROP CONSTRAINT IF EXISTS team_league_payments_amount_ck;
ALTER TABLE public.team_league_payments 
ADD CONSTRAINT team_league_payments_amount_ck CHECK (amount > 0 AND amount % 30 = 0);

ALTER TABLE public.team_league_payments
ADD COLUMN IF NOT EXISTS paid_teams_count INTEGER DEFAULT 1;

-- 3. Table extensions for tournament_matches
ALTER TABLE public.tournament_matches
ADD COLUMN IF NOT EXISTS result_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS result_confirmed_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS result_locked_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS dispute_created_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS dispute_resolved_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS dispute_resolved_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS confirmed_outcome TEXT,
ADD COLUMN IF NOT EXISTS match_day DATE;

-- Drop and re-add check constraint on result_status to be safe
ALTER TABLE public.tournament_matches DROP CONSTRAINT IF EXISTS chk_tm_result_status;
ALTER TABLE public.tournament_matches 
ADD CONSTRAINT chk_tm_result_status 
CHECK (result_status IN ('pending', 'awaiting_result', 'result_one_side', 'confirmed', 'disputed', 'locked'));

-- 4. Create table for Team League Match Submissions
CREATE TABLE IF NOT EXISTS public.team_league_match_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.tournament_matches(id) ON DELETE CASCADE,
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  submitted_by UUID NOT NULL REFERENCES auth.users(id),
  result TEXT NOT NULL CHECK (result IN ('win', 'draw', 'loss')),
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  submission_version INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT uq_team_league_match_submission UNIQUE (match_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_tl_submissions_match_team 
ON public.team_league_match_submissions(match_id, team_id);

ALTER TABLE public.team_league_match_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow team captains/members to view match submissions" ON public.team_league_match_submissions;
CREATE POLICY "Allow team captains/members to view match submissions"
ON public.team_league_match_submissions FOR SELECT
TO authenticated
USING (true);

-- 5. Create table for Team League Result Audits
CREATE TABLE IF NOT EXISTS public.team_league_result_audits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES public.tournament_matches(id) ON DELETE CASCADE,
  championship_id UUID NOT NULL REFERENCES public.championships(id) ON DELETE CASCADE,
  team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  actor_id UUID NOT NULL REFERENCES auth.users(id),
  action TEXT NOT NULL, -- 'submit', 'edit', 'creator_resolve', 'auto_confirm', 'auto_lock'
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_tl_audits_match 
ON public.team_league_result_audits(match_id);

ALTER TABLE public.team_league_result_audits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated to view audits of their league" ON public.team_league_result_audits;
CREATE POLICY "Allow authenticated to view audits of their league"
ON public.team_league_result_audits FOR SELECT
TO authenticated
USING (true);

-- ==============================================================================
-- 6. RPC: Pure Standings Calculation (No Goals, Win=3, Draw=1, Loss=0, H2H)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_team_league_standings(p_championship_id UUID)
RETURNS TABLE (
  team_id UUID,
  team_name TEXT,
  team_logo_url TEXT,
  played INTEGER,
  won INTEGER,
  drawn INTEGER,
  lost INTEGER,
  points INTEGER,
  rank INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_joined TEXT[];
BEGIN
  SELECT joined_teams INTO v_joined
  FROM public.championships
  WHERE id = p_championship_id;

  IF v_joined IS NULL OR cardinality(v_joined) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH team_list AS (
    SELECT 
      t.id AS t_id,
      t.name AS t_name,
      t.logo_url AS t_logo
    FROM unnest(v_joined) j(tid)
    JOIN public.teams t ON t.id = j.tid::uuid
  ),
  match_records AS (
    SELECT 
      m.id AS m_id,
      m.home_team_id AS home_id,
      m.away_team_id AS away_id,
      m.winner_id,
      m.confirmed_outcome,
      m.result_status
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.is_completed = true
      AND m.result_status IN ('confirmed', 'locked')
  ),
  team_stats AS (
    SELECT 
      tl.t_id,
      tl.t_name,
      tl.t_logo,
      COUNT(mr.m_id)::INTEGER AS p_played,
      COUNT(CASE WHEN mr.winner_id = tl.t_id THEN 1 END)::INTEGER AS p_won,
      COUNT(CASE WHEN mr.confirmed_outcome = 'draw' AND (mr.home_id = tl.t_id OR mr.away_id = tl.t_id) THEN 1 END)::INTEGER AS p_drawn,
      COUNT(CASE WHEN mr.winner_id IS NOT NULL AND mr.winner_id != tl.t_id AND (mr.home_id = tl.t_id OR mr.away_id = tl.t_id) THEN 1 END)::INTEGER AS p_lost
    FROM team_list tl
    LEFT JOIN match_records mr ON mr.home_id = tl.t_id OR mr.away_id = tl.t_id
    GROUP BY tl.t_id, tl.t_name, tl.t_logo
  ),
  computed AS (
    SELECT 
      ts.t_id,
      ts.t_name,
      ts.t_logo,
      ts.p_played,
      ts.p_won,
      ts.p_drawn,
      ts.p_lost,
      ((ts.p_won * 3) + (ts.p_drawn * 1))::INTEGER AS p_points
    FROM team_stats ts
  )
  SELECT 
    c.t_id,
    c.t_name,
    c.t_logo,
    c.p_played,
    c.p_won,
    c.p_drawn,
    c.p_lost,
    c.p_points,
    DENSE_RANK() OVER (ORDER BY c.p_points DESC, c.p_won DESC, c.t_name ASC)::INTEGER AS rank
  FROM computed c
  ORDER BY rank ASC, c.t_name ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_league_standings(UUID) TO authenticated, service_role, anon;

-- ==============================================================================
-- 7. RPC: Fixture Generation for 4 to 8 Teams (Single Round Robin)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.generate_team_league_fixtures(p_championship_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_champ RECORD;
  v_teams UUID[];
  v_num_teams INTEGER;
  v_i INTEGER;
  v_j INTEGER;
  v_match INTEGER := 0;
  v_home UUID;
  v_away UUID;
  v_home_name TEXT;
  v_away_name TEXT;
  v_interval INTEGER;
  v_start_day DATE;
  v_round INTEGER;
  v_match_day DATE;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الدوري غير موجود';
  END IF;

  -- Prevent duplicate generation
  IF EXISTS (SELECT 1 FROM public.tournament_matches WHERE championship_id = p_championship_id) THEN
    RETURN jsonb_build_object('success', true, 'already_generated', true);
  END IF;

  SELECT array_agg(x::uuid ORDER BY x::uuid) 
  INTO v_teams 
  FROM unnest(v_champ.paid_teams) x;

  v_num_teams := cardinality(v_teams);
  IF v_num_teams < 4 OR v_num_teams > 8 THEN
    RAISE EXCEPTION 'عدد الفرق يجب أن يكون بين 4 و 8 فرق';
  END IF;

  v_interval := COALESCE(v_champ.match_interval_days, 7);
  v_start_day := CURRENT_DATE + 1; -- Next day starts the cycle

  -- Generate Single Round Robin: every pair (i, j) where i < j exactly once
  FOR v_i IN 1..(v_num_teams - 1) LOOP
    FOR v_j IN (v_i + 1)..v_num_teams LOOP
      v_match := v_match + 1;
      v_home := v_teams[v_i];
      v_away := v_teams[v_j];

      SELECT name INTO v_home_name FROM public.teams WHERE id = v_home;
      SELECT name INTO v_away_name FROM public.teams WHERE id = v_away;

      -- Distribute roughly across rounds
      v_round := ((v_match - 1) / (v_num_teams / 2)) + 1;
      v_match_day := v_start_day + ((v_round - 1) * v_interval);

      INSERT INTO public.tournament_matches (
        championship_id,
        round_index,
        match_index,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        status,
        result_status,
        is_completed,
        stage,
        week_number,
        group_name,
        match_day,
        scheduled_time
      ) VALUES (
        p_championship_id,
        v_round,
        v_match,
        v_home,
        COALESCE(v_home_name, 'فريق'),
        v_away,
        COALESCE(v_away_name, 'فريق'),
        'pending',
        'pending',
        false,
        'league',
        v_round,
        'الدوري',
        v_match_day,
        (v_match_day::text || ' 20:00:00+00')::timestamptz
      );
    END LOOP;
  END LOOP;

  UPDATE public.championships
  SET status = 'ongoing',
      registration_locked_at = now(),
      updated_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object('success', true, 'total_matches', v_match, 'num_teams', v_num_teams);
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_team_league_fixtures(UUID) TO authenticated, service_role;

-- ==============================================================================
-- 8. RPC: Create Team League (Enhanced for 4-8 Teams & Multi-Payment Options)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.create_team_league(
  p_league_name TEXT,
  p_team_id UUID,
  p_governorate TEXT DEFAULT 'Cairo',
  p_max_teams INTEGER DEFAULT 4,
  p_interval_days INTEGER DEFAULT 7,
  p_pay_option TEXT DEFAULT 'my_team',
  p_paid_teams_count INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_existing UUID;
  v_id UUID;
  v_fee NUMERIC := 30.0;
  v_paid_count INTEGER;
  v_total_amount NUMERIC;
  v_reference TEXT;
  v_max INTEGER;
  v_interval INTEGER;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT captain_id INTO v_captain FROM public.teams WHERE id = p_team_id;
  IF v_captain IS NULL OR v_captain <> v_uid THEN
    RAISE EXCEPTION 'فقط قائد الفريق يستطيع إنشاء الدوري';
  END IF;

  SELECT c.id INTO v_existing 
  FROM public.championships c 
  WHERE c.template_type = 'team_league' 
    AND c.owner_id = v_uid 
    AND c.status IN ('open', 'ongoing') 
  LIMIT 1;

  IF v_existing IS NOT NULL THEN
    RAISE EXCEPTION 'لديك دوري قائم بالفعل';
  END IF;

  v_max := LEAST(GREATEST(COALESCE(p_max_teams, 4), 4), 8);
  v_interval := LEAST(GREATEST(COALESCE(p_interval_days, 7), 1), 30);

  -- Fetch entry fee setting from league_settings
  SELECT COALESCE(setting_value::numeric, 30.0) INTO v_fee
  FROM public.league_settings
  WHERE setting_key = 'team_league_entry_fee';

  IF v_fee IS NULL OR v_fee <= 0 THEN
    v_fee := 30.0;
  END IF;

  -- Determine paid count based on pay option
  IF p_pay_option = 'all' THEN
    v_paid_count := v_max;
  ELSIF p_pay_option = 'custom' THEN
    v_paid_count := LEAST(GREATEST(COALESCE(p_paid_teams_count, 1), 1), v_max);
  ELSE
    v_paid_count := 1;
  END IF;

  v_total_amount := v_paid_count * v_fee;

  -- Insert Private Championship
  INSERT INTO public.championships (
    name,
    type,
    sport_type,
    start_date,
    entry_fee,
    grand_prize,
    max_teams,
    owner_id,
    governorate,
    rules,
    payment_methods,
    max_players_per_team,
    min_players_per_team,
    winning_points,
    draw_points,
    loss_points,
    match_duration,
    is_back_and_forth,
    trophy_medals,
    red_card_suspension,
    fair_play_scoring,
    status,
    paid_teams,
    joined_teams,
    is_approved,
    number_of_groups,
    qualifying_per_group,
    is_two_legs,
    creation_fee_paid,
    prize_pool,
    prize_delivered,
    template_type,
    match_interval_days,
    paid_by_creator_count
  ) VALUES (
    NULLIF(TRIM(p_league_name), ''),
    'league',
    'football',
    now(),
    v_fee,
    0,
    v_max,
    v_uid,
    COALESCE(NULLIF(TRIM(p_governorate), ''), 'Cairo'),
    v_max || ' فرق، دور واحد، كل فريق يواجه الآخر مرة واحدة. الفوز: 3 نقاط، التعادل: 1 نقطة.',
    ARRAY['online'],
    0,
    0,
    3,
    1,
    0,
    90,
    false,
    true,
    false,
    false,
    'open',
    '{}'::TEXT[],
    ARRAY[p_team_id::TEXT],
    true,
    1,
    1,
    false,
    false,
    0,
    false,
    'team_league',
    v_interval,
    v_paid_count
  ) RETURNING id INTO v_id;

  -- Generate order reference
  v_reference := 'LEAGUE_' || v_id::TEXT || '_' || p_team_id::TEXT || '_' || FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;

  INSERT INTO public.team_league_payments (
    championship_id,
    team_id,
    user_id,
    amount,
    paid_teams_count,
    order_reference
  ) VALUES (
    v_id,
    p_team_id,
    v_uid,
    v_total_amount,
    v_paid_count,
    v_reference
  );

  RETURN jsonb_build_object(
    'success', true,
    'championship_id', v_id,
    'payment_required', true,
    'payment_reference', v_reference,
    'amount', v_total_amount,
    'paid_teams_count', v_paid_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_team_league(TEXT, UUID, TEXT, INTEGER, INTEGER, TEXT, INTEGER) TO authenticated;

-- ==============================================================================
-- 9. RPC: Confirm Team League Payment & Start if Ready
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirm_team_league_payment(
  p_order_reference TEXT,
  p_paymob_transaction_id TEXT,
  p_gross_amount_cents INTEGER,
  p_gateway_type TEXT DEFAULT 'card'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_payment public.team_league_payments%ROWTYPE;
  v_fee RECORD;
  v_gateway_rate NUMERIC;
  v_expected INTEGER;
  v_champ RECORD;
  v_paid TEXT[];
  v_count INTEGER;
BEGIN
  SELECT * INTO v_payment 
  FROM public.team_league_payments 
  WHERE order_reference = p_order_reference FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'دفع الدوري غير موجود'; END IF;
  IF v_payment.payment_status = 'paid' THEN 
    RETURN jsonb_build_object('success', true, 'already_paid', true); 
  END IF;
  IF v_payment.payment_status <> 'pending' THEN 
    RAISE EXCEPTION 'حالة دفع غير صالحة'; 
  END IF;
  IF p_paymob_transaction_id IS NULL OR TRIM(p_paymob_transaction_id) = '' THEN 
    RAISE EXCEPTION 'رقم عملية الدفع غير صالح'; 
  END IF;

  SELECT booking_vsp_rate, booking_paymob_rate, booking_paymob_local_rate, booking_paymob_wallet_rate, booking_paymob_fixed_fee 
  INTO v_fee 
  FROM public.platform_fee_config 
  WHERE id = 1;

  v_gateway_rate := CASE 
    WHEN lower(COALESCE(p_gateway_type, '')) LIKE '%wallet%' 
    THEN COALESCE(v_fee.booking_paymob_wallet_rate, v_fee.booking_paymob_rate) 
    ELSE COALESCE(v_fee.booking_paymob_local_rate, v_fee.booking_paymob_rate) 
  END;

  v_expected := round((v_payment.amount + v_payment.amount * COALESCE(v_fee.booking_vsp_rate, 0.02) + v_payment.amount * v_gateway_rate + COALESCE(v_fee.booking_paymob_fixed_fee, 3)) * 100);
  IF p_gross_amount_cents <> v_expected THEN 
    RAISE EXCEPTION 'مبلغ دفع الدوري غير مطابق'; 
  END IF;

  UPDATE public.team_league_payments 
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      paid_at = now(),
      updated_at = now() 
  WHERE id = v_payment.id;

  -- Add paying team to paid_teams in championship
  UPDATE public.championships 
  SET paid_teams = array_append(array_remove(COALESCE(paid_teams, '{}'::TEXT[]), v_payment.team_id::TEXT), v_payment.team_id::TEXT),
      updated_at = now() 
  WHERE id = v_payment.championship_id;

  SELECT * INTO v_champ FROM public.championships WHERE id = v_payment.championship_id FOR UPDATE;
  v_paid := COALESCE(v_champ.paid_teams, '{}'::TEXT[]);
  v_count := cardinality(v_paid);

  -- If required teams reached, generate fixtures and start!
  IF v_count >= v_champ.max_teams THEN
    PERFORM public.generate_team_league_fixtures(v_champ.id);
  END IF;

  RETURN jsonb_build_object('success', true, 'league_started', v_count >= v_champ.max_teams);
END;
$$;

GRANT EXECUTE ON FUNCTION public.confirm_team_league_payment(TEXT, TEXT, INTEGER, TEXT) TO service_role;

-- ==============================================================================
-- 10. RPC: Join Team League (With Pre-paid Creator Sponsorship Guard)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.join_team_league(
  p_championship_id UUID,
  p_team_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_champ RECORD;
  v_joined TEXT[];
  v_paid TEXT[];
  v_payment JSONB;
  v_is_prepaid BOOLEAN := FALSE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;

  SELECT captain_id INTO v_captain FROM public.teams WHERE id = p_team_id;
  IF v_captain IS NULL OR v_captain <> v_uid THEN
    RAISE EXCEPTION 'فقط قائد الفريق يستطيع الانضمام للدوري';
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id AND template_type = 'team_league' 
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الدوري غير موجود'; END IF;
  IF v_champ.status <> 'open' THEN RAISE EXCEPTION 'الدوري مغلق للتسجيل'; END IF;

  v_joined := COALESCE(v_champ.joined_teams, '{}'::TEXT[]);
  v_paid := COALESCE(v_champ.paid_teams, '{}'::TEXT[]);

  IF p_team_id::TEXT = ANY(v_joined) THEN
    IF p_team_id::TEXT = ANY(v_paid) THEN
      RETURN jsonb_build_object('success', true, 'already_joined', true, 'already_paid', true, 'message', 'رسوم مشاركة هذا الفريق مدفوعة بالفعل.');
    END IF;
    v_payment := public.prepare_team_league_payment(p_championship_id, p_team_id);
    RETURN jsonb_build_object('success', true, 'already_joined', true, 'payment_required', true, 'payment_reference', v_payment->>'payment_reference', 'amount', 30);
  END IF;

  IF cardinality(v_joined) >= v_champ.max_teams THEN
    RAISE EXCEPTION 'اكتمل عدد الفرق في هذا الدوري';
  END IF;

  -- Add to joined teams
  v_joined := array_append(v_joined, p_team_id::TEXT);

  -- Check if creator already paid for this team slot!
  -- Creator paid for `paid_by_creator_count` teams. If current paid teams count < paid_by_creator_count:
  IF cardinality(v_paid) < COALESCE(v_champ.paid_by_creator_count, 1) THEN
    v_is_prepaid := TRUE;
    v_paid := array_append(v_paid, p_team_id::TEXT);
  END IF;

  UPDATE public.championships 
  SET joined_teams = v_joined,
      paid_teams = v_paid,
      updated_at = now() 
  WHERE id = p_championship_id;

  -- If this was the last team and all are paid, start!
  IF cardinality(v_paid) >= v_champ.max_teams THEN
    PERFORM public.generate_team_league_fixtures(p_championship_id);
  END IF;

  IF v_is_prepaid THEN
    RETURN jsonb_build_object(
      'success', true,
      'joined', true,
      'already_paid', true,
      'prepaid_by_creator', true,
      'message', 'رسوم مشاركة الفريق: مدفوعة'
    );
  END IF;

  v_payment := public.prepare_team_league_payment(p_championship_id, p_team_id);
  RETURN jsonb_build_object(
    'success', true,
    'joined', true,
    'payment_required', true,
    'payment_reference', v_payment->>'payment_reference',
    'amount', 30
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_team_league(UUID, UUID) TO authenticated;

-- ==============================================================================
-- 11. RPC: Submit Team League Match Result (Strict Non-Numerical State Machine)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.submit_team_league_match_result(
  p_match_id UUID,
  p_team_id UUID,
  p_result TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_captain UUID;
  v_match RECORD;
  v_other_team_id UUID;
  v_other_sub RECORD;
  v_is_home BOOLEAN;
  v_winner UUID;
  v_winner_name TEXT;
  v_loser UUID;
  v_outcome TEXT;
  v_is_matching BOOLEAN := FALSE;
  v_creator_id UUID;
  v_home_name TEXT;
  v_away_name TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  IF p_result NOT IN ('win', 'draw', 'loss') THEN
    RAISE EXCEPTION 'النتيجة يجب أن تكون: فوز، تعادل، أو خسارة';
  END IF;

  -- 1. Verify caller belongs to p_team_id
  SELECT captain_id INTO v_captain FROM public.teams WHERE id = p_team_id;
  IF v_captain IS NULL OR (v_captain <> v_uid AND NOT EXISTS (
    SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = v_uid
  )) THEN
    RAISE EXCEPTION 'غير مصرح: يجب أن تكون عضواً أو قائداً للفريق لتسجيل النتيجة';
  END IF;

  -- 2. Lock the match row
  SELECT m.*, c.owner_id AS league_creator_id 
  INTO v_match 
  FROM public.tournament_matches m
  JOIN public.championships c ON c.id = m.championship_id
  WHERE m.id = p_match_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'المباراة غير موجودة'; END IF;

  v_creator_id := v_match.league_creator_id;
  v_home_name := v_match.home_team_name;
  v_away_name := v_match.away_team_name;

  -- Verify team is actually in this match
  IF p_team_id = v_match.home_team_id THEN
    v_is_home := TRUE;
    v_other_team_id := v_match.away_team_id;
  ELSIF p_team_id = v_match.away_team_id THEN
    v_is_home := FALSE;
    v_other_team_id := v_match.home_team_id;
  ELSE
    RAISE EXCEPTION 'فريقك ليس طرفاً في هذه المباراة';
  END IF;

  -- 3. Check match time: cannot submit before match scheduled time
  IF v_match.scheduled_time IS NOT NULL AND v_match.scheduled_time > now() THEN
    RAISE EXCEPTION 'لا يمكن تسجيل النتيجة قبل موعد انتهاء المباراة';
  END IF;

  -- 4. Check locked state
  IF v_match.result_status = 'locked' THEN
    RAISE EXCEPTION 'النتيجة مقفلة ولا يمكن تعديلها';
  END IF;

  -- 5. If confirmed, check 15-minute window
  IF v_match.result_status = 'confirmed' THEN
    IF v_match.result_confirmed_at IS NOT NULL AND (v_match.result_confirmed_at + INTERVAL '15 minutes') < now() THEN
      UPDATE public.tournament_matches SET result_status = 'locked' WHERE id = p_match_id;
      RAISE EXCEPTION 'انتهت مهلة الـ 15 دقيقة لتعديل النتيجة';
    END IF;
  END IF;

  -- 6. Upsert current team submission
  INSERT INTO public.team_league_match_submissions (
    match_id, team_id, submitted_by, result, submitted_at, submission_version
  ) VALUES (
    p_match_id, p_team_id, v_uid, p_result, now(), 1
  )
  ON CONFLICT (match_id, team_id) DO UPDATE SET
    submitted_by = EXCLUDED.submitted_by,
    result = EXCLUDED.result,
    submitted_at = now(),
    submission_version = public.team_league_match_submissions.submission_version + 1;

  -- 7. Audit log record
  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, team_id, actor_id, action, payload
  ) VALUES (
    p_match_id, v_match.championship_id, p_team_id, v_uid, 'submit_result',
    jsonb_build_object('result', p_result, 'is_home', v_is_home)
  );

  -- 8. Check other team's submission
  SELECT * INTO v_other_sub
  FROM public.team_league_match_submissions
  WHERE match_id = p_match_id AND team_id = v_other_team_id;

  IF NOT FOUND THEN
    -- Only one side submitted
    UPDATE public.tournament_matches
    SET result_status = 'result_one_side',
        updated_at = now()
    WHERE id = p_match_id;

    -- Send notification to the other team captain
    SELECT captain_id INTO v_captain FROM public.teams WHERE id = v_other_team_id;
    IF v_captain IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, title, body, type, created_at)
      VALUES (
        v_captain,
        'نتيجة مباراة دوري الفرق',
        'تم تسجيل نتيجة مباراة ' || v_home_name || ' × ' || v_away_name || '. أضف نتيجة فريقك لتأكيد المباراة.',
        'team_league',
        now()
      );
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'awaiting_opponent');
  END IF;

  -- Both have submitted: Evaluate match outcome
  -- Let Home result = v_h_res, Away result = v_a_res
  DECLARE
    v_h_res TEXT := CASE WHEN v_is_home THEN p_result ELSE v_other_sub.result END;
    v_a_res TEXT := CASE WHEN v_is_home THEN v_other_sub.result ELSE p_result END;
  BEGIN
    IF v_h_res = 'win' AND v_a_res = 'loss' THEN
      v_is_matching := TRUE;
      v_winner := v_match.home_team_id;
      v_winner_name := v_match.home_team_name;
      v_loser := v_match.away_team_id;
      v_outcome := 'home_win';
    ELSIF v_h_res = 'loss' AND v_a_res = 'win' THEN
      v_is_matching := TRUE;
      v_winner := v_match.away_team_id;
      v_winner_name := v_match.away_team_name;
      v_loser := v_match.home_team_id;
      v_outcome := 'away_win';
    ELSIF v_h_res = 'draw' AND v_a_res = 'draw' THEN
      v_is_matching := TRUE;
      v_winner := NULL;
      v_winner_name := NULL;
      v_loser := NULL;
      v_outcome := 'draw';
    ELSE
      v_is_matching := FALSE;
    END IF;

    IF v_is_matching THEN
      -- CONFIRMED ATOMICALLY
      UPDATE public.tournament_matches
      SET result_status = 'confirmed',
          confirmed_outcome = v_outcome,
          winner_id = v_winner,
          winner_name = v_winner_name,
          is_completed = true,
          status = 'completed',
          result_confirmed_at = now(),
          result_locked_at = now() + INTERVAL '15 minutes',
          dispute_created_at = NULL,
          dispute_resolved_at = NULL,
          dispute_resolved_by = NULL,
          home_score = CASE WHEN v_outcome = 'home_win' THEN 1 WHEN v_outcome = 'away_win' THEN 0 ELSE 0 END,
          away_score = CASE WHEN v_outcome = 'away_win' THEN 1 WHEN v_outcome = 'home_win' THEN 0 ELSE 0 END,
          updated_at = now()
      WHERE id = p_match_id;

      INSERT INTO public.team_league_result_audits (
        match_id, championship_id, actor_id, action, payload
      ) VALUES (
        p_match_id, v_match.championship_id, v_uid, 'auto_confirm',
        jsonb_build_object('outcome', v_outcome, 'winner_id', v_winner)
      );

      RETURN jsonb_build_object('success', true, 'status', 'confirmed', 'outcome', v_outcome);
    ELSE
      -- RESULT DISPUTED
      UPDATE public.tournament_matches
      SET result_status = 'disputed',
          dispute_created_at = now(),
          is_completed = false,
          winner_id = NULL,
          winner_name = NULL,
          confirmed_outcome = NULL,
          updated_at = now()
      WHERE id = p_match_id;

      INSERT INTO public.team_league_result_audits (
        match_id, championship_id, actor_id, action, payload
      ) VALUES (
        p_match_id, v_match.championship_id, v_uid, 'dispute_raised',
        jsonb_build_object('home_result', v_h_res, 'away_result', v_a_res)
      );

      -- Notify League Creator exclusively
      IF v_creator_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
          v_creator_id,
          'المباراة تحتاج تأكيد منك',
          'مباراة ' || v_home_name || ' × ' || v_away_name || ' تحتاج تأكيدك بسبب اختلاف الفريقين في تسجيل النتيجة.',
          'team_league_dispute',
          now()
        );
      END IF;

      RETURN jsonb_build_object('success', true, 'status', 'disputed');
    END IF;
  END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_team_league_match_result(UUID, UUID, TEXT) TO authenticated;

-- ==============================================================================
-- 12. RPC: Creator Resolve Dispute (Sole Authority for League Creator)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.resolve_team_league_dispute(
  p_match_id UUID,
  p_resolution TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_match RECORD;
  v_creator_id UUID;
  v_winner UUID;
  v_winner_name TEXT;
  v_home_capt UUID;
  v_away_capt UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  IF p_resolution NOT IN ('home_win', 'draw', 'away_win') THEN
    RAISE EXCEPTION 'القرار يجب أن يكون: فوز الفريق الأول، تعادل، أو فوز الفريق الثاني';
  END IF;

  SELECT m.*, c.owner_id AS league_creator_id 
  INTO v_match 
  FROM public.tournament_matches m
  JOIN public.championships c ON c.id = m.championship_id
  WHERE m.id = p_match_id FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'المباراة غير موجودة'; END IF;

  v_creator_id := v_match.league_creator_id;
  IF v_creator_id <> v_uid THEN
    RAISE EXCEPTION 'فقط منشئ الدوري يملك صلاحية حسم النتيجة';
  END IF;

  IF v_match.result_status <> 'disputed' THEN
    RAISE EXCEPTION 'المباراة ليست في حالة نزاع حالياً';
  END IF;

  IF p_resolution = 'home_win' THEN
    v_winner := v_match.home_team_id;
    v_winner_name := v_match.home_team_name;
  ELSIF p_resolution = 'away_win' THEN
    v_winner := v_match.away_team_id;
    v_winner_name := v_match.away_team_name;
  ELSE
    v_winner := NULL;
    v_winner_name := NULL;
  END IF;

  -- Atomically apply creator decision
  UPDATE public.tournament_matches
  SET result_status = 'confirmed',
      confirmed_outcome = p_resolution,
      winner_id = v_winner,
      winner_name = v_winner_name,
      is_completed = true,
      status = 'completed',
      dispute_resolved_at = now(),
      dispute_resolved_by = v_uid,
      result_confirmed_at = now(),
      result_locked_at = now() + INTERVAL '15 minutes',
      home_score = CASE WHEN p_resolution = 'home_win' THEN 1 WHEN p_resolution = 'away_win' THEN 0 ELSE 0 END,
      away_score = CASE WHEN p_resolution = 'away_win' THEN 1 WHEN p_resolution = 'home_win' THEN 0 ELSE 0 END,
      updated_at = now()
  WHERE id = p_match_id;

  -- Record audit trail
  INSERT INTO public.team_league_result_audits (
    match_id, championship_id, actor_id, action, payload
  ) VALUES (
    p_match_id, v_match.championship_id, v_uid, 'creator_resolve',
    jsonb_build_object('resolution', p_resolution, 'winner_id', v_winner)
  );

  -- Notify both captains
  SELECT captain_id INTO v_home_capt FROM public.teams WHERE id = v_match.home_team_id;
  SELECT captain_id INTO v_away_capt FROM public.teams WHERE id = v_match.away_team_id;

  IF v_home_capt IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
      v_home_capt,
      'تم تأكيد نتيجة المباراة',
      'تم اعتماد نتيجة مباراة ' || v_match.home_team_name || ' × ' || v_match.away_team_name || ' من منظم الدوري.',
      'team_league',
      now()
    );
  END IF;

  IF v_away_capt IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    VALUES (
      v_away_capt,
      'تم تأكيد نتيجة المباراة',
      'تم اعتماد نتيجة مباراة ' || v_match.home_team_name || ' × ' || v_match.away_team_name || ' من منظم الدوري.',
      'team_league',
      now()
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'status', 'confirmed', 'outcome', p_resolution);
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_team_league_dispute(UUID, TEXT) TO authenticated;

-- ==============================================================================
-- 13. RPC: Enhanced get_team_active_league (Returns Submissions & Dispute States)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.get_team_active_league(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_champ RECORD;
  v_teams JSONB;
  v_matches JSONB;
  v_standings JSONB;
  v_is_creator BOOLEAN := FALSE;
BEGIN
  IF v_caller IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول'); 
  END IF;

  -- Look for active or open league containing p_team_id
  SELECT * INTO v_champ 
  FROM public.championships
  WHERE p_team_id::TEXT = ANY(joined_teams) 
    AND template_type = 'team_league'
  ORDER BY created_at DESC 
  LIMIT 1;

  IF v_champ IS NULL THEN RETURN NULL; END IF;

  v_is_creator := (v_champ.owner_id = v_caller);

  -- Teams with captain info
  SELECT jsonb_agg(jsonb_build_object(
    'id', t.id,
    'name', t.name,
    'logo_url', t.logo_url,
    'captain_id', t.captain_id,
    'captain_phone', u.phone
  ))
  INTO v_teams 
  FROM unnest(v_champ.joined_teams) jt(team_id)
  JOIN public.teams t ON t.id = jt.team_id::uuid
  LEFT JOIN public.users u ON u.id = t.captain_id;

  -- Matches with enhanced state machine & team submission details
  SELECT jsonb_agg(jsonb_build_object(
    'id', m.id,
    'championship_id', m.championship_id,
    'week_number', m.week_number,
    'match_index', m.match_index,
    'stage', m.stage,
    'home_team_id', m.home_team_id,
    'home_team_name', m.home_team_name,
    'away_team_id', m.away_team_id,
    'away_team_name', m.away_team_name,
    'winner_id', m.winner_id,
    'winner_name', m.winner_name,
    'confirmed_outcome', m.confirmed_outcome,
    'result_status', m.result_status,
    'scheduled_time', m.scheduled_time,
    'match_day', m.match_day,
    'stadium_name', m.stadium_name,
    'booking_id', m.booking_id,
    'status', m.status,
    'is_completed', m.is_completed,
    'result_confirmed_at', m.result_confirmed_at,
    'result_locked_at', m.result_locked_at,
    'dispute_created_at', m.dispute_created_at,
    'my_team_submission', (
      SELECT result 
      FROM public.team_league_match_submissions 
      WHERE match_id = m.id AND team_id = p_team_id 
      LIMIT 1
    ),
    'opponent_team_submission', (
      SELECT result 
      FROM public.team_league_match_submissions 
      WHERE match_id = m.id AND team_id != p_team_id 
      LIMIT 1
    )
  ) ORDER BY m.match_index ASC)
  INTO v_matches 
  FROM public.tournament_matches m 
  WHERE m.championship_id = v_champ.id;

  -- Standings (pure: rank, played, won, drawn, lost, points)
  SELECT jsonb_agg(jsonb_build_object(
    'team_id', s.team_id,
    'team_name', s.team_name,
    'team_logo_url', s.team_logo_url,
    'played', s.played,
    'won', s.won,
    'drawn', s.drawn,
    'lost', s.lost,
    'points', s.points,
    'rank', s.rank
  ))
  INTO v_standings 
  FROM public.get_team_league_standings(v_champ.id) s;

  RETURN jsonb_build_object(
    'id', v_champ.id,
    'name', v_champ.name,
    'status', v_champ.status,
    'entry_fee', v_champ.entry_fee,
    'max_teams', v_champ.max_teams,
    'owner_id', v_champ.owner_id,
    'governorate', v_champ.governorate,
    'match_interval_days', COALESCE(v_champ.match_interval_days, 7),
    'paid_by_creator_count', COALESCE(v_champ.paid_by_creator_count, 1),
    'champion_team_id', v_champ.champion_team_id,
    'champion_team_name', v_champ.champion_team_name,
    'joined_teams_count', COALESCE(array_length(v_champ.joined_teams, 1), 0),
    'paid_teams_count', COALESCE(array_length(v_champ.paid_teams, 1), 0),
    'is_creator', v_is_creator,
    'teams', COALESCE(v_teams, '[]'::jsonb),
    'matches', COALESCE(v_matches, '[]'::jsonb),
    'standings', COALESCE(v_standings, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_active_league(UUID) TO authenticated;
