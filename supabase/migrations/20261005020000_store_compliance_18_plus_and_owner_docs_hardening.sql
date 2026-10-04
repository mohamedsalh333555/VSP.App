-- VSP Store/Legal Compliance Hardening: 18+ users + private owner-document uploads
-- Categories: Egypt + App Stores + Data Protection + Security + Accounts

create or replace function public.vsp_is_adult_date_of_birth(p_dob text)
returns boolean
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_raw text := trim(coalesce(p_dob, ''));
  v_date date;
begin
  if v_raw = '' or v_raw !~ '^\d{4}-\d{2}-\d{2}' then
    return false;
  end if;

  begin
    v_date := to_date(substr(v_raw, 1, 10), 'YYYY-MM-DD');
  exception when others then
    return false;
  end;

  if to_char(v_date, 'YYYY-MM-DD') <> substr(v_raw, 1, 10) then
    return false;
  end if;

  if v_date > current_date then
    return false;
  end if;

  return extract(year from age(current_date, v_date)) >= 18;
end;
$$;

create or replace function public.enforce_vsp_minimum_age()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
  if new.role in ('player', 'owner') then
    if nullif(trim(coalesce(new.date_of_birth, '')), '') is not null
       and not public.vsp_is_adult_date_of_birth(new.date_of_birth) then
      raise exception using
        errcode = 'P0002',
        message = 'VSP_AGE_RESTRICTED';
    end if;

    if coalesce(new.is_registration_complete, false)
       and not public.vsp_is_adult_date_of_birth(new.date_of_birth) then
      raise exception using
        errcode = 'P0002',
        message = 'REGISTRATION_REQUIRES_18_PLUS';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists aaa_trg_enforce_vsp_minimum_age on public.users;
create trigger aaa_trg_enforce_vsp_minimum_age
before insert or update of role, date_of_birth, is_registration_complete
on public.users
for each row
execute function public.enforce_vsp_minimum_age();

revoke execute on function public.vsp_is_adult_date_of_birth(text) from public, anon, authenticated;
revoke execute on function public.enforce_vsp_minimum_age() from public, anon, authenticated;

-- The bucket is already private. This broad INSERT policy bypassed the folder ownership
-- requirement because permissive policies are combined with OR.
drop policy if exists "Authenticated Upload for Owner Documents" on storage.objects;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_role text;
  v_name text;
  v_avatar text;
  v_phone text;
  v_governorate text;
  v_dob timestamptz;
  v_position text;
  v_is_complete boolean;
begin
  v_role := coalesce(nullif(new.raw_user_meta_data->>'role', ''), 'player');
  if v_role not in ('player', 'owner') then
    v_role := 'player';
  end if;

  v_name := coalesce(
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1)
  );

  v_avatar := coalesce(
    new.raw_user_meta_data->>'avatar_url',
    new.raw_user_meta_data->>'picture',
    null
  );

  v_phone := coalesce(
    nullif(new.raw_user_meta_data->>'phone', ''),
    nullif(new.phone, '')
  );

  v_governorate := nullif(new.raw_user_meta_data->>'governorate', '');
  v_position := nullif(new.raw_user_meta_data->>'position', '');

  begin
    v_dob := (new.raw_user_meta_data->>'date_of_birth')::timestamptz;
  exception when others then
    v_dob := null;
  end;

  v_is_complete := (
    v_phone is not null
    and length(regexp_replace(v_phone, '[^0-9]', '', 'g')) >= 9
    and v_governorate is not null
    and v_dob is not null
    and public.vsp_is_adult_date_of_birth(v_dob::text)
  );

  insert into public.users (
    id, email, name, role, phone, governorate, position, date_of_birth,
    profile_image_url, is_email_verified, is_registration_complete, created_at, updated_at
  ) values (
    new.id,
    coalesce(new.email, ''),
    v_name,
    v_role,
    v_phone,
    v_governorate,
    v_position,
    v_dob,
    v_avatar,
    true,
    v_is_complete,
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do update
  set email = excluded.email,
      name = coalesce(nullif(public.users.name, ''), excluded.name),
      role = coalesce(nullif(public.users.role, ''), excluded.role),
      phone = coalesce(nullif(public.users.phone, ''), excluded.phone),
      governorate = coalesce(nullif(public.users.governorate, ''), excluded.governorate),
      position = coalesce(nullif(public.users.position, ''), excluded.position),
      date_of_birth = coalesce(public.users.date_of_birth, excluded.date_of_birth),
      profile_image_url = coalesce(public.users.profile_image_url, excluded.profile_image_url),
      is_email_verified = true,
      is_registration_complete = case
        when public.users.is_registration_complete then true
        else excluded.is_registration_complete
      end,
      updated_at = timezone('utc', now());

  return new;
exception
  when others then
    if sqlstate = 'P0002' then
      raise;
    end if;
    raise warning 'handle_new_user error: %', sqlerrm;
    return new;
end;
$function$;

create or replace function public.complete_user_registration(
  p_user_id uuid default null,
  p_phone text default null,
  p_name text default null,
  p_position text default null,
  p_governorate text default null,
  p_date_of_birth text default null,
  p_p2p_instapay text default null,
  p_p2p_vodafone text default null,
  p_p2p_bank text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_uid uuid := coalesce(p_user_id, auth.uid());
  v_role text;
  v_updated integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'USER_ID_REQUIRED');
  end if;

  if nullif(trim(coalesce(p_date_of_birth, '')), '') is null then
    return jsonb_build_object('success', false, 'error', 'DATE_OF_BIRTH_REQUIRED_18_PLUS');
  end if;

  if not public.vsp_is_adult_date_of_birth(p_date_of_birth) then
    return jsonb_build_object('success', false, 'error', 'VSP_AGE_RESTRICTED');
  end if;

  select role into v_role from public.users where id = v_uid;
  if not found then
    return jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  end if;

  if coalesce(auth.role(), '') <> 'service_role'
     and v_uid is distinct from auth.uid() then
    if not public.is_admin_or_cofounder(auth.uid()) then
      return jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    end if;
  end if;

  if p_phone is not null
     and exists (
       select 1 from public.users
       where phone = p_phone and id <> v_uid
     ) then
    return jsonb_build_object('success', false, 'error', 'PHONE_ALREADY_IN_USE');
  end if;

  perform set_config('vsp.system_override', 'true', true);

  update public.users
  set phone = coalesce(p_phone, phone),
      name = coalesce(nullif(p_name, ''), name),
      position = coalesce(p_position, position, 'ST'),
      governorate = coalesce(p_governorate, governorate, 'Cairo'),
      date_of_birth = p_date_of_birth,
      p2p_instapay = coalesce(p_p2p_instapay, p2p_instapay),
      p2p_vodafone = coalesce(p_p2p_vodafone, p2p_vodafone),
      p2p_bank = coalesce(p_p2p_bank, p2p_bank),
      is_registration_complete = true,
      is_email_verified = true,
      updated_at = now()
  where id = v_uid;

  get diagnostics v_updated = row_count;
  if v_updated <> 1 then
    return jsonb_build_object('success', false, 'error', 'REGISTRATION_UPDATE_FAILED');
  end if;

  return jsonb_build_object('success', true, 'message', 'Registration completed successfully');
end;
$function$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.vsp_is_adult_date_of_birth(text) from public, anon, authenticated;
revoke execute on function public.enforce_vsp_minimum_age() from public, anon, authenticated;
