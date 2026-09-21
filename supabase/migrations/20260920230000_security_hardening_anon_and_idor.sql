-- Security hardening: close anonymous SECURITY DEFINER execution and fix IDORs
begin;

-- Functions that must never be callable anonymously.
revoke execute on function public.admin_set_owner_subscription_atomic(uuid,text,integer) from public, anon;
revoke execute on function public.admin_settle_owner_cash_debt_atomic(uuid,numeric,text) from public, anon;
revoke execute on function public.admin_toggle_user_block(uuid,boolean) from public, anon;
revoke execute on function public.check_extension_available(uuid,timestamptz) from public, anon;
revoke execute on function public.check_owner_stadium_limit_trigger() from public, anon, authenticated;
revoke execute on function public.complete_user_registration(uuid,text,text,text,text,text,text,text) from public, anon;
revoke execute on function public.confirm_owner_onboarding(uuid) from public, anon;
revoke execute on function public.generate_booking_qr_token(uuid) from public, anon;
revoke execute on function public.get_current_user_role(uuid) from public, anon;
revoke execute on function public.get_server_timestamp() from public, anon;
revoke execute on function public.pgmq_archive(text,bigint) from public, anon, authenticated;
revoke execute on function public.pgmq_read(text,integer,integer) from public, anon, authenticated;
revoke execute on function public.register_user_referral(text) from public, anon;
revoke execute on function public.remove_tournament_team_atomic(uuid,uuid) from public, anon;
revoke execute on function public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) from public, anon;
revoke execute on function public.save_and_publish_1v1_tournament_atomic(uuid,jsonb) from public, anon;
revoke execute on function public.set_user_role_on_signup(text,uuid) from public, anon;
revoke execute on function public.trg_fn_enforce_booking_state_machine() from public, anon, authenticated;
revoke execute on function public.trg_fn_protect_user_sensitive_fields() from public, anon, authenticated;
revoke execute on function public.verify_booking_qr_atomic(uuid,text) from public, anon;

grant execute on function public.check_extension_available(uuid,timestamptz) to authenticated, service_role;
grant execute on function public.complete_user_registration(uuid,text,text,text,text,text,text,text,text) to authenticated, service_role;
grant execute on function public.confirm_owner_onboarding(uuid) to authenticated, service_role;
grant execute on function public.generate_booking_qr_token(uuid) to authenticated, service_role;
grant execute on function public.get_current_user_role(uuid) to authenticated, service_role;
grant execute on function public.get_server_timestamp() to authenticated, service_role;
grant execute on function public.register_user_referral(text) to authenticated, service_role;
grant execute on function public.remove_tournament_team_atomic(uuid,uuid) to authenticated, service_role;
grant execute on function public.request_owner_payout_settlement_atomic(uuid,numeric,text,text) to authenticated, service_role;
grant execute on function public.verify_booking_qr_atomic(uuid,text) to authenticated, service_role;

-- Prevent authenticated IDOR against onboarding confirmation.
create or replace function public.confirm_owner_onboarding(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user record;
  v_caller_role text;
begin
  if auth.role() <> 'service_role' then
    if auth.uid() is null then
      return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
    end if;
    if p_user_id is distinct from auth.uid() then
      select role into v_caller_role from public.users where id = auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
        return jsonb_build_object('success',false,'error','UNAUTHORIZED');
      end if;
    end if;
  end if;

  select id, role, is_onboarding_confirmed into v_user
  from public.users where id = p_user_id;

  if not found then
    return jsonb_build_object('success',false,'error','USER_NOT_FOUND');
  end if;
  if v_user.role <> 'owner' then
    return jsonb_build_object('success',false,'error','NOT_AN_OWNER');
  end if;

  update public.users
  set is_onboarding_confirmed = true, updated_at = now()
  where id = p_user_id;

  return jsonb_build_object('success',true);
end;
$$;

-- Prevent authenticated users from assigning a role to another user's account.
create or replace function public.set_user_role_on_signup(p_role text, p_user_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid;
  v_user record;
  v_caller_role text;
  v_trial_ends_at timestamptz;
  v_ledger_record record;
  v_remaining_days integer;
begin
  v_uid := coalesce(p_user_id, auth.uid());

  if v_uid is null then
    return jsonb_build_object('success',false,'error','NO_USER_ID');
  end if;

  if auth.role() <> 'service_role' then
    if auth.uid() is null then
      return jsonb_build_object('success',false,'error','AUTHENTICATION_REQUIRED');
    end if;
    if v_uid is distinct from auth.uid() then
      select role into v_caller_role from public.users where id = auth.uid();
      if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
        return jsonb_build_object('success',false,'error','UNAUTHORIZED');
      end if;
    end if;
  end if;

  select id,email,phone,role,is_registration_complete,trial_ends_at
  into v_user from public.users where id = v_uid;

  if not found then
    return jsonb_build_object('success',false,'error','USER_NOT_FOUND');
  end if;
  if coalesce(v_user.is_registration_complete,false) then
    return jsonb_build_object('success',false,'error','REGISTRATION_ALREADY_COMPLETE');
  end if;
  if p_role not in ('player','owner') then
    return jsonb_build_object('success',false,'error','INVALID_ROLE');
  end if;

  if p_role = 'owner' then
    select * into v_ledger_record
    from public.owner_trial_ledger
    where lower(trim(email)) = lower(trim(v_user.email))
       or (phone is not null and v_user.phone is not null and phone = v_user.phone)
    limit 1;

    if v_ledger_record is not null then
      v_remaining_days := greatest(0,extract(day from (v_ledger_record.original_trial_ends_at-now()))::integer);
      v_trial_ends_at := case
        when v_remaining_days > 0 then now() + (v_remaining_days || ' days')::interval
        else now()
      end;
    else
      v_trial_ends_at := now() + interval '60 days';
      insert into public.owner_trial_ledger(email,phone,user_id,original_trial_ends_at)
      values(lower(trim(v_user.email)),v_user.phone,v_uid,v_trial_ends_at)
      on conflict do nothing;
    end if;

    update public.users
    set role='owner',subscription_plan='free_trial',trial_ends_at=v_trial_ends_at
    where id=v_uid and coalesce(is_registration_complete,false)=false;
  else
    update public.users
    set role='player'
    where id=v_uid and coalesce(is_registration_complete,false)=false;
  end if;

  return jsonb_build_object('success',true,'role',p_role,'trial_ends_at',v_trial_ends_at);
end;
$$;

-- Harden mutable search_path warnings.
alter function public.standardize_egypt_governorate(text)
  set search_path = pg_catalog, public;
alter function public.trg_standardize_1v1_tournament_governorate()
  set search_path = pg_catalog, public;

commit;
