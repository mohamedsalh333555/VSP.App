-- VSP 2-Month Competitive Seasons, Cash Rewards (Top 1-5) & Free Hour Vouchers (Ranks 6-10)
-- Target: vsp-staging (idempotent migration, safe to re-run)

CREATE TABLE IF NOT EXISTS public.competitive_seasons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_code TEXT NOT NULL UNIQUE,
  title_ar TEXT NOT NULL,
  title_en TEXT NOT NULL,
  governorate TEXT,
  duration_months INTEGER NOT NULL DEFAULT 2 CHECK (duration_months >= 1 AND duration_months <= 12),
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('upcoming', 'active', 'settling', 'settled', 'archived')),
  cash_pool_egp INTEGER NOT NULL DEFAULT 1500,
  free_hour_max_value_egp INTEGER NOT NULL DEFAULT 180,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at > starts_at)
);

CREATE TABLE IF NOT EXISTS public.season_reward_entitlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id UUID NOT NULL REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
  team_id UUID NOT NULL,
  governorate TEXT NOT NULL,
  rank_position INTEGER NOT NULL CHECK (rank_position >= 1),
  zone_type TEXT NOT NULL CHECK (zone_type IN ('cash_rewards', 'free_booking', 'competition')),
  reward_type TEXT NOT NULL CHECK (reward_type IN ('cash', 'free_hour')),
  cash_amount_egp INTEGER NOT NULL DEFAULT 0 CHECK (cash_amount_egp >= 0),
  max_voucher_value_egp INTEGER NOT NULL DEFAULT 0 CHECK (max_voucher_value_egp >= 0),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'approved', 'available', 'reserved', 'redeemed', 'expired', 'revoked')
  ),
  idempotency_key TEXT NOT NULL UNIQUE,
  reserved_booking_id UUID,
  redeemed_at TIMESTAMPTZ,
  payout_reference TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (season_id, team_id)
);

CREATE TABLE IF NOT EXISTS public.season_match_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id UUID REFERENCES public.competitive_seasons(id) ON DELETE SET NULL,
  booking_id UUID NOT NULL,
  team_id UUID NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('win', 'draw', 'loss', 'void')),
  points_delta INTEGER NOT NULL,
  is_correction BOOLEAN NOT NULL DEFAULT FALSE,
  reversed_event_id UUID REFERENCES public.season_match_events(id) ON DELETE SET NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_season_reward_entitlements_team_status
  ON public.season_reward_entitlements (team_id, status);

CREATE INDEX IF NOT EXISTS idx_season_match_events_booking_team
  ON public.season_match_events (booking_id, team_id);

ALTER TABLE public.competitive_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.season_reward_entitlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.season_match_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'competitive_seasons' AND policyname = 'competitive_seasons_read_all'
  ) THEN
    CREATE POLICY competitive_seasons_read_all
      ON public.competitive_seasons FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'season_reward_entitlements' AND policyname = 'season_reward_entitlements_read_all'
  ) THEN
    CREATE POLICY season_reward_entitlements_read_all
      ON public.season_reward_entitlements FOR SELECT
      TO authenticated
      USING (true);
  END IF;
END $$;
