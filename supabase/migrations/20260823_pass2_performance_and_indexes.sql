-- ============================================================================
-- ⚡ VSP PRODUCTION PERFORMANCE & SCALABILITY MIGRATION (PASS 2 - CATEGORY 5)
-- File: supabase/migrations/20260823_pass2_performance_and_indexes.sql
-- ============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ إزالة الفهارس المكررة لتوفير مساحة القرص وتسريع الـ INSERT / UPDATE (Drop Duplicate Indexes)
-- ------------------------------------------------------------------------------

-- A. Bookings Table
DROP INDEX IF EXISTS idx_bookings_joined_user_ids;
DROP INDEX IF EXISTS idx_bookings_owner_op_date;
DROP INDEX IF EXISTS idx_bookings_stadium_start;

-- B. Championship Rosters Table
DROP INDEX IF EXISTS idx_championship_rosters_champ_team;

-- C. Chat Messages Table
DROP INDEX IF EXISTS idx_chat_messages_conv_created;

-- D. Conversations Table
DROP INDEX IF EXISTS idx_conversations_participants;

-- E. Stadiums Table
DROP INDEX IF EXISTS idx_stadiums_governorate_verified;
DROP INDEX IF EXISTS idx_stadiums_owner_id;

-- F. Team Members Table (مفهرس بالفعل عبر Primary Key)
DROP INDEX IF EXISTS idx_team_members_user_team;

-- G. Tournament Matches Table
DROP INDEX IF EXISTS idx_tournament_matches_champ_round;

-- H. Users Table (مفهرس بالفعل عبر Unique Index)
DROP INDEX IF EXISTS idx_users_phone;


-- ------------------------------------------------------------------------------
-- 2️⃣ إنشاء الفهارس الاستراتيجية على المفاتيح الأجنبية والاستعلامات الحيوية (Missing Strategic Indexes)
-- ------------------------------------------------------------------------------

-- A. جداول الحجوزات والمباريات (Bookings Table Indexes)
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_created_by_user_id ON public.bookings(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_player_team_id ON public.bookings(player_team_id) WHERE player_team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_opponent_team_id ON public.bookings(opponent_team_id) WHERE opponent_team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_status_start_time ON public.bookings(status, start_time);

-- B. جدول الإشعارات (Notifications Table Compound Index for fast badge counts)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications(user_id, created_at DESC);

-- C. جدول التقييمات والمراجعات (Reviews Table Indexes)
CREATE INDEX IF NOT EXISTS idx_reviews_stadium_id ON public.reviews(stadium_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON public.reviews(user_id);

-- D. جدول المعاملات المالية (Transactions Table Indexes)
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_booking_id ON public.transactions(booking_id) WHERE booking_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_championship_id ON public.transactions(championship_id) WHERE championship_id IS NOT NULL;

-- E. جدول مباريات البطولات (Tournament Matches Indexes)
CREATE INDEX IF NOT EXISTS idx_tournament_matches_winner_id ON public.tournament_matches(winner_id) WHERE winner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_matches_home_team_id ON public.tournament_matches(home_team_id) WHERE home_team_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tournament_matches_away_team_id ON public.tournament_matches(away_team_id) WHERE away_team_id IS NOT NULL;

-- F. جدول البلاغات والتقارير (Reports Table Index)
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
