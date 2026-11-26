-- =============================================================
-- VSP Phase 2B: Complete Gamification, Competitive Ranking,
-- Annual Seasons, 6 Shields, Progressive Missions, Immortal Rewards,
-- Strongest Team Championship, Field Championship XP & 1v1 Sunset
-- Migration: 20261126050000_gamification_seasons_xp_ranking_shields.sql
-- =============================================================
BEGIN;

-- ============================================================
-- 1. FEATURE FLAG & SYSTEM CONFIG
-- ============================================================
INSERT INTO public.app_config (id, vsp_1v1_is_open)
VALUES (1, false)
ON CONFLICT (id) DO UPDATE SET vsp_1v1_is_open = false;

-- ============================================================
-- 2. ANNUAL SEASONS (starts Feb 2027, admin-configurable)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.competition_seasons (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_code       TEXT NOT NULL UNIQUE,
  year_number       INTEGER NOT NULL,
  name_ar           TEXT NOT NULL,
  name_en           TEXT NOT NULL,
  starts_at         TIMESTAMPTZ NOT NULL,
  ends_at           TIMESTAMPTZ NOT NULL,
  status            TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('draft','active','closed','archived')),
  rules_config      JSONB NOT NULL DEFAULT jsonb_build_object(
    'base_xp', jsonb_build_object('win', 80, 'draw', 65, 'loss', 50),
    'repeat_opponent_multiplier', 0.5,
    'shields', jsonb_build_object(
      'gold', 1500, 'platinum', 3000, 'diamond', 5000,
      'elite', 8000, 'legendary', 12000, 'immortal_xp', 15000, 'immortal_challenges', 60
    ),
    'field_championship_xp', jsonb_build_object('first', 800, 'second', 600, 'participant', 200),
    'strongest_team_xp', jsonb_build_object('first', 1400, 'second', 1100, 'third', 800, 'fourth', 600)
  ),
  closed_at         TIMESTAMPTZ,
  created_by        UUID REFERENCES public.users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_competition_season
  ON public.competition_seasons (status)
  WHERE status = 'active';

INSERT INTO public.competition_seasons (season_code, year_number, name_ar, name_en, starts_at, ends_at, status)
VALUES (
  '2027',
  2027,
  'الموسم الأول 2027',
  'Season 1 — 2027',
  '2027-02-01 00:00:00+02'::timestamptz,
  '2027-12-31 23:59:59+02'::timestamptz,
  'active'
)
ON CONFLICT (season_code) DO NOTHING;

-- Helper: current Cairo time, month_key (YYYY-MM), active season
CREATE OR REPLACE FUNCTION public.vsp_cairo_month_key(p_ts timestamptz DEFAULT now())
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT to_char(p_ts AT TIME ZONE 'Africa/Cairo', 'YYYY-MM');
$$;

CREATE OR REPLACE FUNCTION public.vsp_get_active_season()
RETURNS public.competition_seasons
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT * FROM public.competition_seasons
  WHERE status = 'active'
  ORDER BY starts_at DESC
  LIMIT 1;
$$;

-- ============================================================
-- 3. IMMUTABLE TEAM XP LEDGER & PROGRESS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.team_xp_ledger (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id         UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id           UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  source_type       TEXT NOT NULL CHECK (source_type IN (
                      'challenge_result','monthly_mission','field_championship',
                      'strongest_team','admin_adjustment','admin_reversal'
                    )),
  source_ref_id     TEXT NOT NULL,
  idempotency_key   TEXT NOT NULL UNIQUE,
  xp_delta          NUMERIC(12,2) NOT NULL CHECK (xp_delta <> 0),
  is_reversal       BOOLEAN NOT NULL DEFAULT false,
  reversed_entry_id UUID REFERENCES public.team_xp_ledger(id),
  month_key         TEXT NOT NULL,
  is_repeat_opponent BOOLEAN NOT NULL DEFAULT false,
  opponent_team_id  UUID REFERENCES public.teams(id) ON DELETE SET NULL,
  reason            TEXT,
  metadata          JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by        UUID REFERENCES public.users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xp_ledger_team_season
  ON public.team_xp_ledger (season_id, team_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_xp_ledger_single_reversal
  ON public.team_xp_ledger (reversed_entry_id)
  WHERE is_reversal = true AND reversed_entry_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.team_season_progress (
  season_id                   UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id                     UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  total_xp                    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
  approved_challenges_count   INTEGER NOT NULL DEFAULT 0,
  weighted_challenges_count   NUMERIC(10,2) NOT NULL DEFAULT 0,
  challenge_wins              INTEGER NOT NULL DEFAULT 0,
  challenge_draws             INTEGER NOT NULL DEFAULT 0,
  challenge_losses            INTEGER NOT NULL DEFAULT 0,
  tournaments_completed_count INTEGER NOT NULL DEFAULT 0,
  tournaments_won_count       INTEGER NOT NULL DEFAULT 0,
  strongest_team_participations INTEGER NOT NULL DEFAULT 0,
  strongest_team_wins         INTEGER NOT NULL DEFAULT 0,
  current_shield              TEXT NOT NULL DEFAULT 'none'
                              CHECK (current_shield IN ('none','gold','platinum','diamond','elite','legendary','immortal')),
  highest_shield_reached      TEXT NOT NULL DEFAULT 'none'
                              CHECK (highest_shield_reached IN ('none','gold','platinum','diamond','elite','legendary','immortal')),
  shield_unlocked_at          TIMESTAMPTZ,
  immortal_qualified_at       TIMESTAMPTZ,
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (season_id, team_id)
);

CREATE INDEX IF NOT EXISTS idx_team_season_progress_active
  ON public.team_season_progress (season_id, approved_challenges_count DESC, total_xp DESC);

CREATE TABLE IF NOT EXISTS public.team_season_opponents (
  season_id             UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id               UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  opponent_team_id      UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  first_match_booking_id UUID,
  matches_count         INTEGER NOT NULL DEFAULT 1,
  first_played_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_played_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (season_id, team_id, opponent_team_id)
);

CREATE TABLE IF NOT EXISTS public.team_monthly_opponents (
  season_id         UUID NOT NULL REFERENCES public.competition_seasons(id),
  month_key         TEXT NOT NULL,
  team_id           UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  opponent_team_id  UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  first_played_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (season_id, month_key, team_id, opponent_team_id)
);

CREATE TABLE IF NOT EXISTS public.team_monthly_mission_progress (
  season_id             UUID NOT NULL REFERENCES public.competition_seasons(id),
  month_key             TEXT NOT NULL,
  team_id               UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  challenges_completed  INTEGER NOT NULL DEFAULT 0,
  challenge_weights     JSONB NOT NULL DEFAULT '[]'::jsonb,
  challenge_wins        INTEGER NOT NULL DEFAULT 0,
  win_weights           JSONB NOT NULL DEFAULT '[]'::jsonb,
  unique_opponents      INTEGER NOT NULL DEFAULT 0,
  tournaments_completed INTEGER NOT NULL DEFAULT 0,
  claimed_tiers         TEXT[] NOT NULL DEFAULT ARRAY[]::text[],
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (season_id, month_key, team_id)
);

-- ============================================================
-- 4. MONTHLY COMPETITIVE RANKING & NON-EXPIRING FREE HOUR AWARDS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.team_monthly_rankings (
  season_id       UUID NOT NULL REFERENCES public.competition_seasons(id),
  month_key       TEXT NOT NULL,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  governorate     TEXT NOT NULL,
  sport_type      TEXT NOT NULL DEFAULT 'Football',
  ranking_points  INTEGER NOT NULL DEFAULT 0,
  matches_played  INTEGER NOT NULL DEFAULT 0,
  wins            INTEGER NOT NULL DEFAULT 0,
  draws           INTEGER NOT NULL DEFAULT 0,
  losses          INTEGER NOT NULL DEFAULT 0,
  last_match_at   TIMESTAMPTZ,
  is_frozen       BOOLEAN NOT NULL DEFAULT false,
  final_rank      INTEGER,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (season_id, month_key, team_id)
);

CREATE INDEX IF NOT EXISTS idx_monthly_ranking_gov
  ON public.team_monthly_rankings (month_key, governorate, ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC);

CREATE TABLE IF NOT EXISTS public.monthly_champion_awards (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id            UUID NOT NULL REFERENCES public.competition_seasons(id),
  month_key            TEXT NOT NULL,
  governorate          TEXT NOT NULL,
  team_id              UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  final_rank           INTEGER NOT NULL DEFAULT 1,
  ranking_points       INTEGER NOT NULL,
  wins                 INTEGER NOT NULL,
  draws                INTEGER NOT NULL,
  losses               INTEGER NOT NULL,
  matches_played       INTEGER NOT NULL,
  status               TEXT NOT NULL DEFAULT 'issued'
                       CHECK (status IN ('issued','redeemed','voided')),
  redeemed_booking_id  UUID REFERENCES public.bookings(id),
  redeemed_at          TIMESTAMPTZ,
  reimbursed_amount_egp NUMERIC(10,2),
  admin_notes          TEXT,
  issued_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (season_id, month_key, governorate, team_id)
);

CREATE TABLE IF NOT EXISTS public.ranking_disputes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id       UUID NOT NULL REFERENCES public.competition_seasons(id),
  month_key       TEXT NOT NULL,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  booking_id      UUID REFERENCES public.bookings(id),
  dispute_type    TEXT NOT NULL DEFAULT 'ranking' CHECK (dispute_type IN ('ranking','xp','mission','challenge_result')),
  reason          TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','under_review','resolved_upheld','resolved_adjusted','rejected')),
  resolution_note TEXT,
  created_by      UUID NOT NULL REFERENCES public.users(id),
  resolved_by     UUID REFERENCES public.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at     TIMESTAMPTZ
);

-- ============================================================
-- 5. TEAM ACHIEVEMENTS (14 permanent achievements, 0 extra XP)
--    AND TEAM SEASON HISTORY ARCHIVE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.team_achievements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id       UUID REFERENCES public.competition_seasons(id),
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  code            TEXT NOT NULL,
  title_ar        TEXT NOT NULL,
  title_en        TEXT NOT NULL,
  description_ar  TEXT NOT NULL,
  description_en  TEXT NOT NULL,
  category        TEXT NOT NULL CHECK (category IN ('challenge','streak','ranking','tournament','strongest_team','shield','immortal')),
  period_key      TEXT NOT NULL DEFAULT '',
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  unlocked_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (team_id, code, period_key)
);

CREATE TABLE IF NOT EXISTS public.team_season_history (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id               UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id                 UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  year_number             INTEGER NOT NULL,
  final_shield            TEXT NOT NULL DEFAULT 'none',
  final_xp                NUMERIC(12,2) NOT NULL DEFAULT 0,
  approved_challenges     INTEGER NOT NULL DEFAULT 0,
  weighted_challenges     NUMERIC(10,2) NOT NULL DEFAULT 0,
  wins                    INTEGER NOT NULL DEFAULT 0,
  draws                   INTEGER NOT NULL DEFAULT 0,
  losses                  INTEGER NOT NULL DEFAULT 0,
  tournaments_completed   INTEGER NOT NULL DEFAULT 0,
  tournaments_won         INTEGER NOT NULL DEFAULT 0,
  best_monthly_rank       INTEGER,
  most_active_rank        INTEGER,
  immortal_achieved       BOOLEAN NOT NULL DEFAULT false,
  immortal_reward_status  TEXT,
  strongest_team_summary  JSONB NOT NULL DEFAULT '{}'::jsonb,
  achievements_snapshot   JSONB NOT NULL DEFAULT '[]'::jsonb,
  archived_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (season_id, team_id)
);

-- ============================================================
-- 6. IMMORTAL PHYSICAL REWARD ENTITLEMENTS & SNAPSHOTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.immortal_reward_entitlements (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id                UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id                  UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  achievement_date         TIMESTAMPTZ NOT NULL DEFAULT now(),
  season_xp_at_qual        NUMERIC(12,2) NOT NULL,
  approved_challenges_qual INTEGER NOT NULL,
  weighted_challenges_qual NUMERIC(10,2) NOT NULL,
  trophy_quantity          INTEGER NOT NULL DEFAULT 1,
  medal_quantity           INTEGER NOT NULL DEFAULT 0,
  jersey_quantity          INTEGER NOT NULL DEFAULT 0,
  reward_status            TEXT NOT NULL DEFAULT 'eligible'
                           CHECK (reward_status IN ('not_eligible','eligible','under_review','approved','preparing','ready','delivered','rejected')),
  delivery_status          TEXT NOT NULL DEFAULT 'pending'
                           CHECK (delivery_status IN ('pending','preparing','ready','shipped','delivered','cancelled')),
  actual_cost_egp          NUMERIC(10,2),
  delivery_contact_name    TEXT,
  delivery_contact_phone   TEXT,
  delivery_address         TEXT,
  sizes_submitted_at       TIMESTAMPTZ,
  sizes_locked_at          TIMESTAMPTZ,
  admin_notes              TEXT,
  delivered_at             TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (season_id, team_id)
);

CREATE TABLE IF NOT EXISTS public.immortal_reward_player_snapshots (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entitlement_id         UUID NOT NULL REFERENCES public.immortal_reward_entitlements(id) ON DELETE CASCADE,
  season_id              UUID NOT NULL REFERENCES public.competition_seasons(id),
  team_id                UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id                UUID NOT NULL REFERENCES public.users(id),
  player_name            TEXT,
  medal_eligible         BOOLEAN NOT NULL DEFAULT true,
  jersey_eligible        BOOLEAN NOT NULL DEFAULT true,
  duplicate_season_blocked BOOLEAN NOT NULL DEFAULT false,
  jersey_size            TEXT CHECK (jersey_size IN ('XS','S','M','L','XL','XXL','3XL')),
  jersey_number          INTEGER,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (entitlement_id, user_id)
);

-- Enforce: at most ONE personal Immortal reward per player per season across all teams
CREATE UNIQUE INDEX IF NOT EXISTS idx_immortal_one_personal_kit_per_player_season
  ON public.immortal_reward_player_snapshots (season_id, user_id)
  WHERE jersey_eligible = true;

CREATE TABLE IF NOT EXISTS public.immortal_reward_audit_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entitlement_id  UUID NOT NULL REFERENCES public.immortal_reward_entitlements(id) ON DELETE CASCADE,
  actor_id        UUID REFERENCES public.users(id),
  actor_role      TEXT,
  action          TEXT NOT NULL,
  old_status      TEXT,
  new_status      TEXT,
  notes           TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 7. STRONGEST TEAM OFFICIAL VSP CHAMPIONSHIP (4 teams, 5 players incl. GK, 5 flexible tests)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.strongest_team_events (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id               UUID NOT NULL REFERENCES public.competition_seasons(id),
  title_ar                TEXT NOT NULL,
  title_en                TEXT NOT NULL,
  governorate             TEXT NOT NULL,
  venue_name              TEXT NOT NULL,
  stadium_id              UUID REFERENCES public.stadiums(id),
  event_date              TIMESTAMPTZ NOT NULL,
  max_teams               INTEGER NOT NULL DEFAULT 4 CHECK (max_teams = 4),
  required_players        INTEGER NOT NULL DEFAULT 5 CHECK (required_players = 5),
  entry_fee_egp           NUMERIC(10,2) NOT NULL DEFAULT 50.00 CHECK (entry_fee_egp >= 0),
  status                  TEXT NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','registration_open','registration_closed','ongoing','completed','cancelled')),
  rules_locked            BOOLEAN NOT NULL DEFAULT false,
  rules_summary_ar        TEXT,
  rules_summary_en        TEXT,
  prize_description_ar    TEXT,
  prize_description_en    TEXT,
  best_gk_award_rules_ar  TEXT,
  best_gk_award_rules_en  TEXT,
  best_gk_winner_user_id  UUID REFERENCES public.users(id),
  best_gk_winner_team_id  UUID REFERENCES public.teams(id),
  xp_distributed          BOOLEAN NOT NULL DEFAULT false,
  created_by              UUID REFERENCES public.users(id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.strongest_team_tests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES public.strongest_team_events(id) ON DELETE CASCADE,
  test_order        INTEGER NOT NULL CHECK (test_order BETWEEN 1 AND 5),
  test_code         TEXT NOT NULL CHECK (test_code IN ('speed','moving_ball_shooting','penalties','first_touch','final_1v1')),
  title_ar          TEXT NOT NULL,
  title_en          TEXT NOT NULL,
  scoring_direction TEXT NOT NULL DEFAULT 'higher_is_better' CHECK (scoring_direction IN ('higher_is_better','lower_is_better')),
  max_points        NUMERIC(10,2) NOT NULL DEFAULT 100 CHECK (max_points > 0),
  weight            NUMERIC(6,4) NOT NULL DEFAULT 1.0 CHECK (weight > 0),
  max_attempts      INTEGER NOT NULL DEFAULT 3 CHECK (max_attempts >= 1),
  participants_per_team INTEGER NOT NULL DEFAULT 5 CHECK (participants_per_team BETWEEN 1 AND 5),
  config            JSONB NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (event_id, test_order),
  UNIQUE (event_id, test_code)
);

CREATE TABLE IF NOT EXISTS public.strongest_team_participants (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id               UUID NOT NULL REFERENCES public.strongest_team_events(id) ON DELETE CASCADE,
  team_id                UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  captain_id             UUID NOT NULL REFERENCES public.users(id),
  selected_player_ids    UUID[] NOT NULL CHECK (cardinality(selected_player_ids) = 5),
  goalkeeper_user_id     UUID NOT NULL REFERENCES public.users(id),
  fee_snapshot_egp       NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_status         TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('exempt','pending','paid','refunded')),
  registration_status    TEXT NOT NULL DEFAULT 'confirmed' CHECK (registration_status IN ('pending_payment','confirmed','withdrawn','disqualified')),
  final_rank             INTEGER CHECK (final_rank BETWEEN 1 AND 4),
  total_weighted_score   NUMERIC(12,4) NOT NULL DEFAULT 0,
  xp_awarded             NUMERIC(12,2) NOT NULL DEFAULT 0,
  registered_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id, team_id)
);

CREATE TABLE IF NOT EXISTS public.strongest_team_orders (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_reference TEXT NOT NULL UNIQUE,
  event_id        UUID NOT NULL REFERENCES public.strongest_team_events(id) ON DELETE CASCADE,
  team_id         UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  captain_user_id UUID NOT NULL REFERENCES public.users(id),
  selected_player_ids UUID[] NOT NULL CHECK (cardinality(selected_player_ids) = 5),
  goalkeeper_user_id  UUID NOT NULL REFERENCES public.users(id),
  amount          NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  paymob_order_id TEXT,
  paymob_txn_id   TEXT,
  payment_status  TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending','paid','failed','refunded')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.strongest_team_scores (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id          UUID NOT NULL REFERENCES public.strongest_team_events(id) ON DELETE CASCADE,
  test_id           UUID NOT NULL REFERENCES public.strongest_team_tests(id) ON DELETE CASCADE,
  team_id           UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
  raw_metric_value  NUMERIC(12,4),
  normalized_points NUMERIC(10,4) NOT NULL DEFAULT 0,
  weighted_points   NUMERIC(12,4) NOT NULL DEFAULT 0,
  gk_score          NUMERIC(10,4),
  notes             TEXT,
  recorded_by       UUID REFERENCES public.users(id),
  approved_at       TIMESTAMPTZ,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id, test_id, team_id)
);

-- Field championship XP ledger status tracking
ALTER TABLE public.championships
  ADD COLUMN IF NOT EXISTS xp_distributed    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS xp_distributed_at TIMESTAMPTZ;

-- ============================================================
-- 8. HELPER FUNCTIONS: SHIELD EVALUATION & PRO-RATA MISSIONS
-- ============================================================
CREATE OR REPLACE FUNCTION public.vsp_compute_shield_tier(
  p_season_xp numeric,
  p_weighted_challenges numeric
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN COALESCE(p_season_xp, 0) >= 15000 AND COALESCE(p_weighted_challenges, 0) >= 60.0 THEN 'immortal'
    WHEN COALESCE(p_season_xp, 0) >= 12000 THEN 'legendary'
    WHEN COALESCE(p_season_xp, 0) >= 8000  THEN 'elite'
    WHEN COALESCE(p_season_xp, 0) >= 5000  THEN 'diamond'
    WHEN COALESCE(p_season_xp, 0) >= 3000  THEN 'platinum'
    WHEN COALESCE(p_season_xp, 0) >= 1500  THEN 'gold'
    ELSE 'none'
  END;
$$;

CREATE OR REPLACE FUNCTION public.vsp_shield_rank_order(p_shield text)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE COALESCE(p_shield, 'none')
    WHEN 'immortal'  THEN 6
    WHEN 'legendary' THEN 5
    WHEN 'elite'     THEN 4
    WHEN 'diamond'   THEN 3
    WHEN 'platinum'  THEN 2
    WHEN 'gold'      THEN 1
    ELSE 0
  END;
$$;

CREATE OR REPLACE FUNCTION public.vsp_slice_avg_weight(
  p_weights jsonb,
  p_from_one_based int,
  p_to_one_based int
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_sum numeric := 0;
  v_cnt int := 0;
  i int;
BEGIN
  IF p_weights IS NULL OR jsonb_typeof(p_weights) <> 'array' OR p_to_one_based < p_from_one_based THEN
    RETURN 1.0;
  END IF;
  FOR i IN p_from_one_based..p_to_one_based LOOP
    IF i - 1 < jsonb_array_length(p_weights) THEN
      v_sum := v_sum + COALESCE((p_weights ->> (i - 1))::numeric, 1.0);
      v_cnt := v_cnt + 1;
    END IF;
  END LOOP;
  IF v_cnt = 0 THEN RETURN 1.0; END IF;
  RETURN round(v_sum / v_cnt, 6);
END;
$$;

CREATE OR REPLACE FUNCTION public.vsp_unlock_achievement_if_new(
  p_season_id uuid,
  p_team_id uuid,
  p_code text,
  p_title_ar text,
  p_title_en text,
  p_desc_ar text,
  p_desc_en text,
  p_category text,
  p_period_key text DEFAULT ''
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_inserted uuid;
BEGIN
  INSERT INTO public.team_achievements (
    season_id, team_id, code, title_ar, title_en, description_ar, description_en, category, period_key
  ) VALUES (
    p_season_id, p_team_id, p_code, p_title_ar, p_title_en, p_desc_ar, p_desc_en, p_category, COALESCE(p_period_key, '')
  )
  ON CONFLICT (team_id, code, period_key) DO NOTHING
  RETURNING id INTO v_inserted;
  RETURN v_inserted IS NOT NULL;
END;
$$;

-- Recompute team progress + shield + Immortal snapshot from immutable ledger
CREATE OR REPLACE FUNCTION public.vsp_refresh_team_season_state(
  p_season_id uuid,
  p_team_id uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_total_xp       numeric := 0;
  v_lifetime_xp    numeric := 0;
  v_progress       RECORD;
  v_old_shield     text := 'none';
  v_new_shield     text := 'none';
  v_highest_shield text := 'none';
  v_entitlement_id uuid;
  v_team           RECORD;
  v_member         RECORD;
  v_medals         int := 0;
  v_jerseys        int := 0;
  v_already_kitted boolean;
  v_now            timestamptz := now();
  v_streak         int := 0;
  v_unbeaten       int := 0;
  v_unique_opps_total int := 0;
  v_tourn_wins     int := 0;
  v_immortal_seasons int := 0;
  v_prev_consec    int := 0;
  v_shield_upgraded boolean := false;
BEGIN
  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false); END IF;

  INSERT INTO public.team_season_progress (season_id, team_id)
  VALUES (p_season_id, p_team_id)
  ON CONFLICT (season_id, team_id) DO NOTHING;

  SELECT * INTO v_progress
  FROM public.team_season_progress
  WHERE season_id = p_season_id AND team_id = p_team_id
  FOR UPDATE;

  SELECT GREATEST(0, COALESCE(SUM(xp_delta), 0))
  INTO v_total_xp
  FROM public.team_xp_ledger
  WHERE season_id = p_season_id AND team_id = p_team_id;

  SELECT GREATEST(0, COALESCE(SUM(xp_delta), 0))
  INTO v_lifetime_xp
  FROM public.team_xp_ledger
  WHERE team_id = p_team_id;

  v_old_shield := COALESCE(v_progress.current_shield, 'none');
  v_new_shield := public.vsp_compute_shield_tier(v_total_xp, v_progress.weighted_challenges_count);

  IF public.vsp_shield_rank_order(v_new_shield) < public.vsp_shield_rank_order(v_old_shield) THEN
    -- Shield never drops during the season due to match outcomes; only admin reversal changes progress
    v_new_shield := v_new_shield;
  END IF;

  v_shield_upgraded := public.vsp_shield_rank_order(v_new_shield) > public.vsp_shield_rank_order(v_old_shield);

  IF public.vsp_shield_rank_order(v_new_shield) >= public.vsp_shield_rank_order(COALESCE(v_team.highest_historical_shield, 'none')) THEN
    v_highest_shield := v_new_shield;
  ELSE
    v_highest_shield := v_team.highest_historical_shield;
  END IF;

  UPDATE public.team_season_progress
  SET total_xp = v_total_xp,
      current_shield = v_new_shield,
      highest_shield_reached = CASE
        WHEN public.vsp_shield_rank_order(v_new_shield) >= public.vsp_shield_rank_order(highest_shield_reached)
        THEN v_new_shield ELSE highest_shield_reached END,
      shield_unlocked_at = CASE WHEN v_shield_upgraded THEN v_now ELSE shield_unlocked_at END,
      immortal_qualified_at = CASE WHEN v_new_shield = 'immortal' AND immortal_qualified_at IS NULL THEN v_now ELSE immortal_qualified_at END,
      updated_at = v_now
  WHERE season_id = p_season_id AND team_id = p_team_id;

  -- Check Immortal entitlement creation (exactly once per team per season)
  IF v_new_shield = 'immortal' THEN
    INSERT INTO public.immortal_reward_entitlements (
      season_id, team_id, achievement_date, season_xp_at_qual,
      approved_challenges_qual, weighted_challenges_qual, reward_status, delivery_status
    ) VALUES (
      p_season_id, p_team_id, v_now, v_total_xp,
      v_progress.approved_challenges_count, v_progress.weighted_challenges_count, 'eligible', 'pending'
    )
    ON CONFLICT (season_id, team_id) DO NOTHING
    RETURNING id INTO v_entitlement_id;

    IF v_entitlement_id IS NOT NULL THEN
      -- Freeze eligible team roster snapshot right at qualification time.
      -- Each player receives personal kit ONCE per season across all teams.
      FOR v_member IN
        SELECT tm.user_id, u.name
        FROM public.team_members tm
        JOIN public.users u ON u.id = tm.user_id
        WHERE tm.team_id = p_team_id
      LOOP
        SELECT EXISTS (
          SELECT 1 FROM public.immortal_reward_player_snapshots s
          WHERE s.season_id = p_season_id AND s.user_id = v_member.user_id AND s.jersey_eligible = true
        ) INTO v_already_kitted;

        INSERT INTO public.immortal_reward_player_snapshots (
          entitlement_id, season_id, team_id, user_id, player_name,
          medal_eligible, jersey_eligible, duplicate_season_blocked
        ) VALUES (
          v_entitlement_id, p_season_id, p_team_id, v_member.user_id, v_member.name,
          NOT v_already_kitted, NOT v_already_kitted, v_already_kitted
        )
        ON CONFLICT (entitlement_id, user_id) DO NOTHING;

        IF NOT v_already_kitted THEN
          v_medals := v_medals + 1;
          v_jerseys := v_jerseys + 1;
        END IF;
      END LOOP;

      UPDATE public.immortal_reward_entitlements
      SET medal_quantity = v_medals,
          jersey_quantity = v_jerseys
      WHERE id = v_entitlement_id;

      INSERT INTO public.immortal_reward_audit_logs (
        entitlement_id, action, new_status, notes, metadata
      ) VALUES (
        v_entitlement_id, 'entitlement_created', 'eligible',
        'Team qualified for Immortal shield & Special VSP Reward',
        jsonb_build_object('xp', v_total_xp, 'approved_challenges', v_progress.approved_challenges_count,
                           'weighted_challenges', v_progress.weighted_challenges_count, 'medals', v_medals, 'jerseys', v_jerseys)
      );

      INSERT INTO public.notifications (user_id, title, body, type, created_at)
      SELECT tm.user_id,
             'إنجاز تاريخي: درع الخالد! 🏆',
             'مبروك لفريق ' || COALESCE(v_team.name, '') || ' الوصول إلى درع الخالد واستحقاق جائزة خاصة من VSP! يمكن للكابتن إرسال مقاسات الفريق من صفحة فريقي.',
             'immortal_unlocked',
             v_now
      FROM public.team_members tm WHERE tm.team_id = p_team_id;
    END IF;
  END IF;

  -- Evaluate permanent team achievements (0 XP awarded)
  IF v_progress.approved_challenges_count >= 1 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'first_challenge', 'البداية', 'The Beginning', 'إكمال أول تحدٍ معتمد للفريق.', 'Completed first verified team challenge.', 'challenge');
  END IF;
  IF v_progress.challenge_wins >= 1 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'first_win', 'أول انتصار', 'First Victory', 'تحقيق أول فوز في تحديات الفرق.', 'Achieved first verified challenge victory.', 'challenge');
  END IF;
  IF v_progress.approved_challenges_count >= 10 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'warrior_10', 'المحارب', 'Warrior', 'إكمال 10 تحديات معتمدة.', 'Completed 10 verified challenges.', 'challenge');
  END IF;
  IF v_progress.approved_challenges_count >= 50 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'veteran_50', 'المخضرم', 'Veteran', 'إكمال 50 تحدياً معتمداً.', 'Completed 50 verified challenges.', 'challenge');
  END IF;
  IF COALESCE(v_team.matches_played, 0) >= 100 OR v_progress.approved_challenges_count >= 100 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'century_100', 'نادي المئة', 'Century Club', 'إكمال 100 تحدٍ معتمد.', 'Completed 100 verified challenges.', 'challenge');
  END IF;
  SELECT count(DISTINCT opponent_team_id) INTO v_unique_opps_total FROM public.team_season_opponents WHERE team_id = p_team_id;
  IF v_unique_opps_total >= 5 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'explorer_5', 'المستكشف', 'Explorer', 'مواجهة 5 فرق مختلفة في التحديات.', 'Faced 5 unique opponent teams.', 'challenge');
  END IF;
  IF COALESCE(v_team.current_winning_streak, 0) >= 3 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'streak_3', 'سلسلة الانتصارات', 'Win Streak', 'تحقيق 3 انتصارات متتالية.', 'Achieved 3 consecutive wins.', 'streak');
  END IF;
  -- Unbeaten 5 check from last 5 completed challenges
  SELECT count(*) INTO v_unbeaten FROM (
    SELECT CASE
      WHEN b.player_team_id = p_team_id AND b.final_outcome IN ('homeWin','draw') THEN 1
      WHEN b.opponent_team_id = p_team_id AND b.final_outcome IN ('awayWin','draw') THEN 1
      ELSE 0 END AS ok
    FROM public.bookings b
    WHERE b.booking_type = 'challenge' AND b.match_result_status = 'confirmed'
      AND (b.player_team_id = p_team_id OR b.opponent_team_id = p_team_id)
    ORDER BY b.end_time DESC LIMIT 5
  ) s WHERE s.ok = 1;
  IF v_unbeaten >= 5 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'unbeaten_5', 'لا يُهزم', 'Unbeaten', 'خوض 5 تحديات متتالية بدون خسارة.', 'Played 5 consecutive challenges unbeaten.', 'streak');
  END IF;
  IF COALESCE(v_team.championships_won, 0) >= 3 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'cup_hunter_3', 'صائد البطولات', 'Cup Hunter', 'الفوز بثلاث بطولات مؤهلة.', 'Won 3 qualified championships.', 'tournament');
  END IF;
  IF public.vsp_shield_rank_order(v_new_shield) >= 5 THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'shield_legendary', 'الأسطوري', 'Legendary', 'الوصول إلى الدرع الأسطوري.', 'Reached the Legendary Shield.', 'shield');
  END IF;
  IF v_new_shield = 'immortal' THEN
    PERFORM public.vsp_unlock_achievement_if_new(p_season_id, p_team_id, 'shield_immortal', 'الخالد', 'Immortal', 'تحقيق شروط درع الخالد.', 'Unlocked the Immortal Shield.', 'immortal');
  END IF;

  SELECT count(*) INTO v_immortal_seasons
  FROM public.immortal_reward_entitlements
  WHERE team_id = p_team_id AND reward_status <> 'rejected';

  UPDATE public.teams
  SET lifetime_xp = v_lifetime_xp,
      current_season_xp = v_total_xp,
      current_shield = v_new_shield,
      highest_historical_shield = v_highest_shield,
      immortal_count = v_immortal_seasons,
      updated_at = v_now
  WHERE id = p_team_id;

  IF v_shield_upgraded AND v_new_shield <> 'immortal' THEN
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    SELECT tm.user_id,
           'ترقية درع الفريق! 🛡️',
           'ارتفع مستوى فريق ' || COALESCE(v_team.name, '') || ' إلى الدرع ' || v_new_shield || '!',
           'shield_unlocked',
           v_now
    FROM public.team_members tm WHERE tm.team_id = p_team_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'total_xp', v_total_xp,
    'lifetime_xp', v_lifetime_xp,
    'old_shield', v_old_shield,
    'new_shield', v_new_shield,
    'shield_upgraded', v_shield_upgraded,
    'immortal_unlocked', (v_entitlement_id IS NOT NULL)
  );
END;
$$;

-- ============================================================
-- 9. ATOMIC CHALLENGE COMPLETION PIPELINE (Rank + XP + Missions + Shields + Achievements)
--    Field Owner NEVER intervenes (Section 7).
-- ============================================================
CREATE OR REPLACE FUNCTION public.vsp_apply_single_team_challenge_outcome(
  p_season_id uuid,
  p_month_key text,
  p_booking_id uuid,
  p_team_id uuid,
  p_opponent_team_id uuid,
  p_outcome text, -- 'win' | 'draw' | 'loss'
  p_governorate text,
  p_sport_type text,
  p_is_official_season_live boolean
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_prev_rank       int;
  v_new_rank        int;
  v_rank_delta_pts  int;
  v_is_repeat       boolean := false;
  v_weight          numeric := 1.0;
  v_base_xp         numeric := 0;
  v_mission_xp      numeric := 0;
  v_missions_done   text[] := ARRAY[]::text[];
  v_prog            RECORD;
  v_ch_weights      jsonb;
  v_win_weights     jsonb;
  v_ch_count        int;
  v_win_count       int;
  v_uniq_count      int;
  v_tier            RECORD;
  v_prev_thresh     int;
  v_avg_w           numeric;
  v_tier_reward     numeric;
  v_refresh         jsonb;
  v_opp_inserted    uuid;
  v_now             timestamptz := now();
BEGIN
  PERFORM set_config('vsp.system_override', 'true', true);

  -- Record previous competitive rank before applying update
  SELECT rnk INTO v_prev_rank FROM (
    SELECT team_id,
           DENSE_RANK() OVER (
             ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC
           ) AS rnk
    FROM public.team_monthly_rankings
    WHERE season_id = p_season_id AND month_key = p_month_key AND lower(btrim(governorate)) = lower(btrim(p_governorate))
  ) t WHERE t.team_id = p_team_id;

  -- 1. Update aggregate team stats (wins/draws/losses/streak) WITHOUT mixing XP or Elo
  UPDATE public.teams
  SET matches_played = COALESCE(matches_played, 0) + 1,
      wins = COALESCE(wins, 0) + CASE WHEN p_outcome = 'win' THEN 1 ELSE 0 END,
      draws = COALESCE(draws, 0) + CASE WHEN p_outcome = 'draw' THEN 1 ELSE 0 END,
      losses = COALESCE(losses, 0) + CASE WHEN p_outcome = 'loss' THEN 1 ELSE 0 END,
      current_winning_streak = CASE WHEN p_outcome = 'win' THEN COALESCE(current_winning_streak, 0) + 1 ELSE 0 END,
      updated_at = v_now
  WHERE id = p_team_id;

  v_rank_delta_pts := CASE p_outcome WHEN 'win' THEN 3 WHEN 'draw' THEN 1 ELSE 0 END;

  -- If pre-launch test activity before official Season 1 start, record stats only — no official awards/XP
  IF NOT p_is_official_season_live THEN
    RETURN jsonb_build_object(
      'pre_launch_test', true,
      'outcome', p_outcome,
      'ranking_points_delta', 0,
      'xp_earned', 0,
      'mission_xp', 0,
      'total_xp_earned', 0,
      'is_repeat_opponent', false
    );
  END IF;

  -- 2. Monthly Competitive Ranking (3/1/0 per governorate, starts at 0, unaffected by repeat opponents)
  INSERT INTO public.team_monthly_rankings (
    season_id, month_key, team_id, governorate, sport_type,
    ranking_points, matches_played, wins, draws, losses, last_match_at
  ) VALUES (
    p_season_id, p_month_key, p_team_id, COALESCE(NULLIF(btrim(p_governorate), ''), 'Aswan'), COALESCE(NULLIF(btrim(p_sport_type), ''), 'Football'),
    v_rank_delta_pts, 1,
    CASE WHEN p_outcome = 'win' THEN 1 ELSE 0 END,
    CASE WHEN p_outcome = 'draw' THEN 1 ELSE 0 END,
    CASE WHEN p_outcome = 'loss' THEN 1 ELSE 0 END,
    v_now
  )
  ON CONFLICT (season_id, month_key, team_id) DO UPDATE SET
    ranking_points = public.team_monthly_rankings.ranking_points + v_rank_delta_pts,
    matches_played = public.team_monthly_rankings.matches_played + 1,
    wins           = public.team_monthly_rankings.wins + CASE WHEN p_outcome = 'win' THEN 1 ELSE 0 END,
    draws          = public.team_monthly_rankings.draws + CASE WHEN p_outcome = 'draw' THEN 1 ELSE 0 END,
    losses         = public.team_monthly_rankings.losses + CASE WHEN p_outcome = 'loss' THEN 1 ELSE 0 END,
    last_match_at  = v_now,
    updated_at     = v_now;

  SELECT rnk INTO v_new_rank FROM (
    SELECT team_id,
           DENSE_RANK() OVER (
             ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC
           ) AS rnk
    FROM public.team_monthly_rankings
    WHERE season_id = p_season_id AND month_key = p_month_key AND lower(btrim(governorate)) = lower(btrim(p_governorate))
  ) t WHERE t.team_id = p_team_id;

  -- 3. Check season-wide opponent uniqueness (First match = 1.0, Repeat = 0.5)
  INSERT INTO public.team_season_opponents (season_id, team_id, opponent_team_id, first_match_booking_id)
  VALUES (p_season_id, p_team_id, p_opponent_team_id, p_booking_id)
  ON CONFLICT (season_id, team_id, opponent_team_id) DO UPDATE SET
    matches_count = public.team_season_opponents.matches_count + 1,
    last_played_at = v_now
  RETURNING (CASE WHEN matches_count > 1 THEN true ELSE false END) INTO v_is_repeat;

  v_weight := CASE WHEN v_is_repeat THEN 0.5 ELSE 1.0 END;
  v_base_xp := CASE p_outcome
    WHEN 'win'  THEN 80.0 * v_weight
    WHEN 'draw' THEN 65.0 * v_weight
    ELSE 50.0 * v_weight
  END;

  -- 4. Append base XP ledger entry (idempotent)
  INSERT INTO public.team_xp_ledger (
    season_id, team_id, source_type, source_ref_id, idempotency_key,
    xp_delta, month_key, is_repeat_opponent, opponent_team_id, reason, metadata
  ) VALUES (
    p_season_id, p_team_id, 'challenge_result', p_booking_id::text,
    'challenge:' || p_booking_id::text || ':team:' || p_team_id::text,
    v_base_xp, p_month_key, v_is_repeat, p_opponent_team_id,
    CASE WHEN v_is_repeat THEN 'مواجهة متكررة خلال الموسم (50%)' ELSE 'مواجهة جديدة خلال الموسم (100%)' END,
    jsonb_build_object('outcome', p_outcome, 'weight', v_weight, 'booking_id', p_booking_id)
  )
  ON CONFLICT (idempotency_key) DO NOTHING;

  -- 5. Update Season Progress counters
  INSERT INTO public.team_season_progress (
    season_id, team_id, approved_challenges_count, weighted_challenges_count,
    challenge_wins, challenge_draws, challenge_losses
  ) VALUES (
    p_season_id, p_team_id, 1, v_weight,
    CASE WHEN p_outcome = 'win' THEN 1 ELSE 0 END,
    CASE WHEN p_outcome = 'draw' THEN 1 ELSE 0 END,
    CASE WHEN p_outcome = 'loss' THEN 1 ELSE 0 END
  )
  ON CONFLICT (season_id, team_id) DO UPDATE SET
    approved_challenges_count = public.team_season_progress.approved_challenges_count + 1,
    weighted_challenges_count = public.team_season_progress.weighted_challenges_count + v_weight,
    challenge_wins   = public.team_season_progress.challenge_wins + CASE WHEN p_outcome = 'win' THEN 1 ELSE 0 END,
    challenge_draws  = public.team_season_progress.challenge_draws + CASE WHEN p_outcome = 'draw' THEN 1 ELSE 0 END,
    challenge_losses = public.team_season_progress.challenge_losses + CASE WHEN p_outcome = 'loss' THEN 1 ELSE 0 END,
    updated_at       = v_now;

  -- 6. Update Monthly Opponents & Progressive Missions
  INSERT INTO public.team_monthly_opponents (season_id, month_key, team_id, opponent_team_id)
  VALUES (p_season_id, p_month_key, p_team_id, p_opponent_team_id)
  ON CONFLICT (season_id, month_key, team_id, opponent_team_id) DO NOTHING;

  SELECT count(*)::int INTO v_uniq_count
  FROM public.team_monthly_opponents
  WHERE season_id = p_season_id AND month_key = p_month_key AND team_id = p_team_id;

  INSERT INTO public.team_monthly_mission_progress (season_id, month_key, team_id)
  VALUES (p_season_id, p_month_key, p_team_id)
  ON CONFLICT (season_id, month_key, team_id) DO NOTHING;

  SELECT * INTO v_prog
  FROM public.team_monthly_mission_progress
  WHERE season_id = p_season_id AND month_key = p_month_key AND team_id = p_team_id
  FOR UPDATE;

  v_ch_weights := COALESCE(v_prog.challenge_weights, '[]'::jsonb) || to_jsonb(v_weight);
  v_ch_count   := COALESCE(v_prog.challenges_completed, 0) + 1;
  v_win_weights := COALESCE(v_prog.win_weights, '[]'::jsonb);
  v_win_count   := COALESCE(v_prog.challenge_wins, 0);
  IF p_outcome = 'win' THEN
    v_win_weights := v_win_weights || to_jsonb(v_weight);
    v_win_count   := v_win_count + 1;
  END IF;

  -- Mission 1: Challenges Completed (4->200, 6->150, 8->250, 10->350, 12->500) with pro-rata weight
  v_prev_thresh := 0;
  FOR v_tier IN
    SELECT * FROM (VALUES
      ('ch_4', 4, 200.0, 0),
      ('ch_6', 6, 150.0, 4),
      ('ch_8', 8, 250.0, 6),
      ('ch_10', 10, 350.0, 8),
      ('ch_12', 12, 500.0, 10)
    ) AS t(code, thresh, reward, prev_t)
  LOOP
    IF v_ch_count >= v_tier.thresh AND NOT (v_tier.code = ANY(v_prog.claimed_tiers)) THEN
      v_avg_w := public.vsp_slice_avg_weight(v_ch_weights, v_tier.prev_t + 1, v_tier.thresh);
      v_tier_reward := round(v_tier.reward * v_avg_w, 2);
      INSERT INTO public.team_xp_ledger (
        season_id, team_id, source_type, source_ref_id, idempotency_key,
        xp_delta, month_key, reason, metadata
      ) VALUES (
        p_season_id, p_team_id, 'monthly_mission', v_tier.code || ':' || p_month_key,
        'mission:' || p_season_id::text || ':' || p_month_key || ':' || p_team_id::text || ':' || v_tier.code,
        v_tier_reward, p_month_key, 'مكافأة مهمة التحديات (' || v_tier.thresh || ')',
        jsonb_build_object('tier', v_tier.code, 'avg_weight', v_avg_w, 'base_reward', v_tier.reward)
      ) ON CONFLICT (idempotency_key) DO NOTHING;
      IF FOUND THEN
        v_mission_xp := v_mission_xp + v_tier_reward;
        v_missions_done := array_append(v_missions_done, v_tier.code);
      END IF;
      v_prog.claimed_tiers := array_append(v_prog.claimed_tiers, v_tier.code);
    END IF;
  END LOOP;

  -- Mission 2: Wins (2->150, 3->100, 4->150, 5->200, 6->250) with pro-rata weight
  FOR v_tier IN
    SELECT * FROM (VALUES
      ('win_2', 2, 150.0, 0),
      ('win_3', 3, 100.0, 2),
      ('win_4', 4, 150.0, 3),
      ('win_5', 5, 200.0, 4),
      ('win_6', 6, 250.0, 5)
    ) AS t(code, thresh, reward, prev_t)
  LOOP
    IF v_win_count >= v_tier.thresh AND NOT (v_tier.code = ANY(v_prog.claimed_tiers)) THEN
      v_avg_w := public.vsp_slice_avg_weight(v_win_weights, v_tier.prev_t + 1, v_tier.thresh);
      v_tier_reward := round(v_tier.reward * v_avg_w, 2);
      INSERT INTO public.team_xp_ledger (
        season_id, team_id, source_type, source_ref_id, idempotency_key,
        xp_delta, month_key, reason, metadata
      ) VALUES (
        p_season_id, p_team_id, 'monthly_mission', v_tier.code || ':' || p_month_key,
        'mission:' || p_season_id::text || ':' || p_month_key || ':' || p_team_id::text || ':' || v_tier.code,
        v_tier_reward, p_month_key, 'مكافأة مهمة الانتصارات (' || v_tier.thresh || ')',
        jsonb_build_object('tier', v_tier.code, 'avg_weight', v_avg_w, 'base_reward', v_tier.reward)
      ) ON CONFLICT (idempotency_key) DO NOTHING;
      IF FOUND THEN
        v_mission_xp := v_mission_xp + v_tier_reward;
        v_missions_done := array_append(v_missions_done, v_tier.code);
      END IF;
      v_prog.claimed_tiers := array_append(v_prog.claimed_tiers, v_tier.code);
    END IF;
  END LOOP;

  -- Mission 3: Unique Opponents (2->100, 3->75, 4->100, 5->125, 6->150)
  FOR v_tier IN
    SELECT * FROM (VALUES
      ('opp_2', 2, 100.0),
      ('opp_3', 3, 75.0),
      ('opp_4', 4, 100.0),
      ('opp_5', 5, 125.0),
      ('opp_6', 6, 150.0)
    ) AS t(code, thresh, reward)
  LOOP
    IF v_uniq_count >= v_tier.thresh AND NOT (v_tier.code = ANY(v_prog.claimed_tiers)) THEN
      INSERT INTO public.team_xp_ledger (
        season_id, team_id, source_type, source_ref_id, idempotency_key,
        xp_delta, month_key, reason, metadata
      ) VALUES (
        p_season_id, p_team_id, 'monthly_mission', v_tier.code || ':' || p_month_key,
        'mission:' || p_season_id::text || ':' || p_month_key || ':' || p_team_id::text || ':' || v_tier.code,
        v_tier.reward, p_month_key, 'مكافأة مواجهة فرق مختلفة (' || v_tier.thresh || ')',
        jsonb_build_object('tier', v_tier.code)
      ) ON CONFLICT (idempotency_key) DO NOTHING;
      IF FOUND THEN
        v_mission_xp := v_mission_xp + v_tier.reward;
        v_missions_done := array_append(v_missions_done, v_tier.code);
      END IF;
      v_prog.claimed_tiers := array_append(v_prog.claimed_tiers, v_tier.code);
    END IF;
  END LOOP;

  UPDATE public.team_monthly_mission_progress
  SET challenges_completed = v_ch_count,
      challenge_weights    = v_ch_weights,
      challenge_wins       = v_win_count,
      win_weights          = v_win_weights,
      unique_opponents     = v_uniq_count,
      claimed_tiers        = v_prog.claimed_tiers,
      updated_at           = v_now
  WHERE season_id = p_season_id AND month_key = p_month_key AND team_id = p_team_id;

  -- 7. Refresh shield, total XP, achievements, and Immortal qualification
  v_refresh := public.vsp_refresh_team_season_state(p_season_id, p_team_id);

  RETURN jsonb_build_object(
    'pre_launch_test', false,
    'team_id', p_team_id,
    'outcome', p_outcome,
    'ranking_points_delta', v_rank_delta_pts,
    'prev_rank', v_prev_rank,
    'new_rank', v_new_rank,
    'rank_change', CASE WHEN v_prev_rank IS NOT NULL AND v_new_rank IS NOT NULL THEN v_prev_rank - v_new_rank ELSE 0 END,
    'base_xp', v_base_xp,
    'mission_xp', v_mission_xp,
    'total_xp_earned', v_base_xp + v_mission_xp,
    'is_repeat_opponent', v_is_repeat,
    'missions_completed', to_jsonb(v_missions_done),
    'shield_status', v_refresh
  );
END;
$$;

-- Replace legacy calculate_elo_on_match_completion trigger so NO Elo/XP gets written to teams.points,
-- and instead delegate atomically to the new Season + Ranking + XP + Missions + Shields pipeline.
CREATE OR REPLACE FUNCTION public.calculate_elo_on_match_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_season        public.competition_seasons;
  v_month_key     TEXT;
  v_home_team     RECORD;
  v_away_team     RECORD;
  v_home_outcome  TEXT;
  v_away_outcome  TEXT;
  v_official_live BOOLEAN := false;
  v_home_res      JSONB;
  v_away_res      JSONB;
BEGIN
  IF NEW.booking_type = 'challenge'
     AND NEW.match_result_status = 'confirmed'
     AND NEW.final_outcome IN ('homeWin','draw','awayWin')
     AND COALESCE(NEW.gamification_processed, false) = false THEN

    IF NEW.player_team_id IS NULL OR NEW.opponent_team_id IS NULL OR NEW.player_team_id = NEW.opponent_team_id THEN
      RETURN NEW;
    END IF;

    -- Lock match idempotently to prevent concurrent duplicate rewards
    PERFORM pg_advisory_xact_lock(hashtextextended('challenge_complete:' || NEW.id::text, 0));

    SELECT * INTO v_season FROM public.vsp_get_active_season();
    IF v_season.id IS NULL THEN
      RETURN NEW;
    END IF;

    v_month_key := public.vsp_cairo_month_key(COALESCE(NEW.end_time, now()));
    v_official_live := (COALESCE(NEW.end_time, now()) >= v_season.starts_at AND COALESCE(NEW.end_time, now()) <= v_season.ends_at);

    SELECT * INTO v_home_team FROM public.teams WHERE id = NEW.player_team_id;
    SELECT * INTO v_away_team FROM public.teams WHERE id = NEW.opponent_team_id;
    IF NOT FOUND OR v_home_team.id IS NULL OR v_away_team.id IS NULL THEN
      RETURN NEW;
    END IF;

    v_home_outcome := CASE NEW.final_outcome WHEN 'homeWin' THEN 'win' WHEN 'draw' THEN 'draw' ELSE 'loss' END;
    v_away_outcome := CASE NEW.final_outcome WHEN 'awayWin' THEN 'win' WHEN 'draw' THEN 'draw' ELSE 'loss' END;

    v_home_res := public.vsp_apply_single_team_challenge_outcome(
      v_season.id, v_month_key, NEW.id, v_home_team.id, v_away_team.id,
      v_home_outcome, COALESCE(v_home_team.governorate, 'Aswan'), COALESCE(v_home_team.sport_type, 'Football'), v_official_live
    );
    v_away_res := public.vsp_apply_single_team_challenge_outcome(
      v_season.id, v_month_key, NEW.id, v_away_team.id, v_home_team.id,
      v_away_outcome, COALESCE(v_away_team.governorate, 'Aswan'), COALESCE(v_away_team.sport_type, 'Football'), v_official_live
    );

    NEW.gamification_processed := true;
    NEW.elo_processed := true;
    NEW.gamification_summary := jsonb_build_object(
      'season_id', v_season.id,
      'month_key', v_month_key,
      'official_season', v_official_live,
      'home', v_home_res,
      'away', v_away_res
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- Return rich summary from submit_challenge_result_atomic
CREATE OR REPLACE FUNCTION public.submit_challenge_result_atomic(
  p_booking_id uuid,
  p_team_id uuid,
  p_outcome text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_booking record;
  v_team record;
  v_now timestamptz := timezone('utc', now());
  v_existing_team uuid;
  v_existing_outcome text;
  v_updated_summary jsonb;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_outcome NOT IN ('homeWin','draw','awayWin') THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_OUTCOME');
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_booking FROM public.bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); END IF;
  IF v_booking.booking_type <> 'challenge' THEN
    RETURN jsonb_build_object('success',false,'error','NOT_A_CHALLENGE');
  END IF;
  IF v_booking.end_time > v_now THEN
    RETURN jsonb_build_object('success',false,'error','MATCH_NOT_FINISHED');
  END IF;
  IF v_booking.status='cancelled' THEN
    RETURN jsonb_build_object('success',false,'error','BOOKING_CANCELLED');
  END IF;
  IF p_team_id NOT IN (v_booking.player_team_id,v_booking.opponent_team_id) THEN
    RETURN jsonb_build_object('success',false,'error','TEAM_NOT_IN_BOOKING');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id=p_team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller_id THEN
    RETURN jsonb_build_object('success',false,'error','CAPTAIN_ONLY');
  END IF;

  IF v_booking.match_result_status='confirmed' THEN
    RETURN jsonb_build_object('success',false,'error','RESULT_ALREADY_FINALIZED');
  END IF;

  v_existing_team := v_booking.result_submitted_by_team_id;
  v_existing_outcome := v_booking.pending_outcome;

  IF v_existing_team IS NULL OR v_existing_team = p_team_id THEN
    UPDATE public.bookings SET
      pending_outcome=p_outcome,
      result_submitted_by_team_id=p_team_id,
      match_result_status='waitingOpponent',
      requires_admin_intervention=false,
      final_outcome=NULL,
      updated_at=v_now
    WHERE id=p_booking_id;
    RETURN jsonb_build_object('success',true,'state','waitingOpponent','finalized',false,
      'pending_outcome',p_outcome,'submitted_by_team_id',p_team_id);
  END IF;

  IF v_existing_outcome = p_outcome THEN
    UPDATE public.bookings SET
      final_outcome=p_outcome,
      match_result_status='confirmed',
      status='completed',
      requires_admin_intervention=false,
      pending_outcome=NULL,
      result_submitted_by_team_id=NULL,
      updated_at=v_now
    WHERE id=p_booking_id
    RETURNING gamification_summary INTO v_updated_summary;

    RETURN jsonb_build_object('success',true,'state','confirmed','finalized',true,
      'final_outcome',p_outcome, 'gamification_summary', v_updated_summary);
  END IF;

  UPDATE public.bookings SET
    pending_outcome=p_outcome,
    result_submitted_by_team_id=p_team_id,
    match_result_status='waitingOpponent',
    requires_admin_intervention=false,
    final_outcome=NULL,
    updated_at=v_now
  WHERE id=p_booking_id;

  RETURN jsonb_build_object('success',true,'state','mismatch','finalized',false,
    'error','RESULT_MISMATCH','latest_outcome',p_outcome,
    'latest_submitted_by_team_id',p_team_id);
END;
$function$;

-- ============================================================
-- 10. FIELD CHAMPIONSHIP XP REWARDS (800 / 600 / 200 + 150 mission)
--     AND MONTHLY/ANNUAL CLOSE & STRONGEST TEAM RPCs
-- ============================================================
CREATE OR REPLACE FUNCTION public.vsp_grant_tournament_mission_if_eligible(
  p_season_id uuid,
  p_month_key text,
  p_team_id uuid,
  p_source_ref text
)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_prog RECORD;
BEGIN
  INSERT INTO public.team_monthly_mission_progress (season_id, month_key, team_id)
  VALUES (p_season_id, p_month_key, p_team_id)
  ON CONFLICT (season_id, month_key, team_id) DO NOTHING;

  SELECT * INTO v_prog FROM public.team_monthly_mission_progress
  WHERE season_id = p_season_id AND month_key = p_month_key AND team_id = p_team_id
  FOR UPDATE;

  IF NOT ('tournament_1' = ANY(v_prog.claimed_tiers)) THEN
    INSERT INTO public.team_xp_ledger (
      season_id, team_id, source_type, source_ref_id, idempotency_key,
      xp_delta, month_key, reason
    ) VALUES (
      p_season_id, p_team_id, 'monthly_mission', p_source_ref,
      'mission:' || p_season_id::text || ':' || p_month_key || ':' || p_team_id::text || ':tournament_1',
      150.0, p_month_key, 'مكافأة المشاركة في بطولة خلال الشهر'
    ) ON CONFLICT (idempotency_key) DO NOTHING;
    IF FOUND THEN
      UPDATE public.team_monthly_mission_progress
      SET tournaments_completed = tournaments_completed + 1,
          claimed_tiers = array_append(claimed_tiers, 'tournament_1'),
          updated_at = now()
      WHERE season_id = p_season_id AND month_key = p_month_key AND team_id = p_team_id;
      RETURN 150.0;
    END IF;
  END IF;
  RETURN 0.0;
END;
$$;

CREATE OR REPLACE FUNCTION public.distribute_field_championship_xp_atomic(
  p_championship_id uuid,
  p_runner_up_team_id uuid DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_champ          RECORD;
  v_season         public.competition_seasons;
  v_month_key      text;
  v_team_id        uuid;
  v_xp_amount      numeric;
  v_runner_up_id   uuid := p_runner_up_team_id;
  v_distributed    int := 0;
BEGIN
  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
  IF NOT FOUND OR v_champ.status <> 'completed' OR v_champ.is_approved IS NOT TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_NOT_ELIGIBLE');
  END IF;

  IF v_champ.xp_distributed THEN
    RETURN jsonb_build_object('success', true, 'already_distributed', true);
  END IF;

  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL OR now() < v_season.starts_at THEN
    RETURN jsonb_build_object('success', true, 'pre_launch_skipped', true);
  END IF;

  -- Detect runner-up from knockout final if not passed
  IF v_runner_up_id IS NULL AND v_champ.champion_team_id IS NOT NULL THEN
    SELECT CASE WHEN m.home_team_id = v_champ.champion_team_id THEN m.away_team_id ELSE m.home_team_id END
    INTO v_runner_up_id
    FROM public.tournament_matches m
    WHERE m.championship_id = p_championship_id
      AND m.winner_id = v_champ.champion_team_id
    ORDER BY m.round_index DESC, m.match_index ASC
    LIMIT 1;
  END IF;

  v_month_key := public.vsp_cairo_month_key(now());

  FOR v_team_id IN
    SELECT DISTINCT cr.team_id
    FROM public.championship_registrations cr
    WHERE cr.championship_id = p_championship_id
      AND cr.registration_status = 'confirmed'
      AND cr.team_id IS NOT NULL
  LOOP
    v_xp_amount := CASE
      WHEN v_team_id = v_champ.champion_team_id THEN 800.0
      WHEN v_team_id = v_runner_up_id THEN 600.0
      ELSE 200.0
    END;

    INSERT INTO public.team_xp_ledger (
      season_id, team_id, source_type, source_ref_id, idempotency_key,
      xp_delta, month_key, reason, metadata
    ) VALUES (
      v_season.id, v_team_id, 'field_championship', p_championship_id::text,
      'field_champ:' || p_championship_id::text || ':team:' || v_team_id::text,
      v_xp_amount, v_month_key,
      CASE
        WHEN v_team_id = v_champ.champion_team_id THEN 'بطل بطولة ملعب'
        WHEN v_team_id = v_runner_up_id THEN 'المركز الثاني في بطولة ملعب'
        ELSE 'مشاركة مؤهلة في بطولة ملعب'
      END,
      jsonb_build_object('championship_id', p_championship_id, 'title', v_champ.title)
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.team_season_progress
    SET tournaments_completed_count = tournaments_completed_count + 1,
        tournaments_won_count = tournaments_won_count + CASE WHEN v_team_id = v_champ.champion_team_id THEN 1 ELSE 0 END,
        updated_at = now()
    WHERE season_id = v_season.id AND team_id = v_team_id;

    PERFORM public.vsp_grant_tournament_mission_if_eligible(v_season.id, v_month_key, v_team_id, p_championship_id::text);
    PERFORM public.vsp_refresh_team_season_state(v_season.id, v_team_id);
    v_distributed := v_distributed + 1;
  END LOOP;

  UPDATE public.championships
  SET xp_distributed = true, xp_distributed_at = now()
  WHERE id = p_championship_id;

  RETURN jsonb_build_object('success', true, 'teams_rewarded', v_distributed);
END;
$$;

-- Trigger when a field championship becomes completed to award XP safely (owners cannot tamper with XP)
CREATE OR REPLACE FUNCTION public.trg_award_field_championship_xp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed'
     AND NEW.is_approved IS TRUE AND COALESCE(NEW.xp_distributed, false) = false THEN
    PERFORM public.distribute_field_championship_xp_atomic(NEW.id, NULL);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_field_championship_xp ON public.championships;
CREATE TRIGGER trg_field_championship_xp
  AFTER UPDATE ON public.championships
  FOR EACH ROW EXECUTE FUNCTION public.trg_award_field_championship_xp();

-- ============================================================
-- 11. CLIENT-SAFE PUBLIC & PRIVATE RPCs
-- ============================================================
-- Check repeat opponent before confirming challenge
CREATE OR REPLACE FUNCTION public.get_challenge_opponent_repeat_status(
  p_team_id uuid,
  p_opponent_team_id uuid
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season public.competition_seasons;
  v_cnt int := 0;
BEGIN
  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL THEN
    RETURN jsonb_build_object('is_repeat', false, 'season_matches', 0);
  END IF;

  SELECT COALESCE(matches_count, 0) INTO v_cnt
  FROM public.team_season_opponents
  WHERE season_id = v_season.id AND team_id = p_team_id AND opponent_team_id = p_opponent_team_id;

  RETURN jsonb_build_object(
    'is_repeat', (COALESCE(v_cnt, 0) >= 1),
    'season_matches', COALESCE(v_cnt, 0),
    'win_xp', CASE WHEN COALESCE(v_cnt, 0) >= 1 THEN 40 ELSE 80 END,
    'draw_xp', CASE WHEN COALESCE(v_cnt, 0) >= 1 THEN 32.5 ELSE 65 END,
    'loss_xp', CASE WHEN COALESCE(v_cnt, 0) >= 1 THEN 25 ELSE 50 END
  );
END;
$$;

-- Monthly Competitive Ranking RPC (Paginated, Governorate-isolated, exact tiebreakers)
CREATE OR REPLACE FUNCTION public.get_monthly_competitive_ranking(
  p_month_key text DEFAULT NULL,
  p_governorate text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season public.competition_seasons;
  v_month  text := COALESCE(p_month_key, public.vsp_cairo_month_key(now()));
  v_rows   jsonb;
BEGIN
  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL THEN
    RETURN jsonb_build_object('month_key', v_month, 'teams', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(q)), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      DENSE_RANK() OVER (
        PARTITION BY lower(btrim(r.governorate))
        ORDER BY r.ranking_points DESC, r.wins DESC, r.draws DESC, r.losses ASC, r.matches_played DESC
      )::int AS rank,
      r.team_id,
      t.name AS team_name,
      t.logo_url,
      r.governorate,
      r.sport_type,
      r.ranking_points,
      r.matches_played,
      r.wins,
      r.draws,
      r.losses,
      COALESCE(p.current_shield, 'none') AS current_shield,
      r.month_key
    FROM public.team_monthly_rankings r
    JOIN public.teams t ON t.id = r.team_id
    LEFT JOIN public.team_season_progress p ON p.season_id = r.season_id AND p.team_id = r.team_id
    WHERE r.season_id = v_season.id
      AND r.month_key = v_month
      AND (p_governorate IS NULL OR btrim(p_governorate) = '' OR lower(btrim(r.governorate)) = lower(btrim(p_governorate)))
    ORDER BY r.ranking_points DESC, r.wins DESC, r.draws DESC, r.losses ASC, r.matches_played DESC, t.created_at ASC
    LIMIT GREATEST(1, LEAST(p_limit, 100))
    OFFSET GREATEST(0, p_offset)
  ) q;

  RETURN jsonb_build_object('season_id', v_season.id, 'month_key', v_month, 'teams', v_rows);
END;
$$;

-- Most Active Teams Annual Ranking RPC (based on raw approved challenges)
CREATE OR REPLACE FUNCTION public.get_most_active_teams_ranking(
  p_season_id uuid DEFAULT NULL,
  p_governorate text DEFAULT NULL,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season_id uuid := p_season_id;
  v_season public.competition_seasons;
  v_rows jsonb;
BEGIN
  IF v_season_id IS NULL THEN
    SELECT * INTO v_season FROM public.vsp_get_active_season();
    v_season_id := v_season.id;
  ELSE
    SELECT * INTO v_season FROM public.competition_seasons WHERE id = v_season_id;
  END IF;

  IF v_season_id IS NULL THEN
    RETURN jsonb_build_object('teams', '[]'::jsonb);
  END IF;

  SELECT COALESCE(jsonb_agg(row_to_json(q)), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT
      DENSE_RANK() OVER (
        ORDER BY p.approved_challenges_count DESC, p.total_xp DESC, t.created_at ASC
      )::int AS activity_rank,
      p.team_id,
      t.name AS team_name,
      t.logo_url,
      t.governorate,
      p.current_shield,
      p.approved_challenges_count,
      p.weighted_challenges_count,
      p.total_xp AS season_xp,
      v_season.year_number AS season_year
    FROM public.team_season_progress p
    JOIN public.teams t ON t.id = p.team_id
    WHERE p.season_id = v_season_id
      AND p.approved_challenges_count > 0
      AND (p_governorate IS NULL OR btrim(p_governorate) = '' OR lower(btrim(t.governorate)) = lower(btrim(p_governorate)))
    ORDER BY p.approved_challenges_count DESC, p.total_xp DESC, t.created_at ASC
    LIMIT GREATEST(1, LEAST(p_limit, 100))
    OFFSET GREATEST(0, p_offset)
  ) q;

  RETURN jsonb_build_object('season_id', v_season_id, 'season_year', v_season.year_number, 'teams', v_rows);
END;
$$;

-- Team Gamification Overview (Public vs Private controlled cleanly)
CREATE OR REPLACE FUNCTION public.get_team_gamification_profile(p_team_id uuid)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season       public.competition_seasons;
  v_month_key    text := public.vsp_cairo_month_key(now());
  v_caller_id    uuid := auth.uid();
  v_is_member    boolean := false;
  v_is_captain   boolean := false;
  v_is_admin     boolean := false;
  v_team         RECORD;
  v_prog         RECORD;
  v_mission      RECORD;
  v_rank_row     RECORD;
  v_my_rank      int;
  v_immortal     RECORD;
  v_awards       jsonb := '[]'::jsonb;
  v_achievements jsonb := '[]'::jsonb;
  v_history      jsonb := '[]'::jsonb;
  v_strongest    jsonb := '[]'::jsonb;
  v_snapshots    jsonb := '[]'::jsonb;
BEGIN
  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'TEAM_NOT_FOUND');
  END IF;

  IF v_caller_id IS NOT NULL THEN
    v_is_captain := (v_team.captain_id = v_caller_id);
    v_is_admin := public.is_admin_or_cofounder(v_caller_id);
    SELECT EXISTS(SELECT 1 FROM public.team_members WHERE team_id = p_team_id AND user_id = v_caller_id) INTO v_is_member;
  END IF;

  SELECT * INTO v_season FROM public.vsp_get_active_season();

  IF v_season.id IS NOT NULL THEN
    SELECT * INTO v_prog FROM public.team_season_progress WHERE season_id = v_season.id AND team_id = p_team_id;
    SELECT * INTO v_rank_row FROM public.team_monthly_rankings WHERE season_id = v_season.id AND month_key = v_month_key AND team_id = p_team_id;

    IF v_rank_row.team_id IS NOT NULL THEN
      SELECT rnk INTO v_my_rank FROM (
        SELECT team_id,
               DENSE_RANK() OVER (ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC) AS rnk
        FROM public.team_monthly_rankings
        WHERE season_id = v_season.id AND month_key = v_month_key AND lower(btrim(governorate)) = lower(btrim(v_rank_row.governorate))
      ) s WHERE s.team_id = p_team_id;
    END IF;

    IF v_is_member OR v_is_admin THEN
      SELECT * INTO v_mission FROM public.team_monthly_mission_progress WHERE season_id = v_season.id AND month_key = v_month_key AND team_id = p_team_id;
      SELECT * INTO v_immortal FROM public.immortal_reward_entitlements WHERE season_id = v_season.id AND team_id = p_team_id;

      IF v_immortal.id IS NOT NULL THEN
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
          'id', s.id, 'user_id', s.user_id, 'player_name', s.player_name,
          'medal_eligible', s.medal_eligible, 'jersey_eligible', s.jersey_eligible,
          'duplicate_season_blocked', s.duplicate_season_blocked,
          'jersey_size', s.jersey_size, 'jersey_number', s.jersey_number
        ) ORDER BY s.created_at), '[]'::jsonb) INTO v_snapshots
        FROM public.immortal_reward_player_snapshots s WHERE s.entitlement_id = v_immortal.id;
      END IF;

      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', a.id, 'month_key', a.month_key, 'governorate', a.governorate,
        'status', a.status, 'issued_at', a.issued_at, 'redeemed_booking_id', a.redeemed_booking_id
      ) ORDER BY a.issued_at DESC), '[]'::jsonb) INTO v_awards
      FROM public.monthly_champion_awards a WHERE a.team_id = p_team_id;
    END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'code', code, 'title_ar', title_ar, 'title_en', title_en,
    'description_ar', description_ar, 'description_en', description_en,
    'category', category, 'unlocked_at', unlocked_at
  ) ORDER BY unlocked_at DESC), '[]'::jsonb) INTO v_achievements
  FROM public.team_achievements WHERE team_id = p_team_id;

  SELECT COALESCE(jsonb_agg(row_to_json(h) ORDER BY h.year_number DESC), '[]'::jsonb) INTO v_history
  FROM public.team_season_history h WHERE h.team_id = p_team_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'event_id', e.id, 'title_ar', e.title_ar, 'title_en', e.title_en, 'event_date', e.event_date,
    'final_rank', p.final_rank, 'total_weighted_score', p.total_weighted_score, 'xp_awarded', p.xp_awarded,
    'scores', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'test_code', t.test_code, 'title_ar', t.title_ar, 'title_en', t.title_en,
        'raw_metric_value', sc.raw_metric_value, 'normalized_points', sc.normalized_points,
        'max_points', t.max_points, 'weighted_points', sc.weighted_points
      ) ORDER BY t.test_order), '[]'::jsonb)
      FROM public.strongest_team_scores sc
      JOIN public.strongest_team_tests t ON t.id = sc.test_id
      WHERE sc.event_id = e.id AND sc.team_id = p_team_id
    )
  ) ORDER BY e.event_date DESC), '[]'::jsonb) INTO v_strongest
  FROM public.strongest_team_participants p
  JOIN public.strongest_team_events e ON e.id = p.event_id
  WHERE p.team_id = p_team_id AND e.status = 'completed';

  RETURN jsonb_build_object(
    'success', true,
    'is_member', v_is_member,
    'is_captain', v_is_captain,
    'season', CASE WHEN v_season.id IS NOT NULL THEN jsonb_build_object(
      'id', v_season.id, 'code', v_season.season_code, 'year', v_season.year_number,
      'name_ar', v_season.name_ar, 'name_en', v_season.name_en,
      'starts_at', v_season.starts_at, 'ends_at', v_season.ends_at,
      'is_official_live', (now() >= v_season.starts_at AND now() <= v_season.ends_at)
    ) ELSE NULL END,
    'progress', jsonb_build_object(
      'season_xp', COALESCE(v_prog.total_xp, 0),
      'lifetime_xp', COALESCE(v_team.lifetime_xp, 0),
      'current_shield', COALESCE(v_prog.current_shield, 'none'),
      'highest_historical_shield', COALESCE(v_team.highest_historical_shield, 'none'),
      'approved_challenges', COALESCE(v_prog.approved_challenges_count, 0),
      'weighted_challenges', COALESCE(v_prog.weighted_challenges_count, 0),
      'immortal_count', COALESCE(v_team.immortal_count, 0)
    ),
    'monthly_ranking', jsonb_build_object(
      'month_key', v_month_key,
      'rank', v_my_rank,
      'ranking_points', COALESCE(v_rank_row.ranking_points, 0),
      'matches_played', COALESCE(v_rank_row.matches_played, 0),
      'wins', COALESCE(v_rank_row.wins, 0),
      'draws', COALESCE(v_rank_row.draws, 0),
      'losses', COALESCE(v_rank_row.losses, 0)
    ),
    'missions', CASE WHEN v_is_member OR v_is_admin THEN jsonb_build_object(
      'challenges_completed', COALESCE(v_mission.challenges_completed, 0),
      'challenge_wins', COALESCE(v_mission.challenge_wins, 0),
      'unique_opponents', COALESCE(v_mission.unique_opponents, 0),
      'tournaments_completed', COALESCE(v_mission.tournaments_completed, 0),
      'claimed_tiers', COALESCE(v_mission.claimed_tiers, ARRAY[]::text[])
    ) ELSE NULL END,
    'immortal_reward', CASE WHEN v_is_member OR v_is_admin THEN CASE WHEN v_immortal.id IS NOT NULL THEN jsonb_build_object(
      'id', v_immortal.id, 'reward_status', v_immortal.reward_status,
      'delivery_status', v_immortal.delivery_status,
      'sizes_locked', (v_immortal.sizes_locked_at IS NOT NULL),
      'players', v_snapshots
    ) ELSE NULL END ELSE NULL END,
    'free_hour_awards', v_awards,
    'achievements', v_achievements,
    'season_history', v_history,
    'strongest_team_results', v_strongest
  );
END;
$$;

-- Captain/member submits jersey sizes before admin locks fulfillment
CREATE OR REPLACE FUNCTION public.submit_immortal_player_size(
  p_entitlement_id uuid,
  p_target_user_id uuid,
  p_jersey_size text,
  p_contact_phone text DEFAULT NULL,
  p_delivery_address text DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_ent RECORD;
  v_is_captain boolean := false;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;
  IF p_jersey_size NOT IN ('XS','S','M','L','XL','XXL','3XL') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_SIZE');
  END IF;

  SELECT e.*, t.captain_id INTO v_ent
  FROM public.immortal_reward_entitlements e
  JOIN public.teams t ON t.id = e.team_id
  WHERE e.id = p_entitlement_id FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND'); END IF;
  IF v_ent.sizes_locked_at IS NOT NULL OR v_ent.reward_status IN ('preparing','ready','delivered','rejected') THEN
    RETURN jsonb_build_object('success', false, 'error', 'SIZES_ALREADY_LOCKED');
  END IF;

  v_is_captain := (v_ent.captain_id = v_caller);
  IF NOT v_is_captain AND v_caller <> p_target_user_id AND NOT public.is_admin_or_cofounder(v_caller) THEN
    RETURN jsonb_build_object('success', false, 'error', 'FORBIDDEN');
  END IF;

  UPDATE public.immortal_reward_player_snapshots
  SET jersey_size = p_jersey_size, updated_at = now()
  WHERE entitlement_id = p_entitlement_id AND user_id = p_target_user_id;

  IF v_is_captain AND (p_contact_phone IS NOT NULL OR p_delivery_address IS NOT NULL) THEN
    UPDATE public.immortal_reward_entitlements
    SET delivery_contact_phone = COALESCE(p_contact_phone, delivery_contact_phone),
        delivery_address = COALESCE(p_delivery_address, delivery_address),
        sizes_submitted_at = COALESCE(sizes_submitted_at, now()),
        updated_at = now()
    WHERE id = p_entitlement_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============================================================
-- 12. ADMIN RPCs FOR SEASONS, XP ADJUST/REVERSAL, RANKING CLOSE,
--     STRONGEST TEAM, AND IMMORTAL REWARDS (ALL AUDIT-LOGGED)
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_update_season_config_atomic(
  p_season_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_rules_config jsonb DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_old RECORD;
BEGIN
  PERFORM public.require_active_admin_actor();
  IF p_ends_at <= p_starts_at THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DATES');
  END IF;

  SELECT * INTO v_old FROM public.competition_seasons WHERE id = p_season_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'SEASON_NOT_FOUND'); END IF;

  UPDATE public.competition_seasons
  SET starts_at = p_starts_at,
      ends_at   = p_ends_at,
      rules_config = COALESCE(p_rules_config, rules_config),
      updated_at = now()
  WHERE id = p_season_id;

  INSERT INTO public.system_audit_logs (action, table_name, record_id, old_data, new_data, changed_by, changed_by_role, created_at)
  VALUES ('admin_update_season', 'competition_seasons', p_season_id, row_to_json(v_old)::jsonb,
          jsonb_build_object('starts_at', p_starts_at, 'ends_at', p_ends_at), auth.uid(), 'admin', now());

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_adjust_team_xp_atomic(
  p_team_id uuid,
  p_xp_delta numeric,
  p_reason text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season public.competition_seasons;
  v_entry_id uuid;
BEGIN
  PERFORM public.require_active_admin_actor();
  IF p_xp_delta = 0 OR btrim(COALESCE(p_reason, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'VALID_DELTA_AND_REASON_REQUIRED');
  END IF;

  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'NO_ACTIVE_SEASON'); END IF;

  INSERT INTO public.team_xp_ledger (
    season_id, team_id, source_type, source_ref_id, idempotency_key,
    xp_delta, month_key, reason, created_by
  ) VALUES (
    v_season.id, p_team_id, 'admin_adjustment', gen_random_uuid()::text,
    'admin_adj:' || gen_random_uuid()::text,
    round(p_xp_delta, 2), public.vsp_cairo_month_key(now()), p_reason, auth.uid()
  ) RETURNING id INTO v_entry_id;

  PERFORM public.vsp_refresh_team_season_state(v_season.id, p_team_id);

  INSERT INTO public.system_audit_logs (action, table_name, record_id, new_data, changed_by, changed_by_role, created_at)
  VALUES ('admin_adjust_xp', 'team_xp_ledger', v_entry_id,
          jsonb_build_object('team_id', p_team_id, 'xp_delta', p_xp_delta, 'reason', p_reason), auth.uid(), 'admin', now());

  RETURN jsonb_build_object('success', true, 'entry_id', v_entry_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reverse_xp_entry_atomic(
  p_entry_id uuid,
  p_reason text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_orig RECORD;
  v_rev_id uuid;
BEGIN
  PERFORM public.require_active_admin_actor();
  IF btrim(COALESCE(p_reason, '')) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REASON_REQUIRED');
  END IF;

  SELECT * INTO v_orig FROM public.team_xp_ledger WHERE id = p_entry_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ENTRY_NOT_FOUND'); END IF;
  IF v_orig.is_reversal THEN RETURN jsonb_build_object('success', false, 'error', 'CANNOT_REVERSE_REVERSAL'); END IF;

  INSERT INTO public.team_xp_ledger (
    season_id, team_id, source_type, source_ref_id, idempotency_key,
    xp_delta, is_reversal, reversed_entry_id, month_key, reason, created_by
  ) VALUES (
    v_orig.season_id, v_orig.team_id, 'admin_reversal', p_entry_id::text,
    'rev:' || p_entry_id::text,
    -v_orig.xp_delta, true, p_entry_id, public.vsp_cairo_month_key(now()), p_reason, auth.uid()
  ) ON CONFLICT (idempotency_key) DO NOTHING
  RETURNING id INTO v_rev_id;

  IF v_rev_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_REVERSED');
  END IF;

  PERFORM public.vsp_refresh_team_season_state(v_orig.season_id, v_orig.team_id);

  INSERT INTO public.system_audit_logs (action, table_name, record_id, new_data, changed_by, changed_by_role, created_at)
  VALUES ('admin_reverse_xp', 'team_xp_ledger', v_rev_id,
          jsonb_build_object('reversed_entry_id', p_entry_id, 'delta', -v_orig.xp_delta, 'reason', p_reason), auth.uid(), 'admin', now());

  RETURN jsonb_build_object('success', true, 'reversal_id', v_rev_id);
END;
$$;

-- Close Monthly Ranking & issue non-expiring Free Hour awards for EVERY #1 tied team per governorate
CREATE OR REPLACE FUNCTION public.close_monthly_ranking_period(p_month_key text DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_season     public.competition_seasons;
  v_target_mon text := COALESCE(p_month_key, public.vsp_cairo_month_key(now() - interval '1 day'));
  v_winner     RECORD;
  v_awards_cnt int := 0;
BEGIN
  IF auth.uid() IS NOT NULL THEN PERFORM public.require_active_admin_actor(); END IF;

  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'NO_ACTIVE_SEASON'); END IF;

  -- Freeze final ranks per governorate
  WITH ranked AS (
    SELECT season_id, month_key, team_id,
           DENSE_RANK() OVER (
             PARTITION BY lower(btrim(governorate))
             ORDER BY ranking_points DESC, wins DESC, draws DESC, losses ASC, matches_played DESC
           )::int AS rnk
    FROM public.team_monthly_rankings
    WHERE season_id = v_season.id AND month_key = v_target_mon
  )
  UPDATE public.team_monthly_rankings r
  SET final_rank = ranked.rnk, is_frozen = true, updated_at = now()
  FROM ranked
  WHERE r.season_id = ranked.season_id AND r.month_key = ranked.month_key AND r.team_id = ranked.team_id;

  -- Award non-expiring 1 Free Hour to ALL exact rank=1 winners per governorate (Section 5 & 6)
  FOR v_winner IN
    SELECT * FROM public.team_monthly_rankings
    WHERE season_id = v_season.id AND month_key = v_target_mon AND final_rank = 1
  LOOP
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
      PERFORM public.vsp_unlock_achievement_if_new(
        v_season.id, v_winner.team_id, 'month_champion',
        'بطل الشهر', 'Champion of the Month',
        'تصدر ترتيب المحافظة الشهري والفوز بساعة مجانية.',
        'Topped monthly governorate ranking and won 1 free hour.',
        'ranking', v_target_mon
      );

      INSERT INTO public.notifications (user_id, title, body, type, created_at)
      SELECT tm.user_id,
             'بطل الشهر في ' || v_winner.governorate || '! 🏆',
             'مبروك! تصدر فريقك ترتيب شهر ' || v_target_mon || ' واستحق ساعة حجز ملعب مجانية صالحة بدون انتهاء في محافظتك.',
             'monthly_champion',
             now()
      FROM public.team_members tm WHERE tm.team_id = v_winner.team_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'month_key', v_target_mon, 'awards_issued', v_awards_cnt);
END;
$$;

-- Admin updates Immortal reward fulfillment status with audit trail
CREATE OR REPLACE FUNCTION public.admin_update_immortal_reward_status_atomic(
  p_entitlement_id uuid,
  p_reward_status text,
  p_delivery_status text,
  p_lock_sizes boolean DEFAULT false,
  p_actual_cost_egp numeric DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_old RECORD;
BEGIN
  PERFORM public.require_active_admin_actor();
  SELECT * INTO v_old FROM public.immortal_reward_entitlements WHERE id = p_entitlement_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND'); END IF;

  UPDATE public.immortal_reward_entitlements
  SET reward_status = COALESCE(p_reward_status, reward_status),
      delivery_status = COALESCE(p_delivery_status, delivery_status),
      sizes_locked_at = CASE WHEN p_lock_sizes AND sizes_locked_at IS NULL THEN now() ELSE sizes_locked_at END,
      actual_cost_egp = COALESCE(p_actual_cost_egp, actual_cost_egp),
      admin_notes = COALESCE(p_notes, admin_notes),
      delivered_at = CASE WHEN p_delivery_status = 'delivered' AND delivered_at IS NULL THEN now() ELSE delivered_at END,
      updated_at = now()
  WHERE id = p_entitlement_id;

  INSERT INTO public.immortal_reward_audit_logs (
    entitlement_id, actor_id, actor_role, action, old_status, new_status, notes
  ) VALUES (
    p_entitlement_id, auth.uid(), 'admin', 'admin_status_update',
    v_old.reward_status || '/' || v_old.delivery_status,
    COALESCE(p_reward_status, v_old.reward_status) || '/' || COALESCE(p_delivery_status, v_old.delivery_status),
    p_notes
  );

  IF p_delivery_status IN ('preparing','ready','delivered') AND p_delivery_status IS DISTINCT FROM v_old.delivery_status THEN
    INSERT INTO public.notifications (user_id, title, body, type, created_at)
    SELECT captain_id,
           'تحديث جائزة VSP الخاصة 🎁',
           CASE p_delivery_status
             WHEN 'preparing' THEN 'بدأ فريق VSP في تجهيز الجائزة الخاصة لفريقك.'
             WHEN 'ready'     THEN 'الجائزة الخاصة لفريقك جاهزة للتسليم الآن!'
             ELSE 'تم تسليم الجائزة الخاصة لفريقك بنجاح.'
           END,
           'immortal_reward_status',
           now()
    FROM public.teams WHERE id = v_old.team_id;
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Strongest Team Registration (free OR server-verified order) & Admin Finalization
CREATE OR REPLACE FUNCTION public.join_strongest_team_event_atomic(
  p_event_id uuid,
  p_team_id uuid,
  p_selected_player_ids uuid[],
  p_goalkeeper_user_id uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_event  RECORD;
  v_team   RECORD;
  v_cnt    int;
  v_order_ref text;
  v_order_id  uuid;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  SELECT * INTO v_event FROM public.strongest_team_events WHERE id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'EVENT_NOT_FOUND'); END IF;
  IF v_event.status <> 'registration_open' THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_CLOSED');
  END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
  IF NOT FOUND OR v_team.captain_id IS DISTINCT FROM v_caller THEN
    RETURN jsonb_build_object('success', false, 'error', 'CAPTAIN_ONLY');
  END IF;

  IF cardinality(p_selected_player_ids) <> 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EXACTLY_5_PLAYERS_REQUIRED');
  END IF;
  IF (SELECT count(DISTINCT x) FROM unnest(p_selected_player_ids) x) <> 5 THEN
    RETURN jsonb_build_object('success', false, 'error', 'DUPLICATE_PLAYERS');
  END IF;
  IF NOT (p_goalkeeper_user_id = ANY(p_selected_player_ids)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'GOALKEEPER_MUST_BE_IN_5');
  END IF;
  IF EXISTS (
    SELECT 1 FROM unnest(p_selected_player_ids) uid
    WHERE NOT EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = p_team_id AND tm.user_id = uid)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'PLAYERS_MUST_BE_TEAM_MEMBERS');
  END IF;

  IF EXISTS (SELECT 1 FROM public.strongest_team_participants WHERE event_id = p_event_id AND team_id = p_team_id AND registration_status = 'confirmed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'ALREADY_REGISTERED');
  END IF;

  SELECT count(*) INTO v_cnt FROM public.strongest_team_participants WHERE event_id = p_event_id AND registration_status = 'confirmed';
  IF v_cnt >= 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_FULL_MAX_4_TEAMS');
  END IF;

  IF COALESCE(v_event.entry_fee_egp, 0) > 0 THEN
    v_order_ref := 'STRONGEST_' || replace(gen_random_uuid()::text, '-', '');
    INSERT INTO public.strongest_team_orders (
      order_reference, event_id, team_id, captain_user_id, selected_player_ids, goalkeeper_user_id, amount
    ) VALUES (
      v_order_ref, p_event_id, p_team_id, v_caller, p_selected_player_ids, p_goalkeeper_user_id, v_event.entry_fee_egp
    ) RETURNING id INTO v_order_id;
    RETURN jsonb_build_object('success', true, 'requires_payment', true, 'order_reference', v_order_ref, 'order_id', v_order_id, 'amount', v_event.entry_fee_egp);
  END IF;

  INSERT INTO public.strongest_team_participants (
    event_id, team_id, captain_id, selected_player_ids, goalkeeper_user_id, fee_snapshot_egp, payment_status, registration_status
  ) VALUES (
    p_event_id, p_team_id, v_caller, p_selected_player_ids, p_goalkeeper_user_id, 0, 'exempt', 'confirmed'
  );

  RETURN jsonb_build_object('success', true, 'requires_payment', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_strongest_team_payment_atomic(
  p_order_reference text,
  p_paymob_txn_id text,
  p_paymob_order_id text DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_order RECORD;
  v_cnt   int;
BEGIN
  SELECT * INTO v_order FROM public.strongest_team_orders WHERE order_reference = p_order_reference FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'ORDER_NOT_FOUND'); END IF;
  IF v_order.payment_status = 'paid' THEN RETURN jsonb_build_object('success', true, 'already_paid', true); END IF;

  PERFORM 1 FROM public.strongest_team_events WHERE id = v_order.event_id FOR UPDATE;
  SELECT count(*) INTO v_cnt FROM public.strongest_team_participants WHERE event_id = v_order.event_id AND registration_status = 'confirmed';
  IF v_cnt >= 4 THEN
    RETURN jsonb_build_object('success', false, 'error', 'EVENT_FULL_REFUND_NEEDED');
  END IF;

  UPDATE public.strongest_team_orders
  SET payment_status = 'paid', paymob_txn_id = p_paymob_txn_id, paymob_order_id = COALESCE(p_paymob_order_id, paymob_order_id), updated_at = now()
  WHERE id = v_order.id;

  INSERT INTO public.strongest_team_participants (
    event_id, team_id, captain_id, selected_player_ids, goalkeeper_user_id,
    fee_snapshot_egp, payment_status, registration_status
  ) VALUES (
    v_order.event_id, v_order.team_id, v_order.captain_user_id, v_order.selected_player_ids, v_order.goalkeeper_user_id,
    v_order.amount, 'paid', 'confirmed'
  ) ON CONFLICT (event_id, team_id) DO UPDATE SET
    payment_status = 'paid', registration_status = 'confirmed';

  RETURN jsonb_build_object('success', true, 'event_id', v_order.event_id, 'team_id', v_order.team_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_finalize_strongest_team_event_atomic(
  p_event_id uuid,
  p_best_gk_user_id uuid DEFAULT NULL,
  p_best_gk_team_id uuid DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_event    RECORD;
  v_month_key text := public.vsp_cairo_month_key(now());
  v_part     RECORD;
  v_rank     int := 0;
  v_xp       numeric;
BEGIN
  PERFORM public.require_active_admin_actor();

  SELECT * INTO v_event FROM public.strongest_team_events WHERE id = p_event_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'EVENT_NOT_FOUND'); END IF;
  IF v_event.xp_distributed THEN RETURN jsonb_build_object('success', true, 'already_finalized', true); END IF;

  -- Compute weighted totals per participating team
  UPDATE public.strongest_team_participants p
  SET total_weighted_score = COALESCE((
    SELECT SUM(sc.weighted_points)
    FROM public.strongest_team_scores sc
    WHERE sc.event_id = p_event_id AND sc.team_id = p.team_id
  ), 0)
  WHERE p.event_id = p_event_id AND p.registration_status = 'confirmed';

  FOR v_part IN
    SELECT * FROM public.strongest_team_participants
    WHERE event_id = p_event_id AND registration_status = 'confirmed'
    ORDER BY total_weighted_score DESC, registered_at ASC
  LOOP
    v_rank := v_rank + 1;
    v_xp := CASE v_rank WHEN 1 THEN 1400.0 WHEN 2 THEN 1100.0 WHEN 3 THEN 800.0 ELSE 600.0 END;

    UPDATE public.strongest_team_participants
    SET final_rank = v_rank, xp_awarded = v_xp
    WHERE id = v_part.id;

    INSERT INTO public.team_xp_ledger (
      season_id, team_id, source_type, source_ref_id, idempotency_key,
      xp_delta, month_key, reason, metadata, created_by
    ) VALUES (
      v_event.season_id, v_part.team_id, 'strongest_team', p_event_id::text,
      'strongest:' || p_event_id::text || ':team:' || v_part.team_id::text,
      v_xp, v_month_key, 'نتيجة بطولة أقوى فريق (المركز ' || v_rank || ')',
      jsonb_build_object('event_id', p_event_id, 'rank', v_rank, 'score', v_part.total_weighted_score),
      auth.uid()
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    UPDATE public.team_season_progress
    SET strongest_team_participations = strongest_team_participations + 1,
        strongest_team_wins = strongest_team_wins + CASE WHEN v_rank = 1 THEN 1 ELSE 0 END,
        updated_at = now()
    WHERE season_id = v_event.season_id AND team_id = v_part.team_id;

    IF v_rank = 1 THEN
      PERFORM public.vsp_unlock_achievement_if_new(
        v_event.season_id, v_part.team_id, 'strongest_team_winner',
        'أقوى فريق', 'Strongest Team',
        'التتويج بلقب بطولة أقوى فريق الرسمية من VSP.',
        'Won the official VSP Strongest Team Championship.',
        'strongest_team', p_event_id::text
      );
    END IF;

    PERFORM public.vsp_grant_tournament_mission_if_eligible(v_event.season_id, v_month_key, v_part.team_id, 'strongest:' || p_event_id::text);
    PERFORM public.vsp_refresh_team_season_state(v_event.season_id, v_part.team_id);
  END LOOP;

  UPDATE public.strongest_team_events
  SET status = 'completed',
      rules_locked = true,
      xp_distributed = true,
      best_gk_winner_user_id = COALESCE(p_best_gk_user_id, best_gk_winner_user_id),
      best_gk_winner_team_id = COALESCE(p_best_gk_team_id, best_gk_winner_team_id),
      updated_at = now()
  WHERE id = p_event_id;

  INSERT INTO public.system_audit_logs (action, table_name, record_id, new_data, changed_by, changed_by_role, created_at)
  VALUES ('finalize_strongest_team', 'strongest_team_events', p_event_id,
          jsonb_build_object('best_gk_user_id', p_best_gk_user_id, 'teams_finalized', v_rank), auth.uid(), 'admin', now());

  RETURN jsonb_build_object('success', true, 'teams_finalized', v_rank);
END;
$$;

-- ============================================================
-- 13. ROW LEVEL SECURITY & LEAST PRIVILEGE GRANTS
-- ============================================================
ALTER TABLE public.competition_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_xp_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_season_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_season_opponents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_monthly_opponents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_monthly_mission_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_monthly_rankings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_champion_awards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ranking_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_season_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immortal_reward_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immortal_reward_player_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.immortal_reward_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strongest_team_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strongest_team_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strongest_team_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strongest_team_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.strongest_team_scores ENABLE ROW LEVEL SECURITY;

-- Public/authenticated read policies for non-PII competition tables
DROP POLICY IF EXISTS "public_read_seasons" ON public.competition_seasons;
CREATE POLICY "public_read_seasons" ON public.competition_seasons FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_progress" ON public.team_season_progress;
CREATE POLICY "public_read_progress" ON public.team_season_progress FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_rankings" ON public.team_monthly_rankings;
CREATE POLICY "public_read_rankings" ON public.team_monthly_rankings FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_achievements" ON public.team_achievements;
CREATE POLICY "public_read_achievements" ON public.team_achievements FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_history" ON public.team_season_history;
CREATE POLICY "public_read_history" ON public.team_season_history FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_strongest_events" ON public.strongest_team_events;
CREATE POLICY "public_read_strongest_events" ON public.strongest_team_events FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_strongest_tests" ON public.strongest_team_tests;
CREATE POLICY "public_read_strongest_tests" ON public.strongest_team_tests FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_strongest_participants" ON public.strongest_team_participants;
CREATE POLICY "public_read_strongest_participants" ON public.strongest_team_participants FOR SELECT USING (true);

DROP POLICY IF EXISTS "public_read_strongest_scores" ON public.strongest_team_scores;
CREATE POLICY "public_read_strongest_scores" ON public.strongest_team_scores FOR SELECT USING (true);

-- Team-scoped private tables
DROP POLICY IF EXISTS "members_read_own_xp_ledger" ON public.team_xp_ledger;
CREATE POLICY "members_read_own_xp_ledger" ON public.team_xp_ledger FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = team_xp_ledger.team_id AND tm.user_id = auth.uid()) OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "members_read_own_missions" ON public.team_monthly_mission_progress;
CREATE POLICY "members_read_own_missions" ON public.team_monthly_mission_progress FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = team_monthly_mission_progress.team_id AND tm.user_id = auth.uid()) OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "members_read_own_awards" ON public.monthly_champion_awards;
CREATE POLICY "members_read_own_awards" ON public.monthly_champion_awards FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = monthly_champion_awards.team_id AND tm.user_id = auth.uid()) OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "members_read_own_immortal_entitlement" ON public.immortal_reward_entitlements;
CREATE POLICY "members_read_own_immortal_entitlement" ON public.immortal_reward_entitlements FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = immortal_reward_entitlements.team_id AND tm.user_id = auth.uid()) OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "members_read_own_immortal_snapshots" ON public.immortal_reward_player_snapshots;
CREATE POLICY "members_read_own_immortal_snapshots" ON public.immortal_reward_player_snapshots FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = immortal_reward_player_snapshots.team_id AND tm.user_id = auth.uid()) OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "admin_only_immortal_audit" ON public.immortal_reward_audit_logs;
CREATE POLICY "admin_only_immortal_audit" ON public.immortal_reward_audit_logs FOR SELECT
  USING (public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "captain_read_own_strongest_orders" ON public.strongest_team_orders;
CREATE POLICY "captain_read_own_strongest_orders" ON public.strongest_team_orders FOR SELECT
  USING (captain_user_id = auth.uid() OR public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "admin_manage_strongest_events" ON public.strongest_team_events;
CREATE POLICY "admin_manage_strongest_events" ON public.strongest_team_events FOR ALL
  USING (public.is_admin_or_cofounder(auth.uid())) WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "admin_manage_strongest_tests" ON public.strongest_team_tests;
CREATE POLICY "admin_manage_strongest_tests" ON public.strongest_team_tests FOR ALL
  USING (public.is_admin_or_cofounder(auth.uid())) WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "admin_manage_strongest_scores" ON public.strongest_team_scores;
CREATE POLICY "admin_manage_strongest_scores" ON public.strongest_team_scores FOR ALL
  USING (public.is_admin_or_cofounder(auth.uid())) WITH CHECK (public.is_admin_or_cofounder(auth.uid()));

DROP POLICY IF EXISTS "members_disputes_rw" ON public.ranking_disputes;
CREATE POLICY "members_disputes_rw" ON public.ranking_disputes FOR SELECT
  USING (created_by = auth.uid() OR public.is_admin_or_cofounder(auth.uid()));

-- Non-PII Public view for Immortal Winners Hall of Fame (website & app)
CREATE OR REPLACE VIEW public.immortal_winners_public AS
SELECT
  e.id,
  e.season_id,
  s.year_number,
  s.name_ar AS season_name_ar,
  s.name_en AS season_name_en,
  e.team_id,
  t.name AS team_name,
  t.logo_url,
  t.governorate,
  e.achievement_date,
  e.season_xp_at_qual,
  e.approved_challenges_qual
FROM public.immortal_reward_entitlements e
JOIN public.competition_seasons s ON s.id = e.season_id
JOIN public.teams t ON t.id = e.team_id
WHERE e.reward_status IN ('eligible','approved','preparing','ready','delivered');

GRANT SELECT ON public.competition_seasons, public.team_season_progress, public.team_monthly_rankings,
  public.team_achievements, public.team_season_history, public.strongest_team_events,
  public.strongest_team_tests, public.strongest_team_participants, public.strongest_team_scores,
  public.immortal_winners_public TO anon, authenticated;

GRANT SELECT ON public.team_xp_ledger, public.team_monthly_mission_progress, public.monthly_champion_awards,
  public.immortal_reward_entitlements, public.immortal_reward_player_snapshots, public.immortal_reward_audit_logs,
  public.strongest_team_orders, public.ranking_disputes TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_challenge_opponent_repeat_status(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_monthly_competitive_ranking(text, text, int, int) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_most_active_teams_ranking(uuid, text, int, int) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_gamification_profile(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_immortal_player_size(uuid, uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_strongest_team_event_atomic(uuid, uuid, uuid[], uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_strongest_team_payment_atomic(text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_season_config_atomic(uuid, timestamptz, timestamptz, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_team_xp_atomic(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reverse_xp_entry_atomic(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_monthly_ranking_period(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_immortal_reward_status_atomic(uuid, text, text, boolean, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_finalize_strongest_team_event_atomic(uuid, uuid, uuid) TO authenticated;

-- ============================================================
-- 14. REDEEM MONTHLY FREE HOUR AWARD & ANNUAL ROLLOVER
-- ============================================================
CREATE OR REPLACE FUNCTION public.book_stadium_with_monthly_award_atomic(
  p_award_id uuid,
  p_stadium_id uuid,
  p_start_time timestamptz,
  p_end_time timestamptz
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_caller   uuid := auth.uid();
  v_award    RECORD;
  v_team     RECORD;
  v_stadium  RECORD;
  v_dur_hr   numeric;
  v_price    numeric;
  v_booking_id uuid;
  v_op_date  date;
BEGIN
  IF v_caller IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED'); END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_award FROM public.monthly_champion_awards WHERE id = p_award_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'AWARD_NOT_FOUND'); END IF;
  IF v_award.status <> 'issued' THEN RETURN jsonb_build_object('success', false, 'error', 'AWARD_ALREADY_USED_OR_VOID'); END IF;

  SELECT * INTO v_team FROM public.teams WHERE id = v_award.team_id;
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

  IF lower(btrim(COALESCE(v_stadium.governorate, ''))) <> lower(btrim(v_award.governorate)) THEN
    RETURN jsonb_build_object('success', false, 'error', 'GOVERNORATE_MISMATCH_WITH_AWARD');
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
      AND status IN ('pending','confirmed','completed')
      AND start_time < p_end_time AND end_time > p_start_time
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_ALREADY_BOOKED');
  END IF;

  -- Owner gets paid 100% of pitch rate (funded by VSP, zero cost to owner or team!)
  v_price := round(COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0), 2);
  v_op_date := (p_start_time AT TIME ZONE 'Africa/Cairo')::date;

  INSERT INTO public.bookings (
    stadium_id, owner_id, user_id, created_by_user_id, stadium_name, stadium_image_url,
    start_time, end_time, operational_date, booking_type, player_team_id, player_team_name,
    is_private, total_price, deposit_paid, is_deposit_paid, is_paid, payment_status,
    payment_method, payment_source, payment_transaction_id, platform_fee, vsp_commission, gateway_fee,
    status, currency, is_verified_by_owner
  ) VALUES (
    p_stadium_id, v_stadium.owner_id, v_caller, v_caller, v_stadium.name, v_stadium.image_url,
    p_start_time, p_end_time, v_op_date, 'team', v_team.id, v_team.name,
    true, v_price, v_price, true, true, 'paid',
    'vsp_monthly_award', 'vsp_monthly_award', 'AWARD_' || v_award.id::text, 0, 0, 0,
    'confirmed', 'EGP', true
  ) RETURNING id INTO v_booking_id;

  UPDATE public.monthly_champion_awards
  SET status = 'redeemed',
      redeemed_booking_id = v_booking_id,
      redeemed_at = now(),
      reimbursed_amount_egp = v_price,
      updated_at = now()
  WHERE id = v_award.id;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, type, status, payment_method, metadata, created_at, updated_at
  ) VALUES (
    v_stadium.owner_id, v_booking_id, v_price, 'vsp_monthly_award_credit', 'completed', 'vsp_monthly_award',
    jsonb_build_object('award_id', v_award.id, 'team_id', v_team.id, 'month_key', v_award.month_key, 'vsp_funded', true),
    now(), now()
  );

  RETURN jsonb_build_object('success', true, 'booking_id', v_booking_id, 'vsp_covered_amount', v_price);
END;
$$;

GRANT EXECUTE ON FUNCTION public.book_stadium_with_monthly_award_atomic(uuid, uuid, timestamptz, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION public.rollover_annual_season_atomic(
  p_closing_season_id uuid,
  p_next_year integer DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_closing RECORD;
  v_next_yr int;
  v_next_id uuid;
  v_prog    RECORD;
  v_archived int := 0;
BEGIN
  IF auth.uid() IS NOT NULL THEN PERFORM public.require_active_admin_actor(); END IF;
  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_closing FROM public.competition_seasons WHERE id = p_closing_season_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'SEASON_NOT_FOUND'); END IF;
  IF v_closing.status = 'archived' THEN RETURN jsonb_build_object('success', true, 'already_archived', true); END IF;

  v_next_yr := COALESCE(p_next_year, v_closing.year_number + 1);

  -- Archive every team's season record permanently before resetting Season XP & current shield
  FOR v_prog IN
    SELECT p.*,
           (SELECT min(r.final_rank) FROM public.team_monthly_rankings r WHERE r.season_id = p_closing_season_id AND r.team_id = p.team_id AND r.final_rank IS NOT NULL) AS best_rank,
           (SELECT e.reward_status FROM public.immortal_reward_entitlements e WHERE e.season_id = p_closing_season_id AND e.team_id = p.team_id LIMIT 1) AS imm_status
    FROM public.team_season_progress p
    WHERE p.season_id = p_closing_season_id
  LOOP
    INSERT INTO public.team_season_history (
      season_id, team_id, year_number, final_shield, final_xp,
      approved_challenges, weighted_challenges, wins, draws, losses,
      tournaments_completed, tournaments_won, best_monthly_rank,
      immortal_achieved, immortal_reward_status
    ) VALUES (
      p_closing_season_id, v_prog.team_id, v_closing.year_number, v_prog.current_shield, v_prog.total_xp,
      v_prog.approved_challenges_count, v_prog.weighted_challenges_count, v_prog.challenge_wins, v_prog.challenge_draws, v_prog.challenge_losses,
      v_prog.tournaments_completed_count, v_prog.tournaments_won_count, v_prog.best_rank,
      (v_prog.current_shield = 'immortal'), v_prog.imm_status
    ) ON CONFLICT (season_id, team_id) DO NOTHING;

    UPDATE public.teams
    SET previous_season_shield = v_prog.current_shield,
        current_season_xp = 0,
        current_shield = 'none',
        updated_at = now()
    WHERE id = v_prog.team_id;

    v_archived := v_archived + 1;
  END LOOP;

  UPDATE public.competition_seasons
  SET status = 'archived', closed_at = now(), updated_at = now()
  WHERE id = p_closing_season_id;

  -- Open next calendar year season in Africa/Cairo
  INSERT INTO public.competition_seasons (season_code, year_number, name_ar, name_en, starts_at, ends_at, status)
  VALUES (
    v_next_yr::text,
    v_next_yr,
    'الموسم السنوي ' || v_next_yr::text,
    'Annual Season ' || v_next_yr::text,
    (v_next_yr::text || '-01-01 00:00:00 Africa/Cairo')::timestamptz,
    (v_next_yr::text || '-12-31 23:59:59 Africa/Cairo')::timestamptz,
    'active'
  )
  ON CONFLICT (season_code) DO UPDATE SET status = 'active', updated_at = now()
  RETURNING id INTO v_next_id;

  RETURN jsonb_build_object('success', true, 'archived_teams', v_archived, 'new_season_id', v_next_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.rollover_annual_season_atomic(uuid, integer) TO authenticated, service_role;

-- ============================================================
-- 15. LEGACY 1v1 SUNSET (Preserve all historical/financial rows!)
-- ============================================================
UPDATE public.vsp_1v1_tournaments
SET status = 'archived', updated_at = now()
WHERE status IN ('draft','registration_open','in_progress','published');

-- Safe disable of 1v1 cron job if scheduled
DO $$
BEGIN
  PERFORM cron.unschedule('expire-pending-1v1-orders');
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

COMMIT;
