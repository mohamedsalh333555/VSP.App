-- ==============================================================================
-- 🧹 VSP SPORTS PLATFORM — COMPLETE DATABASE WIPE & FRESH RESET SCRIPT
-- ==============================================================================
-- ⚠️ تحذير: تشغيل هذا السكريبت في Supabase سيقوم بحذف كافة البيانات التجريبية،
-- حسابات المستخدمين، الملاعب، الحجوزات، الفرق، البطولات، والرسائل نهائياً
-- ليصبح التطبيق جديداً كلياً وشاغراً لبيانات الإنتاج الحقيقية.

-- 1. تفريغ كافة الجداول الحالية مع التبعات (CASCADE)
TRUNCATE TABLE 
    public.notifications,
    public.chat_messages,
    public.reviews,
    public.reports,
    public.webhook_logs,
    public.tournament_matches,
    public.championships,
    public.bookings,
    public.team_members,
    public.teams,
    public.stadiums,
    public.users
CASCADE;

-- 2. حذف مستخدمي المصادقة (Auth Users) لغسل الجلسات كلياً
DELETE FROM auth.users;

-- 3. تأكيد النجاح
SELECT '✅ تم تنظيف ومسح قاعدة البيانات بالكامل والتطبيق الآن جديد كلياً 100%!' AS status;
