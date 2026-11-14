-- Keep all profile creation/deletion behind authenticated server operations.
CREATE OR REPLACE FUNCTION public.provision_registration_profile(p_role text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_auth auth.users%ROWTYPE;
  v_role_result jsonb;
  v_prior_override text := current_setting('vsp.system_override', true);
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
  END IF;
  IF p_role IS NULL OR p_role NOT IN ('player','owner') THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_ROLE');
  END IF;
  SELECT * INTO v_auth FROM auth.users WHERE id=v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','AUTH_USER_NOT_FOUND');
  END IF;
  -- A repeat or a concurrent device must not reset an existing profile.
  IF EXISTS(SELECT 1 FROM public.users WHERE id=v_uid) THEN
    RETURN jsonb_build_object('success',true,'created',false);
  END IF;
  INSERT INTO public.users(
    id,email,name,role,profile_image_url,is_email_verified,
    is_registration_complete,subscription_plan,trial_ends_at
  ) VALUES (
    v_uid,v_auth.email,
    left(COALESCE(NULLIF(v_auth.raw_user_meta_data->>'full_name',''),
                  NULLIF(v_auth.raw_user_meta_data->>'name',''),'مستخدم جديد'),160),
    'player',
    CASE WHEN COALESCE(v_auth.raw_user_meta_data->>'avatar_url',
                       v_auth.raw_user_meta_data->>'picture','') LIKE 'https://%'
      THEN left(COALESCE(v_auth.raw_user_meta_data->>'avatar_url',
                         v_auth.raw_user_meta_data->>'picture'),2048) ELSE NULL END,
    v_auth.email_confirmed_at IS NOT NULL,
    false,'free',NULL
  );
  -- Reuse the existing catalog/one-time trial policy. Do not start a new trial.
  v_role_result := public.set_user_role_on_signup(p_role,v_uid);
  IF v_role_result->'success' IS DISTINCT FROM 'true'::jsonb THEN
    RAISE EXCEPTION 'PROFILE_ROLE_PROVISIONING_FAILED' USING ERRCODE='P0001';
  END IF;
  PERFORM set_config('vsp.system_override',COALESCE(v_prior_override,'false'),true);
  RETURN jsonb_build_object('success',true,'created',true);
END;
$$;
REVOKE ALL ON FUNCTION public.provision_registration_profile(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.provision_registration_profile(text) TO authenticated;
-- Definer registration and permanent-deletion RPCs retain their owner privileges.
REVOKE INSERT, DELETE ON public.users FROM PUBLIC, anon, authenticated;
