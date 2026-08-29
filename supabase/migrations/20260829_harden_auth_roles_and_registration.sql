-- ==============================================================================
-- 🔒 VSP PLATFORM — AUTH & USER ROLE ESCALATION HARDENING PATCH
-- Description: 1. Closes self-promotion to admin/co_founder in handle_new_user.
--              2. Eliminates IDOR in complete_user_registration & set_user_role_on_signup.
--              3. Hardens protect_user_sensitive_fields trigger with auth.role().
-- Date: 2026-08-29
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1️⃣ تحصين تريغر التسجيل (handle_new_user): قصر الرتب على player أو owner فقط
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_name text;
  v_avatar text;
  v_phone text;
  v_governorate text;
  v_dob timestamptz;
  v_position text;
  v_is_complete boolean;
BEGIN
  -- 🔒 قصر الرتب المسموح بطلبها على player أو owner فقط (منع تصعيد الأدمن نهائياً)
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'player');
  IF v_role NOT IN ('player', 'owner') THEN
    v_role := 'player';
  END IF;

  -- 2. استخراج الاسم
  v_name := COALESCE(
    NULLIF(new.raw_user_meta_data->>'full_name', ''),
    NULLIF(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1)
  );

  -- 3. استخراج صورة الحساب
  v_avatar := COALESCE(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    NULL
  );

  -- 4. استخراج رقم الهاتف والمحافظة وتاريخ الميلاد
  v_phone := COALESCE(
    NULLIF(new.raw_user_meta_data->>'phone', ''),
    NULLIF(new.phone, '')
  );

  v_governorate := COALESCE(
    NULLIF(new.raw_user_meta_data->>'governorate', ''),
    'Cairo'
  );

  v_position := COALESCE(
    NULLIF(new.raw_user_meta_data->>'position', ''),
    'GK'
  );

  BEGIN
    v_dob := (new.raw_user_meta_data->>'date_of_birth')::timestamptz;
  EXCEPTION WHEN OTHERS THEN
    v_dob := NULL;
  END;

  IF v_phone IS NOT NULL AND length(regexp_replace(v_phone, '\D', '', 'g')) >= 9 THEN
    v_is_complete := TRUE;
  ELSE
    v_is_complete := FALSE;
  END IF;

  -- 5. إدراج أو تحديث المستخدم في public.users
  INSERT INTO public.users (
    id,
    email,
    name,
    role,
    phone,
    governorate,
    position,
    date_of_birth,
    profile_image_url,
    is_email_verified,
    is_registration_complete,
    created_at,
    updated_at
  ) VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_name,
    v_role,
    v_phone,
    v_governorate,
    v_position,
    v_dob,
    v_avatar,
    TRUE,
    v_is_complete,
    timezone('utc'::text, now()),
    timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    email = EXCLUDED.email,
    name = COALESCE(NULLIF(public.users.name, ''), EXCLUDED.name),
    role = COALESCE(NULLIF(public.users.role, ''), EXCLUDED.role),
    phone = COALESCE(NULLIF(public.users.phone, ''), EXCLUDED.phone),
    governorate = COALESCE(NULLIF(public.users.governorate, ''), EXCLUDED.governorate),
    position = COALESCE(NULLIF(public.users.position, ''), EXCLUDED.position),
    date_of_birth = COALESCE(public.users.date_of_birth, EXCLUDED.date_of_birth),
    profile_image_url = COALESCE(public.users.profile_image_url, EXCLUDED.profile_image_url),
    is_email_verified = TRUE,
    is_registration_complete = CASE 
      WHEN public.users.is_registration_complete = TRUE THEN TRUE 
      ELSE EXCLUDED.is_registration_complete 
    END,
    updated_at = timezone('utc'::text, now());

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    RETURN new;
END;
$function$;


-- ------------------------------------------------------------------------------
-- 2️⃣ تحصين دالة إكمال التسجيل (complete_user_registration): منع الـ IDOR
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
    v_caller_role TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User ID required');
    END IF;

    -- 🔒 منع الـ IDOR: المستخدم يمكنه فقط استكمال حسابه الشخصي أو الأدمن أو service_role
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        IF (v_uid IS DISTINCT FROM auth.uid()) THEN
            SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
            IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
                RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: You can only complete registration for your own account');
            END IF;
        END IF;
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

GRANT EXECUTE ON FUNCTION public.complete_user_registration(UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 3️⃣ تحصين دالة تعيين الرتبة عند التسجيل (set_user_role_on_signup)
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
  v_caller_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- 🔒 قصر الرتب المتاحة على player أو owner فقط
  IF p_role NOT IN ('player', 'owner') THEN
    RAISE EXCEPTION 'Invalid role assignment attempt (%s). Only player or owner allowed.', p_role;
  END IF;

  -- 🔒 منع الـ IDOR: المستخدم يمكنه تغيير رتبة حسابه فقط
  IF (COALESCE(auth.role(), '') != 'service_role') THEN
    IF (v_uid IS DISTINCT FROM auth.uid()) THEN
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
        RAISE EXCEPTION 'Unauthorized: You can only set your own role.';
      END IF;
    END IF;
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

GRANT EXECUTE ON FUNCTION public.set_user_role_on_signup(TEXT, UUID) TO authenticated, service_role;


-- ------------------------------------------------------------------------------
-- 4️⃣ تحصين تريغر حماية الحقول الحساسة (protect_user_sensitive_fields)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role text;
  v_caller_uid uuid := auth.uid();
BEGIN
  -- إعفاء الـ service_role من القيود
  IF (COALESCE(auth.role(), '') = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- التحقق من صلاحيات الأدمن أو الشريك المؤسس
  IF v_caller_uid IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_uid;
    IF COALESCE(v_caller_role, '') IN ('admin', 'co_founder') THEN
      RETURN NEW;
    END IF;
  END IF;

  -- حماية الرتب والحقول الحساسة من أي تعديل مباشر من المستخدم العادي
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Security Alert: Modifying user role directly is prohibited.';
  END IF;

  IF NEW.is_blocked IS DISTINCT FROM OLD.is_blocked THEN
    RAISE EXCEPTION 'Security Alert: Modifying is_blocked status directly is prohibited.';
  END IF;

  IF NEW.is_identity_verified IS DISTINCT FROM OLD.is_identity_verified AND NEW.is_identity_verified = true THEN
    RAISE EXCEPTION 'Security Alert: Self-verifying identity is prohibited.';
  END IF;

  IF NEW.verification_status IS DISTINCT FROM OLD.verification_status AND NEW.verification_status IN ('approved', 'verified') THEN
    RAISE EXCEPTION 'Security Alert: Self-approving verification status is prohibited.';
  END IF;

  IF NEW.cash_booking_banned IS DISTINCT FROM OLD.cash_booking_banned THEN
    RAISE EXCEPTION 'Security Alert: Modifying cash_booking_banned status is prohibited.';
  END IF;

  IF NEW.no_show_count IS DISTINCT FROM OLD.no_show_count THEN
    RAISE EXCEPTION 'Security Alert: Modifying no_show_count directly is prohibited.';
  END IF;

  IF NEW.subscription_plan IS DISTINCT FROM OLD.subscription_plan THEN
    RAISE EXCEPTION 'Security Alert: Modifying subscription_plan directly is prohibited.';
  END IF;

  IF NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at THEN
    RAISE EXCEPTION 'Security Alert: Modifying trial_ends_at directly is prohibited.';
  END IF;

  IF NEW.subscription_expires_at IS DISTINCT FROM OLD.subscription_expires_at THEN
    RAISE EXCEPTION 'Security Alert: Modifying subscription_expires_at directly is prohibited.';
  END IF;

  IF NEW.total_platform_fees IS DISTINCT FROM OLD.total_platform_fees THEN
    RAISE EXCEPTION 'Security Alert: Modifying total_platform_fees directly is prohibited.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.protect_user_sensitive_fields();

COMMIT;
