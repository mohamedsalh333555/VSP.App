-- ============================================================
-- VSP Application - Supabase Complete Fix Migration (Robust Type Casting)
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- STEP 1: FIX NOTIFICATIONS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Allow authenticated insert notifications" ON public.notifications;

-- READ: Each user sees only their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.notifications FOR SELECT
USING (auth.uid()::text = user_id::text);

-- INSERT: Any authenticated user can send a notification
CREATE POLICY "Allow authenticated insert notifications"
ON public.notifications FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- UPDATE: Users can update (mark as read) their own notifications
CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE
USING (auth.uid()::text = user_id::text);

-- DELETE: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
ON public.notifications FOR DELETE
USING (auth.uid()::text = user_id::text);


-- ─────────────────────────────────────────────────────────────
-- STEP 2: FIX USERS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Authenticated can view basic profiles" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can view basic profiles" ON public.users;

-- Users can view their own full profile
CREATE POLICY "Users can view their own profile"
ON public.users FOR SELECT
USING (auth.uid()::text = id::text);

-- Authenticated users can view basic info of other users
CREATE POLICY "Authenticated can view basic profiles"
ON public.users FOR SELECT
USING (auth.role() = 'authenticated');

-- Users can insert their own profile (on signup)
CREATE POLICY "Users can insert their own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid()::text = id::text);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON public.users FOR UPDATE
USING (auth.uid()::text = id::text);


-- ─────────────────────────────────────────────────────────────
-- STEP 3: FIX STADIUMS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.stadiums ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view verified stadiums" ON public.stadiums;
DROP POLICY IF EXISTS "Owner can manage own stadiums" ON public.stadiums;

-- Players see verified, non-blocked stadiums
CREATE POLICY "Anyone can view verified stadiums"
ON public.stadiums FOR SELECT
USING (
  (is_verified = true AND (is_blocked IS FALSE OR is_blocked IS NULL))
  OR auth.uid()::text = owner_id::text
);

-- Owners can manage their own stadiums
CREATE POLICY "Owner can manage own stadiums"
ON public.stadiums FOR ALL
USING (auth.uid()::text = owner_id::text)
WITH CHECK (auth.uid()::text = owner_id::text);


-- ─────────────────────────────────────────────────────────────
-- STEP 4: FIX TEAMS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view teams" ON public.teams;
DROP POLICY IF EXISTS "Captain can manage their team" ON public.teams;

CREATE POLICY "Anyone can view teams"
ON public.teams FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Captain can manage their team"
ON public.teams FOR ALL
USING (auth.uid()::text = captain_id::text)
WITH CHECK (auth.uid()::text = captain_id::text);


-- ─────────────────────────────────────────────────────────────
-- STEP 5: FIX TEAM_MEMBERS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view team members" ON public.team_members;
DROP POLICY IF EXISTS "Authenticated can add team members" ON public.team_members;
DROP POLICY IF EXISTS "Members can leave team" ON public.team_members;

CREATE POLICY "Anyone can view team members"
ON public.team_members FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated can add team members"
ON public.team_members FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Members can leave team"
ON public.team_members FOR DELETE
USING (auth.uid()::text = user_id::text OR auth.role() = 'authenticated');


-- ─────────────────────────────────────────────────────────────
-- STEP 6: FIX BOOKINGS TABLE
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner can manage own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Player can view public matches" ON public.bookings;
DROP POLICY IF EXISTS "Player can create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Player can update joined bookings" ON public.bookings;

CREATE POLICY "Owner can manage own bookings"
ON public.bookings FOR ALL
USING (auth.uid()::text = owner_id::text);

CREATE POLICY "Player can view public matches"
ON public.bookings FOR SELECT
USING (auth.role() = 'authenticated');

CREATE POLICY "Player can create bookings"
ON public.bookings FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Player can update joined bookings"
ON public.bookings FOR UPDATE
USING (auth.role() = 'authenticated');


-- ─────────────────────────────────────────────────────────────
-- VERIFY FIXES
-- ─────────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd as operation
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
