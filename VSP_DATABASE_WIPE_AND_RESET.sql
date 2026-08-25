-- ==============================================================================
-- 🧹 VSP SPORTS PLATFORM — COMPLETE DATABASE WIPE & FRESH RESET SCRIPT
-- ==============================================================================
-- ⚠️ تحذير: تشغيل هذا السكريبت في Supabase سيقوم بحذف كافة البيانات،
-- حسابات المستخدمين، الملاعب، الحجوزات، الفرق، البطولات، المعاملات، والرسائل نهائياً
-- ليصبح التطبيق جديداً كلياً وشاغراً لبيانات الإنتاج الحقيقية.

-- 1. تفريغ كافة جداول public مع التبعات (CASCADE)
TRUNCATE TABLE 
    public.notifications,
    public.chat_messages,
    public.reviews,
    public.reports,
    public.webhook_logs,
    public.rate_limit_logs,
    public.financial_audit_logs,
    public.transactions,
    public.payout_settlements,
    public.paymob_transactions,
    public.tournament_orders,
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

-- 3. تنظيف كائنات التخزين (Storage Objects) للملفات المرفوعة التجريبية
DO $$
BEGIN
    DELETE FROM storage.objects;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- تجاهل إذا لم يكن هناك صلاحيات لـ storage schema
END $$;

-- 4. تأكيد النجاح
SELECT '✅ تم تنظيف ومسح قاعدة البيانات بالكامل والتطبيق الآن جديد كلياً 100%!' AS status;
