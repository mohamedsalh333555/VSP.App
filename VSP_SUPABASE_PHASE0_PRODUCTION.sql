-- ==============================================================================
-- 🏆 VSP SPORTS PLATFORM — SUPABASE PHASE 0 & PHASE 1 PRODUCTION MIGRATION
-- ==============================================================================
-- Instructions: Copy all content below, paste into Supabase Dashboard -> SQL Editor, and click RUN.
-- This script is 100% idempotent (safe to run multiple times without breaking existing data).

-- ------------------------------------------------------------------------------
-- 1. OPERATIONAL SHIFT DATE FUNCTION & GENERATED COLUMN
-- ------------------------------------------------------------------------------
-- Shifts starting late at night (e.g. 1:00 AM - 3:00 AM) belong to the stadium's
-- previous operational shift day. Shift rollover threshold is 6:00 AM.

CREATE OR REPLACE FUNCTION public.get_operational_date(
  p_timestamp TIMESTAMPTZ,
  p_shift_start_hour INT DEFAULT 6
)
RETURNS DATE
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF EXTRACT(HOUR FROM (p_timestamp AT TIME ZONE 'Africa/Cairo')) < p_shift_start_hour THEN
    RETURN ((p_timestamp AT TIME ZONE 'Africa/Cairo') - INTERVAL '1 day')::DATE;
  ELSE
    RETURN (p_timestamp AT TIME ZONE 'Africa/Cairo')::DATE;
  END IF;
END;
$$;

-- Add operational_date to bookings table if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'operational_date'
  ) THEN
    ALTER TABLE public.bookings ADD COLUMN operational_date DATE GENERATED ALWAYS AS (
      get_operational_date(start_time, 6)
    ) STORED;
  END IF;
END $$;

-- Compound indexes for high-speed queries on bookings
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_start ON public.bookings(stadium_id, start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner_status ON public.bookings(owner_id, status);
CREATE INDEX IF NOT EXISTS idx_bookings_op_date ON public.bookings(operational_date);


-- ------------------------------------------------------------------------------
-- 2. PAYMOB TRANSACTIONS DEDUPLICATION & IDEMPOTENCY TABLE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.paymob_transactions (
  transaction_id TEXT PRIMARY KEY,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  amount_cents BIGINT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT FALSE,
  currency TEXT DEFAULT 'EGP',
  processed_at TIMESTAMPTZ DEFAULT NOW(),
  raw_payload JSONB
);

ALTER TABLE public.paymob_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role manages paymob transactions" ON public.paymob_transactions;
CREATE POLICY "Service role manages paymob transactions"
ON public.paymob_transactions FOR ALL
TO service_role
USING (true);


-- ------------------------------------------------------------------------------
-- 3. AUTOMATIC EXPIRY & AUTO-APPROVE VIA PG_CRON
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function: Cancel unconfirmed pending bookings older than 90 seconds
CREATE OR REPLACE FUNCTION public.auto_expire_pending_bookings_90s()
RETURNS void AS $$
BEGIN
  UPDATE public.bookings
  SET 
    status = 'cancelled',
    updated_at = NOW(),
    notes = COALESCE(notes, '') || E'\n[SYSTEM: Auto-expired due to 90-second timeout]'
  WHERE 
    status = 'pending'
    AND is_paid = FALSE
    AND payment_status NOT IN ('paid', 'completed')
    AND created_at <= NOW() - INTERVAL '90 seconds';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule cron job every 1 minute
SELECT cron.schedule(
  'expire-pending-bookings-90s',
  '* * * * *',
  $$ SELECT public.auto_expire_pending_bookings_90s(); $$
);

-- Function: Auto-approve match results after 24 hours
CREATE OR REPLACE FUNCTION public.auto_approve_tournament_matches_24h()
RETURNS void AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tournament_matches') THEN
    UPDATE public.tournament_matches
    SET 
      status = 'approved',
      updated_at = NOW()
    WHERE 
      status = 'pending_confirmation'
      AND submitted_at <= NOW() - INTERVAL '24 hours';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule cron job every hour
SELECT cron.schedule(
  'auto-approve-matches-24h',
  '0 * * * *',
  $$ SELECT public.auto_approve_tournament_matches_24h(); $$
);


-- ------------------------------------------------------------------------------
-- 4. TIGHTENED ROW LEVEL SECURITY (RLS) POLICIES FOR ALL 11 TABLES
-- ------------------------------------------------------------------------------

-- 1. BOOKINGS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can select own or owner bookings" ON public.bookings;
CREATE POLICY "Users can select own or owner bookings"
ON public.bookings FOR SELECT
TO authenticated
USING (
  auth.uid()::text = user_id::text 
  OR auth.uid()::text = owner_id::text
  OR EXISTS (
    SELECT 1 FROM public.stadiums s
    WHERE s.id = bookings.stadium_id AND s.owner_id::text = auth.uid()::text
  )
);

DROP POLICY IF EXISTS "Players can insert own bookings" ON public.bookings;
CREATE POLICY "Players can insert own bookings"
ON public.bookings FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Players and owners can update bookings" ON public.bookings;
CREATE POLICY "Players and owners can update bookings"
ON public.bookings FOR UPDATE
TO authenticated
USING (
  auth.uid()::text = user_id::text 
  OR auth.uid()::text = owner_id::text
);

-- 2. USERS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view basic user profiles" ON public.users;
CREATE POLICY "Public can view basic user profiles"
ON public.users FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
TO authenticated
USING (auth.uid()::text = id::text);

-- 3. STADIUMS
ALTER TABLE public.stadiums ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active stadiums" ON public.stadiums;
CREATE POLICY "Anyone can view active stadiums"
ON public.stadiums FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Owners can manage own stadiums" ON public.stadiums;
CREATE POLICY "Owners can manage own stadiums"
ON public.stadiums FOR ALL
TO authenticated
USING (auth.uid()::text = owner_id::text);

-- 4. TEAMS
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view teams" ON public.teams;
CREATE POLICY "Anyone can view teams"
ON public.teams FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Captains can manage team" ON public.teams;
CREATE POLICY "Captains can manage team"
ON public.teams FOR ALL
TO authenticated
USING (auth.uid()::text = captain_id::text);

-- 5. TEAM MEMBERS
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view team members" ON public.team_members;
CREATE POLICY "Anyone can view team members"
ON public.team_members FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Captains or members manage team membership" ON public.team_members;
CREATE POLICY "Captains or members manage team membership"
ON public.team_members FOR ALL
TO authenticated
USING (
  auth.uid()::text = user_id::text
  OR EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_members.team_id AND t.captain_id::text = auth.uid()::text
  )
);

-- 6. CHAMPIONSHIPS
ALTER TABLE public.championships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players can view approved championships" ON public.championships;
CREATE POLICY "Players can view approved championships"
ON public.championships FOR SELECT
TO authenticated, anon
USING (is_approved = true OR auth.uid()::text = owner_id::text);

DROP POLICY IF EXISTS "Owners manage own championships" ON public.championships;
CREATE POLICY "Owners manage own championships"
ON public.championships FOR ALL
TO authenticated
USING (auth.uid()::text = owner_id::text);

-- 7. REVIEWS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view reviews" ON public.reviews;
CREATE POLICY "Anyone can view reviews"
ON public.reviews FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Players insert own reviews" ON public.reviews;
CREATE POLICY "Players insert own reviews"
ON public.reviews FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = user_id::text);

-- 8. NOTIFICATIONS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own notifications" ON public.notifications;
CREATE POLICY "Users view own notifications"
ON public.notifications FOR SELECT
TO authenticated
USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Users update own notifications" ON public.notifications;
CREATE POLICY "Users update own notifications"
ON public.notifications FOR UPDATE
TO authenticated
USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "Authenticated insert notifications" ON public.notifications;
CREATE POLICY "Authenticated insert notifications"
ON public.notifications FOR INSERT
TO authenticated
WITH CHECK (true);

-- 9. CHAT MESSAGES
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view involved chat messages" ON public.chat_messages;
CREATE POLICY "Users view involved chat messages"
ON public.chat_messages FOR SELECT
TO authenticated
USING (auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text);

DROP POLICY IF EXISTS "Users send chat messages" ON public.chat_messages;
CREATE POLICY "Users send chat messages"
ON public.chat_messages FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = sender_id::text);

-- 10. REPORTS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reporters view own reports" ON public.reports;
CREATE POLICY "Reporters view own reports"
ON public.reports FOR SELECT
TO authenticated
USING (auth.uid()::text = reporter_id::text);

DROP POLICY IF EXISTS "Reporters insert reports" ON public.reports;
CREATE POLICY "Reporters insert reports"
ON public.reports FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = reporter_id::text);

-- 11. APP SETTINGS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read app settings" ON public.app_settings;
CREATE POLICY "Anyone can read app settings"
ON public.app_settings FOR SELECT
TO authenticated, anon
USING (true);
