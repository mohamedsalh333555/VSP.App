-- Owner subscription UX/backend: one-time 7-day trial started explicitly by the owner.
-- Applied to production as: owner_trial_7_day_cta_and_canonical_subscription

UPDATE public.subscription_plans
SET trial_days = 7, updated_at = now()
WHERE code = 'basic' AND is_active = true;

CREATE OR REPLACE FUNCTION public.set_user_role_on_signup(p_role text, p_user_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid uuid := coalesce(p_user_id, auth.uid());
  v_user record;
  v_ledger record;
BEGIN
  IF v_uid IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID'); END IF;
  IF auth.role() <> 'service_role' THEN
    IF auth.uid() IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'AUTHENTICATION_REQUIRED'); END IF;
    IF v_uid IS DISTINCT FROM auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;
  END IF;

  SELECT id, email, phone, role, is_registration_complete INTO v_user
  FROM public.users WHERE id = v_uid;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND'); END IF;
  IF coalesce(v_user.is_registration_complete, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'REGISTRATION_ALREADY_COMPLETE');
  END IF;
  IF p_role NOT IN ('player', 'owner') THEN RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE'); END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  IF p_role = 'owner' THEN
    SELECT * INTO v_ledger FROM public.owner_trial_ledger
    WHERE lower(trim(email)) = lower(trim(v_user.email))
       OR (phone IS NOT NULL AND v_user.phone IS NOT NULL AND phone = v_user.phone)
    LIMIT 1;

    IF FOUND AND v_ledger.original_trial_ends_at > now() THEN
      UPDATE public.users SET role='owner', subscription_plan='free_trial',
        trial_ends_at=v_ledger.original_trial_ends_at, subscription_expires_at=NULL
      WHERE id=v_uid AND coalesce(is_registration_complete,false)=false;
    ELSIF FOUND THEN
      UPDATE public.users SET role='owner', subscription_plan='expired',
        trial_ends_at=v_ledger.original_trial_ends_at, subscription_expires_at=NULL
      WHERE id=v_uid AND coalesce(is_registration_complete,false)=false;
    ELSE
      UPDATE public.users SET role='owner', subscription_plan='expired',
        trial_ends_at=NULL, subscription_expires_at=NULL
      WHERE id=v_uid AND coalesce(is_registration_complete,false)=false;
    END IF;
  ELSE
    UPDATE public.users SET role='player'
    WHERE id=v_uid AND coalesce(is_registration_complete,false)=false;
  END IF;

  RETURN jsonb_build_object('success',true,'role',p_role,
    'trial_ends_at',(SELECT trial_ends_at FROM public.users WHERE id=v_uid));
END;
$function$;

CREATE OR REPLACE FUNCTION public.start_owner_trial()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_owner public.users%ROWTYPE;
  v_plan public.subscription_plans%ROWTYPE;
  v_existing public.owner_trial_ledger%ROWTYPE;
  v_now timestamptz := now();
  v_ends timestamptz;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501'; END IF;

  SELECT * INTO v_owner FROM public.users WHERE id=v_uid FOR UPDATE;
  IF NOT FOUND OR v_owner.role <> 'owner' THEN RAISE EXCEPTION 'OWNER_ONLY' USING ERRCODE='42501'; END IF;

  IF v_owner.subscription_plan IN ('pro','basic')
     AND v_owner.subscription_expires_at IS NOT NULL
     AND v_owner.subscription_expires_at > v_now THEN
    RETURN jsonb_build_object('success',false,'error','SUBSCRIPTION_ALREADY_ACTIVE');
  END IF;

  IF v_owner.subscription_plan='free_trial'
     AND v_owner.trial_ends_at IS NOT NULL
     AND v_owner.trial_ends_at > v_now THEN
    RETURN jsonb_build_object('success',true,'already_active',true,'trial_ends_at',v_owner.trial_ends_at);
  END IF;

  SELECT * INTO v_existing FROM public.owner_trial_ledger
  WHERE lower(trim(email))=lower(trim(v_owner.email))
     OR (phone IS NOT NULL AND v_owner.phone IS NOT NULL AND phone=v_owner.phone)
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object('success',false,'error','TRIAL_ALREADY_USED',
      'trial_ends_at',v_existing.original_trial_ends_at);
  END IF;

  SELECT * INTO v_plan FROM public.subscription_plans
  WHERE code='basic' AND is_active=true LIMIT 1;
  IF NOT FOUND OR v_plan.trial_days IS NULL OR v_plan.trial_days <= 0 THEN
    RAISE EXCEPTION 'TRIAL_CONFIGURATION_MISSING';
  END IF;

  v_ends := v_now + make_interval(days=>v_plan.trial_days);

  INSERT INTO public.owner_trial_ledger(email,phone,user_id,first_trial_started_at,original_trial_ends_at)
  VALUES(lower(trim(v_owner.email)),nullif(trim(v_owner.phone),''),v_uid,v_now,v_ends);

  UPDATE public.users SET subscription_plan='free_trial',
    trial_ends_at=v_ends, subscription_expires_at=NULL, updated_at=v_now
  WHERE id=v_uid;

  RETURN jsonb_build_object('success',true,'already_active',false,
    'trial_started_at',v_now,'trial_ends_at',v_ends,'trial_days',v_plan.trial_days);
END;
$function$;

REVOKE ALL ON FUNCTION public.start_owner_trial() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_owner_trial() TO authenticated, service_role;
