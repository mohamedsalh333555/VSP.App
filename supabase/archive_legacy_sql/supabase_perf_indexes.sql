-- ============================================================================
-- ⚡ VSP PERFORMANCE & SCALABILITY MIGRATION (CATEGORY 2)
-- ============================================================================

-- 1. إضافة فهارس GIN لتسريع البحث داخل المصفوفات (Array Queries Optimization)
CREATE INDEX IF NOT EXISTS idx_bookings_joined_users_gin 
ON public.bookings USING gin (joined_user_ids);

CREATE INDEX IF NOT EXISTS idx_conversations_participants_gin 
ON public.conversations USING gin (participant_ids);

CREATE INDEX IF NOT EXISTS idx_championships_joined_teams_gin 
ON public.championships USING gin (joined_teams);

-- 2. إضافة فهارس B-Tree المركبة لتسريع استعلامات الحجوزات والملاعب
CREATE INDEX IF NOT EXISTS idx_bookings_user_lookup 
ON public.bookings (created_by_user_id, status, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_bookings_owner_operational 
ON public.bookings (owner_id, operational_date, start_time DESC);

CREATE INDEX IF NOT EXISTS idx_stadiums_public_filter 
ON public.stadiums (is_verified, is_blocked, is_deleted_by_owner, governorate);

CREATE INDEX IF NOT EXISTS idx_tournament_matches_champ_round 
ON public.tournament_matches (championship_id, round_index, match_index);

-- 3. تنظيف الفهارس المكررة (Drop Duplicate Indexes)
DROP INDEX IF EXISTS public.idx_vsp_1v1_unique_user;
