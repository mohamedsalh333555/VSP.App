-- ==============================================================================
-- 🏆 VSP MIGRATION 202608110001: COMPREHENSIVE RLS AUDIT & SECURITY POLICIES
-- ==============================================================================
-- Purpose: Enforce Row Level Security (RLS) on all 17 tables with granular role-based access.

-- ------------------------------------------------------------------------------
-- 1. BOOKINGS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
CREATE POLICY "bookings_select_policy" ON public.bookings
FOR SELECT TO authenticated
USING (
  auth.uid()::text = user_id::text 
  OR auth.uid()::text = owner_id::text
  OR EXISTS (
    SELECT 1 FROM public.stadiums s 
    WHERE s.id = bookings.stadium_id AND s.owner_id::text = auth.uid()::text
  )
);

DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
CREATE POLICY "bookings_insert_policy" ON public.bookings
FOR INSERT TO authenticated
WITH CHECK (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;
CREATE POLICY "bookings_update_policy" ON public.bookings
FOR UPDATE TO authenticated
USING (
  auth.uid()::text = user_id::text 
  OR auth.uid()::text = owner_id::text
);

-- ------------------------------------------------------------------------------
-- 2. USERS (Role column protection)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_policy" ON public.users;
CREATE POLICY "users_select_policy" ON public.users
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "users_update_policy" ON public.users;
CREATE POLICY "users_update_policy" ON public.users
FOR UPDATE TO authenticated
USING (auth.uid()::text = id::text)
WITH CHECK (
  -- Prevent authenticated users from changing their role unless already admin/service_role
  (id::text = auth.uid()::text AND role IS NOT DISTINCT FROM (SELECT role FROM public.users WHERE id::text = auth.uid()::text))
);

-- ------------------------------------------------------------------------------
-- 3. STADIUMS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.stadiums ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stadiums_select_policy" ON public.stadiums;
CREATE POLICY "stadiums_select_policy" ON public.stadiums
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "stadiums_manage_policy" ON public.stadiums;
CREATE POLICY "stadiums_manage_policy" ON public.stadiums
FOR ALL TO authenticated
USING (auth.uid()::text = owner_id::text);

-- ------------------------------------------------------------------------------
-- 4. TEAMS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teams_select_policy" ON public.teams;
CREATE POLICY "teams_select_policy" ON public.teams
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "teams_manage_policy" ON public.teams;
CREATE POLICY "teams_manage_policy" ON public.teams
FOR ALL TO authenticated
USING (auth.uid()::text = captain_id::text);

-- ------------------------------------------------------------------------------
-- 5. TEAM MEMBERS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_members_select_policy" ON public.team_members;
CREATE POLICY "team_members_select_policy" ON public.team_members
FOR SELECT TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "team_members_manage_policy" ON public.team_members;
CREATE POLICY "team_members_manage_policy" ON public.team_members
FOR ALL TO authenticated
USING (
  auth.uid()::text = user_id::text
  OR EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_members.team_id AND t.captain_id::text = auth.uid()::text
  )
);

-- ------------------------------------------------------------------------------
-- 6. CHAMPIONSHIPS & CHAMPIONSHIP ROSTERS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.championships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "championships_select_policy" ON public.championships;
CREATE POLICY "championships_select_policy" ON public.championships
FOR SELECT TO authenticated, anon
USING (is_approved = true OR auth.uid()::text = owner_id::text);

DROP POLICY IF EXISTS "championships_manage_policy" ON public.championships;
CREATE POLICY "championships_manage_policy" ON public.championships
FOR ALL TO authenticated
USING (auth.uid()::text = owner_id::text);

ALTER TABLE IF EXISTS public.championship_rosters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "championship_rosters_select" ON public.championship_rosters;
CREATE POLICY "championship_rosters_select" ON public.championship_rosters
FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "championship_rosters_manage" ON public.championship_rosters;
CREATE POLICY "championship_rosters_manage" ON public.championship_rosters
FOR ALL TO authenticated
USING (
  auth.uid()::text = captain_id::text
  OR EXISTS (
    SELECT 1 FROM public.championships c 
    WHERE c.id = championship_rosters.championship_id AND c.owner_id::text = auth.uid()::text
  )
);

-- ------------------------------------------------------------------------------
-- 7. TOURNAMENT MATCHES
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.tournament_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tournament_matches_select" ON public.tournament_matches;
CREATE POLICY "tournament_matches_select" ON public.tournament_matches
FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "tournament_matches_update" ON public.tournament_matches;
CREATE POLICY "tournament_matches_update" ON public.tournament_matches
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.championships c 
    WHERE c.id = tournament_matches.championship_id AND c.owner_id::text = auth.uid()::text
  )
  OR EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE (t.id = tournament_matches.home_team_id OR t.id = tournament_matches.away_team_id)
      AND t.captain_id::text = auth.uid()::text
  )
);

-- ------------------------------------------------------------------------------
-- 8. REVIEWS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews_select_policy" ON public.reviews;
CREATE POLICY "reviews_select_policy" ON public.reviews
FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "reviews_insert_policy" ON public.reviews;
CREATE POLICY "reviews_insert_policy" ON public.reviews
FOR INSERT TO authenticated WITH CHECK (auth.uid()::text = user_id::text);

-- ------------------------------------------------------------------------------
-- 9. NOTIFICATIONS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications
FOR SELECT TO authenticated USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications
FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications
FOR UPDATE TO authenticated USING (auth.uid()::text = user_id::text);

-- ------------------------------------------------------------------------------
-- 10. CHAT MESSAGES
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_select" ON public.chat_messages;
CREATE POLICY "chat_select" ON public.chat_messages
FOR SELECT TO authenticated
USING (auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text);

DROP POLICY IF EXISTS "chat_insert" ON public.chat_messages;
CREATE POLICY "chat_insert" ON public.chat_messages
FOR INSERT TO authenticated WITH CHECK (auth.uid()::text = sender_id::text);

-- ------------------------------------------------------------------------------
-- 11. REPORTS (Reporter + Admin access only)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reports_select" ON public.reports;
CREATE POLICY "reports_select" ON public.reports
FOR SELECT TO authenticated
USING (auth.uid()::text = reporter_id::text);

DROP POLICY IF EXISTS "reports_insert" ON public.reports;
CREATE POLICY "reports_insert" ON public.reports
FOR INSERT TO authenticated WITH CHECK (auth.uid()::text = reporter_id::text);

-- ------------------------------------------------------------------------------
-- 12. APP SETTINGS & APP CONFIG (Admin only)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_read" ON public.app_settings;
CREATE POLICY "app_settings_read" ON public.app_settings FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "app_config_read" ON public.app_config;
CREATE POLICY "app_config_read" ON public.app_config FOR SELECT TO authenticated, anon USING (true);

-- ------------------------------------------------------------------------------
-- 13. PROMOTIONS, 1v1 PLAYERS & REGISTRATIONS
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vsp_1vs1_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vsp_1v1_registrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "promotions_read" ON public.promotions;
CREATE POLICY "promotions_read" ON public.promotions FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "vsp_1vs1_read" ON public.vsp_1vs1_players;
CREATE POLICY "vsp_1vs1_read" ON public.vsp_1vs1_players FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "vsp_1v1_reg_select" ON public.vsp_1v1_registrations;
CREATE POLICY "vsp_1v1_reg_select" ON public.vsp_1v1_registrations FOR SELECT TO authenticated USING (auth.uid()::text = user_id::text);

DROP POLICY IF EXISTS "vsp_1v1_reg_insert" ON public.vsp_1v1_registrations;
CREATE POLICY "vsp_1v1_reg_insert" ON public.vsp_1v1_registrations FOR INSERT TO authenticated WITH CHECK (auth.uid()::text = user_id::text);
