-- ============================================================================
-- VSP PLATFORM: SECURITY, RLS & PERFORMANCE OPTIMIZATION MIGRATION
-- Pass 2: Category 1: Security Hardening, RLS Policies & Performance Indexes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PERFORMANCE INDEXES (H-01)
-- ----------------------------------------------------------------------------

-- A. Bookings Table Indexes
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_start 
ON public.bookings (stadium_id, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_user_status 
ON public.bookings (user_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_created_by 
ON public.bookings (created_by_user_id, status);

CREATE INDEX IF NOT EXISTS idx_bookings_owner_op_date 
ON public.bookings (owner_id, operational_date);

CREATE INDEX IF NOT EXISTS idx_bookings_joined_user_ids 
ON public.bookings USING GIN (joined_user_ids);

CREATE INDEX IF NOT EXISTS idx_bookings_status_payment 
ON public.bookings (status, payment_status, is_paid);

-- B. Conversations & Chat Messages Indexes
CREATE INDEX IF NOT EXISTS idx_conversations_participants 
ON public.conversations USING GIN (participant_ids);

CREATE INDEX IF NOT EXISTS idx_conversations_booking 
ON public.conversations (booking_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation_created 
ON public.chat_messages (conversation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_booking_created 
ON public.chat_messages (booking_id, created_at DESC);

-- C. Tournament Matches & Championships Indexes
CREATE INDEX IF NOT EXISTS idx_tournament_matches_champ_round 
ON public.tournament_matches (championship_id, round_index, match_index);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_stage 
ON public.tournament_matches (championship_id, stage);

CREATE INDEX IF NOT EXISTS idx_championships_status_sport 
ON public.championships (status, sport_type, governorate);

CREATE INDEX IF NOT EXISTS idx_championship_rosters_champ_team 
ON public.championship_rosters (championship_id, team_id);

-- D. Stadiums & Teams Indexes
CREATE INDEX IF NOT EXISTS idx_stadiums_owner_active 
ON public.stadiums (owner_id) WHERE is_deleted_by_owner = false;

CREATE INDEX IF NOT EXISTS idx_stadiums_discovery 
ON public.stadiums (governorate, is_verified, is_blocked) WHERE is_deleted_by_owner = false;

CREATE INDEX IF NOT EXISTS idx_teams_captain 
ON public.teams (captain_id);

CREATE INDEX IF NOT EXISTS idx_teams_governorate_sport 
ON public.teams (governorate, sport_type, points DESC);

CREATE INDEX IF NOT EXISTS idx_team_members_user_team 
ON public.team_members (user_id, team_id);

CREATE INDEX IF NOT EXISTS idx_users_phone 
ON public.users (phone);

CREATE INDEX IF NOT EXISTS idx_users_role_status 
ON public.users (role, is_blocked, verification_status);


-- ----------------------------------------------------------------------------
-- 2. SECURITY & RLS POLICIES HARDENING (C-01, C-02, C-04, C-05)
-- ----------------------------------------------------------------------------

-- A. Users Table: Restrict Public PII Access (C-01)
DROP POLICY IF EXISTS users_select_safe_public ON public.users;
DROP POLICY IF EXISTS users_select_authenticated ON public.users;
DROP POLICY IF EXISTS users_select_anon ON public.users;

-- Authenticated users can read player profiles for matchmaking and team rosters
CREATE POLICY users_select_authenticated ON public.users
FOR SELECT TO authenticated
USING (
  (auth.uid() = id) OR 
  (is_blocked = false) OR 
  (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder')))
);

-- Public / Anonymous can only select active, unblocked users with minimal fields
CREATE POLICY users_select_anon ON public.users
FOR SELECT TO anon
USING (is_blocked = false AND is_registration_complete = true);


-- B. Teams Table: Trigger to Prevent Direct Leaderboard/Elo Fraud by Captains (C-04)
CREATE OR REPLACE FUNCTION public.protect_team_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Allow service_role or admins/co-founders to modify all fields
  IF (auth.jwt()->>'role' = 'service_role') OR 
     (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder'))) THEN
    RETURN NEW;
  END IF;

  -- If regular captain is updating, prevent mutating competitive stats directly
  IF (OLD.points IS DISTINCT FROM NEW.points) OR
     (OLD.wins IS DISTINCT FROM NEW.wins) OR
     (OLD.draws IS DISTINCT FROM NEW.draws) OR
     (OLD.losses IS DISTINCT FROM NEW.losses) OR
     (OLD.matches_played IS DISTINCT FROM NEW.matches_played) OR
     (OLD.current_winning_streak IS DISTINCT FROM NEW.current_winning_streak) OR
     (OLD.championships_won IS DISTINCT FROM NEW.championships_won) OR
     (OLD.is_official IS DISTINCT FROM NEW.is_official) OR
     (OLD.verified_badge IS DISTINCT FROM NEW.verified_badge) OR
     (OLD.fair_play_score IS DISTINCT FROM NEW.fair_play_score) THEN
     
     -- Reset protected fields back to original values silently
     NEW.points := OLD.points;
     NEW.wins := OLD.wins;
     NEW.draws := OLD.draws;
     NEW.losses := OLD.losses;
     NEW.matches_played := OLD.matches_played;
     NEW.current_winning_streak := OLD.current_winning_streak;
     NEW.championships_won := OLD.championships_won;
     NEW.is_official := OLD.is_official;
     NEW.verified_badge := OLD.verified_badge;
     NEW.fair_play_score := OLD.fair_play_score;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_teams_sensitive_fields ON public.teams;
CREATE TRIGGER trg_protect_teams_sensitive_fields
BEFORE UPDATE ON public.teams
FOR EACH ROW
EXECUTE FUNCTION public.protect_team_sensitive_fields();


-- C. Tournament Matches: Prevent Tampering with Completed Matches (C-05)
CREATE OR REPLACE FUNCTION public.protect_completed_match_scores()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_champ_status text;
BEGIN
  -- Allow service_role or admin
  IF (auth.jwt()->>'role' = 'service_role') OR 
     (EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder'))) THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_champ_status FROM public.championships WHERE id = OLD.championship_id;

  IF (v_champ_status = 'completed') THEN
    RAISE EXCEPTION 'cannot_modify_completed_championship_match';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_completed_match_scores ON public.tournament_matches;
CREATE TRIGGER trg_protect_completed_match_scores
BEFORE UPDATE ON public.tournament_matches
FOR EACH ROW
EXECUTE FUNCTION public.protect_completed_match_scores();
