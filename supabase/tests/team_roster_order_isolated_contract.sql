-- Local disposable DB only; the source migration is injected below.
create schema auth;
create function auth.uid() returns uuid language sql stable as $uid$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$uid$;
do $$ begin
  if not exists(select 1 from pg_roles where rolname='authenticated') then
    create role authenticated;
  end if;
  if not exists(select 1 from pg_roles where rolname='anon') then
    create role anon;
  end if;
end $$;
create table public.users (id uuid primary key, role text, name text, phone text, position text);
create table public.teams (id uuid primary key, captain_id uuid not null);
create table public.team_members (
  team_id uuid not null, user_id uuid not null, joined_at timestamptz,
  primary key(team_id,user_id)
);

-- ROSTER_FUNCTION_HERE

do $test$ declare
  team_id constant uuid := '10000000-0000-4000-8000-000000000001';
  captain constant uuid := '20000000-0000-4000-8000-000000000001';
  member constant uuid := '20000000-0000-4000-8000-000000000002';
  outsider constant uuid := '20000000-0000-4000-8000-000000000003';
  admin constant uuid := '20000000-0000-4000-8000-000000000004';
  roster uuid[];
begin
  insert into public.users values
    (captain,'player','Captain','0001','GK'),
    (member,'player','Member','0002','FW'),
    (outsider,'player','Outsider','0003','MF'),
    (admin,'admin','Admin','0004','DF');
  insert into public.teams values(team_id,captain);
  insert into public.team_members values
    (team_id,captain,now()-interval '1 day'),
    (team_id,member,now());

  perform set_config('request.jwt.claim.sub',outsider::text,true);
  if exists(select 1 from public.get_team_member_profiles(team_id)) then
    raise exception 'outsider read private roster';
  end if;
  perform set_config('request.jwt.claim.sub',member::text,true);
  select array_agg(uid) into roster from public.get_team_member_profiles(team_id);
  if roster is distinct from array[captain,member] then
    raise exception 'member roster missing or nondeterministic';
  end if;
  perform set_config('request.jwt.claim.sub',admin::text,true);
  if (select count(*) from public.get_team_member_profiles(team_id))<>2 then
    raise exception 'admin cannot read the team roster';
  end if;
  perform set_config('request.jwt.claim.sub','',true);
  if exists(select 1 from public.get_team_member_profiles(team_id)) then
    raise exception 'no-identity roster leaked';
  end if;
  if has_function_privilege('anon','public.get_team_member_profiles(uuid)','execute') then
    raise exception 'anonymous role may execute roster function';
  end if;
end $test$;
