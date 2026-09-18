-- ==============================================================================
-- 🧹 VSP PRODUCTION DATABASE RESET SCRIPT (ZERO-TEST-DATA LAUNCH PREP)
-- Self-Healing & Dynamic: checks table existence before TRUNCATE
-- Preserves Admin Accounts: CEO (mohamedsalh333555@gmail.com) & COO (hana.ramadan@vsp.com)
-- ==============================================================================

BEGIN;

-- 1. تفريغ ديناميكي ذاتي الإصلاح لجميع جداول الحركات والعمليات والتجارب (مع تصفير العدادات)
DO $$
DECLARE
    tbl text;
    tbls text[] := ARRAY[
        -- Financial & Ledger
        'transactions', 
        'payout_settlements', 
        'financial_audit_logs', 
        'system_audit_logs', 
        'points_ledger', 
        'tournament_orders', 
        'vsp_1v1_tournament_orders', 
        'rate_limit_logs',
        -- Bookings & Radar Matchups
        'bookings', 
        'matchups', 
        'matchup_teams', 
        'matchup_results', 
        'team_head_to_head',
        -- Tournaments, Leagues & Championships
        'championships', 
        'vsp_1v1_tournaments', 
        'tournament_teams', 
        'tournament_matches', 
        'tournament_brackets', 
        'league_1v1_players', 
        'league_1v1_matches',
        -- Stadiums & Configurations
        'stadiums', 
        'stadium_pricing', 
        'stadium_operating_hours', 
        'stadium_photos',
        -- Communications, Copilot, Reviews & Reports
        'copilot_messages', 
        'copilot_conversations', 
        'notifications', 
        'reviews', 
        'reports', 
        'referrals'
    ];
BEGIN
    FOREACH tbl IN ARRAY tbls
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE;', tbl);
        END IF;
    END LOOP;
END $$;

-- 2. التصفية الدقيقة لجدول المستخدمين مع حماية واستثناء حسابات الـ CEO والـ COO
-- أ) حذف جميع مستخدمي المصادقة التجريبيين من auth.users باستثناء الإدارة
DELETE FROM auth.users 
WHERE email NOT IN (
    'mohamedsalh333555@gmail.com', 
    'hana.ramadan@vsp.com'
);

-- ب) حذف جميع البروفايلات التجريبية من public.users باستثناء الإدارة
DELETE FROM public.users 
WHERE email NOT IN (
    'mohamedsalh333555@gmail.com', 
    'hana.ramadan@vsp.com'
);

-- ج) تثبيت وتأكيد صلاحيات الأدمن النقية لحسابات القيادة
UPDATE public.users 
SET 
    role = 'admin',
    verification_status = 'approved',
    is_blocked = false,
    updated_at = timezone('utc'::text, now())
WHERE email IN (
    'mohamedsalh333555@gmail.com', 
    'hana.ramadan@vsp.com'
);

-- 3. تنظيف ملفات التخزين (Storage) يتم من تبويب Storage بلوحة سوبابيز مباشرة
-- نظراً لوجود حماية أوتوماتيكية من سوبابيز تمنع الـ DELETE المباشر بـ SQL.

COMMIT;
