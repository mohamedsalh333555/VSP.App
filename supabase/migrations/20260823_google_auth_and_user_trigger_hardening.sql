-- ==============================================================================
-- 🚀 VSP PLATFORM — GOOGLE AUTH & USER REGISTRATION PATCH (SUPABASE SQL EDITOR)
-- Description: Automated User Profile Creation on Google OAuth Signup, 
--              Registration Completion RPC, and Role Assignment Hardening.
-- Date: 2026-08-23
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1️⃣ تفعيل سياسة إدراج المستخدمين في public.users (RLS Insert Policy)
-- ------------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_insert_policy" ON public.users;
CREATE POLICY "users_insert_policy" ON public.users
FOR INSERT TO authenticated, service_role
WITH CHECK (auth.uid() = id OR auth.role() = 'service_role');


-- ------------------------------------------------------------------------------
-- 2️⃣ تريجر إنشاء سجل المستخدم التلقائي فور التسجيل عبر Google (handle_new_user)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_role text;
  v_name text;
  v_avatar text;
BEGIN
  -- 1. استخراج الدور المطلوب (player أو owner)
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'player');
  IF v_role NOT IN ('player', 'owner') THEN
    v_role := 'player';
  END IF;

  -- 2. استخراج الاسم الكامل من حساب جوجل
  v_name := COALESCE(
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'name',
    split_part(new.email, '@', 1)
  );

  -- 3. استخراج الصورة الشخصية من جوجل
  v_avatar := COALESCE(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    NULL
  );

  -- 4. إدراج أو تحديث السجل في جدول public.users
  INSERT INTO public.users (
    id,
    email,
    name,
    role,
    profile_image_url,
    is_email_verified,
    is_registration_complete,
    fair_play_score,
    points,
    subscription_plan,
    created_at,
    updated_at
  ) VALUES (
    new.id,
    new.email,
    v_name,
    v_role,
    v_avatar,
    TRUE, -- إيميل جوجل موثق تلقائياً
    FALSE, -- ينتظر إدخال الهاتف والبيانات في شاشة Onboarding
    100,
    0,
    CASE WHEN v_role = 'owner' THEN 'free_trial' ELSE NULL END,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.users.name, ''), EXCLUDED.name),
    profile_image_url = COALESCE(public.users.profile_image_url, EXCLUDED.profile_image_url),
    is_email_verified = TRUE,
    updated_at = timezone('utc'::text, now());

  RETURN new;
END;
$$;

-- ربط التريجر مع جدول auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ------------------------------------------------------------------------------
-- 3️⃣ دالة إكمال تسجيل الحساب الاجتماعي (complete_user_registration RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_user_registration(
    p_user_id UUID,
    p_phone TEXT,
    p_name TEXT DEFAULT NULL,
    p_position TEXT DEFAULT NULL,
    p_governorate TEXT DEFAULT 'Cairo',
    p_date_of_birth TIMESTAMPTZ DEFAULT NULL,
    p_p2p_instapay TEXT DEFAULT NULL,
    p_p2p_vodafone TEXT DEFAULT NULL,
    p_p2p_bank TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.uid());
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User ID required');
    END IF;

    -- التحقق من عدم تكرار رقم الهاتف مع مستخدم آخر
    IF p_phone IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE phone = p_phone AND id != v_uid
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Phone number already in use');
    END IF;

    UPDATE public.users
    SET 
        phone = COALESCE(p_phone, phone),
        name = COALESCE(NULLIF(p_name, ''), name),
        position = COALESCE(p_position, position, 'ST'),
        governorate = COALESCE(p_governorate, governorate, 'Cairo'),
        date_of_birth = COALESCE(p_date_of_birth, date_of_birth),
        p2p_instapay = COALESCE(p_p2p_instapay, p2p_instapay),
        p2p_vodafone = COALESCE(p_p2p_vodafone, p2p_vodafone),
        p2p_bank = COALESCE(p_p2p_bank, p2p_bank),
        is_registration_complete = true,
        is_email_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration completed successfully'
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4️⃣ دالة تعيين رتبة المستخدم عند التسجيل (set_user_role_on_signup RPC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(
    p_role text,
    p_user_id uuid DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := COALESCE(p_user_id, auth.uid());
  v_current_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  SELECT role INTO v_current_role FROM public.users WHERE id = v_uid;

  -- منع المساس برتب الأدمن ومؤسسي المنصة
  IF v_current_role IN ('admin', 'co_founder') THEN
    RETURN true;
  END IF;

  UPDATE public.users
  SET role = p_role, updated_at = timezone('utc'::text, now())
  WHERE id = v_uid;

  RETURN true;
END;
$$;


-- ------------------------------------------------------------------------------
-- 5️⃣ منح الصلاحيات للأدوار المعتمدة (Grant Permissions)
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.complete_user_registration(UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.set_user_role_on_signup(TEXT, UUID) TO authenticated, service_role;
