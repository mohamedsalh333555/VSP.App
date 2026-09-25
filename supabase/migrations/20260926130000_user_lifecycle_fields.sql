-- User lifecycle field hardening -- 2026-09-26
create or replace function public.trg_fn_protect_user_sensitive_fields()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_caller_role text; v_is_admin boolean:=false;
begin
  if current_user in ('postgres','service_role')
     or (auth.uid() is null and session_user in ('postgres','supabase_admin')) then return new; end if;
  if auth.uid() is not null then
    select role into v_caller_role from public.users where id=auth.uid();
    v_is_admin:=coalesce(v_caller_role in ('admin','co_founder','cofounder','super_admin'),false);
  end if;
  if v_is_admin then return new; end if;

  if old.role is distinct from new.role
     or old.email is distinct from new.email
     or old.subscription_plan is distinct from new.subscription_plan
     or old.subscription_expires_at is distinct from new.subscription_expires_at
     or old.trial_ends_at is distinct from new.trial_ends_at
     or old.total_platform_fees is distinct from new.total_platform_fees
     or old.cash_booking_banned is distinct from new.cash_booking_banned
     or old.no_show_count is distinct from new.no_show_count
     or old.is_identity_verified is distinct from new.is_identity_verified
     or old.is_email_verified is distinct from new.is_email_verified
     or old.verification_status is distinct from new.verification_status
     or old.is_blocked is distinct from new.is_blocked
     or old.has_stadium is distinct from new.has_stadium
     or old.is_registration_complete is distinct from new.is_registration_complete
     or old.is_onboarding_confirmed is distinct from new.is_onboarding_confirmed then
    raise exception 'PERMISSION_DENIED: Account security and lifecycle fields are server-authoritative.'
      using errcode='42501',detail='UNAUTHORIZED_USER_SENSITIVE_UPDATE';
  end if;
  return new;
end;
$function$;
drop trigger if exists trg_protect_users_sensitive_fields on public.users;
create trigger trg_protect_users_sensitive_fields
before update on public.users for each row
execute function public.trg_fn_protect_user_sensitive_fields();
