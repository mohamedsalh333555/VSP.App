-- =========================================================================
-- PERF-02: OPTIMIZING DATABASE QUERY PERFORMANCE WITH INDEXES
-- تسريع استعلامات قاعدة البيانات ومنع عنق الزجاجة (Bottlenecks)
-- =========================================================================

-- تسريع استعلامات جدول الحجوزات (الأكثر استخداماً في التطبيق)
CREATE INDEX IF NOT EXISTS idx_bookings_stadium_id ON bookings(stadium_id);
CREATE INDEX IF NOT EXISTS idx_bookings_owner_id ON bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status_paid ON bookings(status, is_paid);
CREATE INDEX IF NOT EXISTS idx_bookings_start_time ON bookings(start_time);

-- تسريع فلاتر البحث وعرض الملاعب
CREATE INDEX IF NOT EXISTS idx_stadiums_owner_id ON stadiums(owner_id);
CREATE INDEX IF NOT EXISTS idx_stadiums_gov_verified ON stadiums(governorate, is_verified, is_blocked);

-- تسريع مباريات البطولات والرسائل
CREATE INDEX IF NOT EXISTS idx_tourn_matches_champ_id ON tournament_matches(championship_id);
CREATE INDEX IF NOT EXISTS idx_chat_msgs_booking_id ON chat_messages(booking_id);

-- تسريع الإشعارات
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_unread ON notifications(user_id) WHERE is_read = false;
