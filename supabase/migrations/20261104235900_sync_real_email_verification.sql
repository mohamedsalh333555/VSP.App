-- Keep public.users.is_email_verified strictly synchronized with Supabase Auth.
--
-- The legacy signup trigger and complete_user_registration RPC both wrote TRUE
-- before the user had confirmed the email OTP.  That made the public profile an
-- unreliable authorization signal and could bypass the verification screen.

create or replace function public.sync_auth_email_verification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform set_config('vsp.system_override', 'true', true);

  update public.users
  set is_email_verified = (new.email_confirmed_at is not null),
      updated_at = timezone('utc', now())
  where id = new.id
    and is_email_verified is distinct from (new.email_confirmed_at is not null);

  return new;
end;
$$;

drop trigger if exists zz_sync_auth_email_verification on auth.users;
create trigger zz_sync_auth_email_verification
after insert or update of email_confirmed_at
on auth.users
for each row
execute function public.sync_auth_email_verification();

-- Correct any historical drift using Auth as the single source of truth.
do $$
begin
  perform set_config('vsp.system_override', 'true', true);

  update public.users u
  set is_email_verified = (au.email_confirmed_at is not null),
      updated_at = timezone('utc', now())
  from auth.users au
  where au.id = u.id
    and u.is_email_verified is distinct from (au.email_confirmed_at is not null);
end;
$$;

-- Profile completion must never mint email verification. The Auth trigger above
-- is the only writer that promotes this flag after an OTP is confirmed.
create or replace function public.guard_registration_email_verification()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_confirmed boolean;
begin
  if new.is_email_verified is distinct from old.is_email_verified then
    select (email_confirmed_at is not null)
      into v_confirmed
    from auth.users
    where id = new.id;

    new.is_email_verified := coalesce(v_confirmed, false);
  end if;

  return new;
end;
$$;

drop trigger if exists aab_guard_registration_email_verification on public.users;
create trigger aab_guard_registration_email_verification
before update of is_email_verified
on public.users
for each row
execute function public.guard_registration_email_verification();

revoke execute on function public.sync_auth_email_verification() from public, anon, authenticated;
revoke execute on function public.guard_registration_email_verification() from public, anon, authenticated;

