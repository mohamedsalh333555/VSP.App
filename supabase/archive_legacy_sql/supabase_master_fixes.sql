-- ============================================================================
-- 🏆 VSP APPLICATION - MASTER SUPABASE SQL FIXES (حزمة الإصلاحات الشاملة المحدثة)
-- ============================================================================
-- ينفذ هذا السكريبت في Supabase SQL Editor لمعالجة كافة الثغرات والقيود والدوال السحابية.

-- ----------------------------------------------------------------------------
-- 1️⃣ أولاً: حماية جدول إعدادات التطبيق (app_settings)
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_manage" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_admin_manage" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_public_read" ON public.app_settings;

-- القراءة متاحة لجميع المستخدمين المسجلين
CREATE POLICY "app_settings_public_read" ON public.app_settings
FOR SELECT TO authenticated USING (true);

-- التعديل والإدارة محصورة بالأدمن والـ Co-Founder فقط
CREATE POLICY "app_settings_admin_manage" ON public.app_settings
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )
);

-- ----------------------------------------------------------------------------
-- 2️⃣ ثانياً: حماية بيانات المستخدمين ومنع منح شارة التوثيق الذاتية
-- ----------------------------------------------------------------------------
-- التأكد من وجود عمود التوثيق is_identity_verified
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS is_identity_verified BOOLEAN DEFAULT false;
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_public" ON public.users;
DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

-- 🔒 سد ثغرة سحب بيانات جميع المستخدمين
CREATE POLICY "users_select_authenticated" ON public.users
FOR SELECT TO authenticated
USING (
  (auth.uid() = id) OR 
  (EXISTS (
    SELECT 1 FROM public.users u 
    WHERE u.id = auth.uid() 
      AND u.role IN ('admin', 'co_founder')
  )) OR
  (is_blocked = false)
);

-- 🔒 سد ثغرة التوثيق الذاتي (منع المستخدم من تغيير is_identity_verified بنفسه)
CREATE POLICY "users_update_own" ON public.users
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id AND (
    is_identity_verified = (SELECT COALESCE(u.is_identity_verified, false) FROM public.users u WHERE u.id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'co_founder'))
  )
);

-- ----------------------------------------------------------------------------
-- 3️⃣ ثالثاً: تأمين مستندات التوثيق والإيصالات (Storage RLS)
-- ----------------------------------------------------------------------------
UPDATE storage.buckets
SET public = false
WHERE id IN ('owner_documents', 'verification-documents', 'deposit-receipts');

DROP POLICY IF EXISTS "secure_owner_docs_read" ON storage.objects;
DROP POLICY IF EXISTS "secure_deposit_receipts_read" ON storage.objects;
DROP POLICY IF EXISTS "public_images_read" ON storage.objects;

CREATE POLICY "secure_owner_docs_read" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'owner_documents' AND (
    (auth.uid())::text = (storage.foldername(name))[1] OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder'))
  )
);

CREATE POLICY "secure_deposit_receipts_read" ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'deposit-receipts' AND (
    (auth.uid())::text = (storage.foldername(name))[1] OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder'))
  )
);

CREATE POLICY "public_images_read" ON storage.objects
FOR SELECT TO public
USING (bucket_id IN ('stadium-images', 'profile-pictures'));

-- ----------------------------------------------------------------------------
-- 4️⃣ رابعاً: منع تزوير أسعار الحجز وإضافة قيد الحماية المالية
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.bookings 
DROP CONSTRAINT IF EXISTS check_positive_price;

ALTER TABLE IF EXISTS public.bookings 
ADD CONSTRAINT check_positive_price CHECK (total_price >= 0 AND deposit_paid >= 0);

-- ----------------------------------------------------------------------------
-- 5️⃣ خامساً: إصلاح دالة الترتيب لضمان إظهار الفرق الجديدة (get_championship_standings)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_championship_standings(p_championship_id UUID)
RETURNS TABLE (
  team_id UUID,
  team_name TEXT,
  logo_url TEXT,
  matches_played INT,
  wins INT,
  draws INT,
  losses INT,
  goals_for INT,
  goals_against INT,
  goal_difference INT,
  points INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id AS team_id,
    t.name AS team_name,
    t.logo_url AS logo_url,
    COALESCE(s.matches_played, 0) AS matches_played,
    COALESCE(s.wins, 0) AS wins,
    COALESCE(s.draws, 0) AS draws,
    COALESCE(s.losses, 0) AS losses,
    COALESCE(s.goals_for, 0) AS goals_for,
    COALESCE(s.goals_against, 0) AS goals_against,
    COALESCE(s.goal_difference, 0) AS goal_difference,
    COALESCE(s.points, 0) AS points
  FROM public.tournament_teams tt
  JOIN public.teams t ON tt.team_id = t.id
  LEFT JOIN public.championship_standings s 
    ON s.championship_id = p_championship_id AND s.team_id = t.id
  WHERE tt.championship_id = p_championship_id
  ORDER BY 
    COALESCE(s.points, 0) DESC, 
    COALESCE(s.goal_difference, 0) DESC, 
    COALESCE(s.goals_for, 0) DESC, 
    t.name ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ✅ انتهى سكريبت القاعدة المعالِج بكفاءة عالية.
-- ============================================================================
