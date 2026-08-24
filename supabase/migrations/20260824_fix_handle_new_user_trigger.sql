-- Migration: 20260824_fix_handle_new_user_trigger.sql
-- Description: Fix handle_new_user trigger and complete_user_registration RPC to preserve all signup metadata (phone, governorate, position, dob) and avoid onboarding redirect loop.

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
  -- 1. استخراج الدور (player أو owner)
  v_role := COALESCE(new.raw_user_meta_data->>'role', 'player');
  IF v_role NOT IN ('player', 'owner', 'admin', 'co_founder') THEN
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

  -- 4. استخراج رقم الهاتف والمحافظة وتاريخ الميلاد (إن وجدوا وقت التسجيل)
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

  -- إذا كان الهاتف والاسم موجودين يصبح الحساب مكتملاً فورياً دون إجباره على Onboarding مكرر
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

CREATE OR REPLACE FUNCTION public.complete_user_registration(
    p_user_id uuid,
    p_phone text,
    p_name text DEFAULT NULL::text,
    p_position text DEFAULT NULL::text,
    p_governorate text DEFAULT 'Cairo'::text,
    p_date_of_birth timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_p2p_instapay text DEFAULT NULL::text,
    p_p2p_vodafone text DEFAULT NULL::text,
    p_p2p_bank text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid UUID := COALESCE(p_user_id, auth.uid());
    v_existing_role TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User ID required');
    END IF;

    -- التحقق من عدم تكرار رقم الهاتف مع مستخدم آخر
    IF p_phone IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.users 
        WHERE phone = p_phone AND id != v_uid
    ) THEN
        RETURN jsonb_build_object('success', false, 'error', 'رقم الهاتف مسجل مسبقاً بحساب آخر');
    END IF;

    SELECT role INTO v_existing_role FROM public.users WHERE id = v_uid;

    UPDATE public.users
    SET 
        phone = COALESCE(p_phone, phone),
        name = COALESCE(NULLIF(p_name, ''), name),
        position = COALESCE(p_position, position, 'GK'),
        governorate = COALESCE(p_governorate, governorate, 'Cairo'),
        date_of_birth = COALESCE(p_date_of_birth::text, date_of_birth),
        p2p_instapay = COALESCE(p_p2p_instapay, p2p_instapay),
        p2p_vodafone = COALESCE(p_p2p_vodafone, p2p_vodafone),
        p2p_bank = COALESCE(p_p2p_bank, p2p_bank),
        additional_data = jsonb_set(
            COALESCE(additional_data, '{}'::jsonb),
            '{isOnboardingConfirmed}',
            'true'::jsonb,
            true
        ),
        is_registration_complete = true,
        is_email_verified = true,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Registration completed successfully'
    );
END;
$function$;
