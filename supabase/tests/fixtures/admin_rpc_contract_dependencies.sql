-- TEST ONLY: three observed production RPC bodies; not full schema.
CREATE OR REPLACE FUNCTION public.admin_reset_no_show_count_atomic(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_role text; v_now timestamptz:=timezone('utc',now());
begin
  select role into v_role from public.users where id=auth.uid();
  if coalesce(auth.role(),'')<>'service_role' and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;
  if not exists(select 1 from public.users where id=p_user_id) then
    return jsonb_build_object('success',false,'error','User not found');
  end if;
  update public.users set no_show_count=0, updated_at=v_now where id=p_user_id;
  return jsonb_build_object('success',true,'user_id',p_user_id,'server_time',v_now);
end $function$;

CREATE OR REPLACE FUNCTION public.admin_set_owner_subscription_atomic(p_owner_id uuid, p_plan text, p_days integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role text;
  v_current_plan text;
  v_current_expires_at timestamptz;
  v_now timestamptz := timezone('utc', now());
  v_base_time timestamptz;
  v_new_expires_at timestamptz;
  v_normalized_plan text := lower(trim(coalesce(p_plan, '')));
  v_days integer;
BEGIN
  SELECT role INTO v_caller_role
  FROM public.users
  WHERE id = auth.uid();

  IF current_user NOT IN ('postgres','service_role')
     AND coalesce(auth.role(),'') <> 'service_role'
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can alter owner subscriptions';
  END IF;

  IF v_normalized_plan NOT IN ('free_trial','basic','pro') THEN
    RAISE EXCEPTION 'Invalid subscription plan';
  END IF;

  IF v_normalized_plan = 'basic' THEN
    -- Basic is permanently free (1 stadium, perpetual)
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', null,
      'server_time', v_now
    );
  ELSIF v_normalized_plan = 'free_trial' THEN
    -- Pro 7-day trial
    v_days := 7;
    UPDATE public.users
    SET subscription_plan = 'basic',
        subscription_expires_at = NULL,
        trial_ends_at = v_now + make_interval(days => v_days),
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'basic',
      'subscription_expires_at', null,
      'trial_ends_at', v_now + make_interval(days => v_days),
      'server_time', v_now,
      'catalog_trial_days', v_days
    );
  ELSE
    -- 'pro' plan requires positive days
    v_days := coalesce(p_days, 30);
    IF v_days < 1 OR v_days > 3650 THEN
      RAISE EXCEPTION 'A valid subscription duration is required for paid plans';
    END IF;

    SELECT subscription_plan, subscription_expires_at
    INTO v_current_plan, v_current_expires_at
    FROM public.users
    WHERE id = p_owner_id
    FOR UPDATE;

    v_base_time := v_now;
    IF v_current_plan = 'pro'
       AND v_current_expires_at IS NOT NULL
       AND v_current_expires_at > v_now THEN
      v_base_time := v_current_expires_at;
    END IF;

    v_new_expires_at := v_base_time + make_interval(days => v_days);

    UPDATE public.users
    SET subscription_plan = 'pro',
        subscription_expires_at = v_new_expires_at,
        trial_ends_at = NULL,
        updated_at = v_now
    WHERE id = p_owner_id;

    RETURN jsonb_build_object(
      'success', true,
      'owner_id', p_owner_id,
      'subscription_plan', 'pro',
      'subscription_expires_at', v_new_expires_at,
      'trial_ends_at', null,
      'server_time', v_now
    );
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_toggle_user_block(p_user_id uuid, p_is_blocked boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$ DECLARE v_admin_id UUID:=auth.uid(); v_admin_role TEXT; v_target RECORD; BEGIN SELECT role INTO v_admin_role FROM public.users WHERE id=v_admin_id; IF COALESCE(auth.role(),'')<>'service_role' AND COALESCE(v_admin_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','UNAUTHORIZED'); END IF; SELECT id,role,is_blocked,email INTO v_target FROM public.users WHERE id=p_user_id; IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','USER_NOT_FOUND'); END IF; IF v_target.role=ANY(ARRAY['co_founder','cofounder','super_admin']) THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_PROTECTED_ACCOUNT'); END IF; IF v_admin_id=p_user_id THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_SELF'); END IF; IF v_target.role='admin' AND COALESCE(v_admin_role,'') NOT IN ('co_founder','cofounder','super_admin') THEN RETURN jsonb_build_object('success',false,'error','CANNOT_BLOCK_ADMIN'); END IF; UPDATE public.users SET is_blocked=p_is_blocked,updated_at=NOW() WHERE id=p_user_id; INSERT INTO public.system_audit_logs(action,table_name,record_id,old_data,new_data,changed_by,changed_by_role,created_at) VALUES(CASE WHEN p_is_blocked THEN 'admin_block_user' ELSE 'admin_unblock_user' END,'users',p_user_id,jsonb_build_object('is_blocked',v_target.is_blocked,'email',v_target.email),jsonb_build_object('is_blocked',p_is_blocked),v_admin_id,v_admin_role,NOW()); RETURN jsonb_build_object('success',true,'user_id',p_user_id,'is_blocked',p_is_blocked,'server_time',NOW()); END; $function$;
