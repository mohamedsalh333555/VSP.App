-- ==============================================================================
-- ⚡ VSP PLATFORM — LIVE MATCH RADAR PERFORMANCE PATCH (SUPABASE SQL EDITOR)
-- Description: Indexes to accelerate Live Match Radar countdown queries on bookings
-- Date: 2026-08-23
-- ==============================================================================

-- 1️⃣ فهرس مركب لتسريع جلب مباريات اليوم القادمة والجارية للمستخدم
CREATE INDEX IF NOT EXISTS idx_bookings_user_live_radar 
ON public.bookings (user_id, start_time, end_time, status) 
WHERE status != 'cancelled';

-- 2️⃣ فهرس GIN للبحث السريع في المباريات التي انضم إليها اللاعب كعضو
CREATE INDEX IF NOT EXISTS idx_bookings_joined_live_radar 
ON public.bookings USING gin (joined_user_ids) 
WHERE status != 'cancelled';
