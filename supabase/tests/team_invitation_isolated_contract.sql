-- Disposable PostgreSQL-only fixture. No hosted Supabase connection or real users.
-- Invitation RPC bodies are injected by the guarded local runner below.
create extension if not exists pgcrypto;
create schema auth;
create function auth.uid()
returns uuid language sql stable as $uid$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$uid$;

create table public.users(
  id uuid primary key,
  governorate text
);
create table public.teams(
  id uuid primary key,
  captain_id uuid not null references public.users(id),
  governorate text not null
);
create table public.team_members(
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  primary key(team_id, user_id)
);
create table public.team_membership_invitations(
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  invited_user_id uuid not null references public.users(id) on delete cascade,
  invited_by uuid not null references public.users(id),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '7 days')
);
create unique index team_membership_one_pending_invite
  on public.team_membership_invitations(team_id, invited_user_id)
  where status = 'pending';

-- INVITE_FUNCTION_HERE
-- RESPOND_FUNCTION_HERE

do $contract$
declare
  captain constant uuid := '10000000-0000-4000-8000-000000000001';
  recipient constant uuid := '20000000-0000-4000-8000-000000000001';
  stranger constant uuid := '30000000-0000-4000-8000-000000000001';
  mismatch constant uuid := '40000000-0000-4000-8000-000000000001';
  team constant uuid := '50000000-0000-4000-8000-000000000001';
  valid_invite constant uuid := '60000000-0000-4000-8000-000000000001';
  expired_invite constant uuid := '60000000-0000-4000-8000-000000000002';
  decline_invite constant uuid := '60000000-0000-4000-8000-000000000003';
  result jsonb;
begin
  insert into public.users(id, governorate) values
    (captain, 'Aswan'), (recipient, 'Aswan'), (stranger, 'Aswan'),
    (mismatch, 'Cairo');
  insert into public.teams(id, captain_id, governorate)
  values(team, captain, 'Aswan');

  -- Only the captain can issue a team invitation.
  perform set_config('request.jwt.claim.sub', stranger::text, true);
  result := public.invite_team_member(team, recipient);
  if result->>'success' is distinct from 'false' then
    raise exception 'FAIL: non-captain issued an invitation';
  end if;

  -- The real captain can invite a same-governorate player.
  perform set_config('request.jwt.claim.sub', captain::text, true);
  result := public.invite_team_member(team, recipient);
  if result->>'success' is distinct from 'true' then
    raise exception 'FAIL: captain invitation rejected: %', result;
  end if;
  update public.team_membership_invitations
  set id = valid_invite
  where team_id = team and invited_user_id = recipient and status = 'pending';

  -- A different authenticated account cannot accept someone else's invite.
  perform set_config('request.jwt.claim.sub', stranger::text, true);
  result := public.respond_team_membership_invitation(valid_invite, true);
  if result->>'success' is distinct from 'false'
     or exists(select 1 from public.team_members where team_id = team and user_id = recipient)
     or (select status from public.team_membership_invitations where id = valid_invite) <> 'pending' then
    raise exception 'FAIL: wrong recipient mutated invitation or membership';
  end if;

  -- The recipient accepts once and becomes a member exactly once.
  perform set_config('request.jwt.claim.sub', recipient::text, true);
  result := public.respond_team_membership_invitation(valid_invite, true);
  if result->>'success' is distinct from 'true'
     or (select status from public.team_membership_invitations where id = valid_invite) <> 'accepted'
     or (select count(*) from public.team_members where team_id = team and user_id = recipient) <> 1 then
    raise exception 'FAIL: valid acceptance did not update membership atomically';
  end if;
  result := public.respond_team_membership_invitation(valid_invite, true);
  if result->>'success' is distinct from 'false'
     or (select count(*) from public.team_members where team_id = team and user_id = recipient) <> 1 then
    raise exception 'FAIL: repeated acceptance was not rejected safely';
  end if;

  -- An expired invitation stays unaccepted and creates no membership.
  insert into public.team_membership_invitations(
    id, team_id, invited_user_id, invited_by, expires_at
  ) values(expired_invite, team, stranger, captain, now() - interval '1 minute');
  perform set_config('request.jwt.claim.sub', stranger::text, true);
  result := public.respond_team_membership_invitation(expired_invite, true);
  if result->>'success' is distinct from 'false'
     or exists(select 1 from public.team_members where team_id = team and user_id = stranger)
     or (select status from public.team_membership_invitations where id = expired_invite) <> 'pending' then
    raise exception 'FAIL: expired invitation changed membership or status';
  end if;

  -- Declining records the recipient decision without adding membership.
  insert into public.team_membership_invitations(
    id, team_id, invited_user_id, invited_by
  ) values(decline_invite, team, stranger, captain);
  result := public.respond_team_membership_invitation(decline_invite, false);
  if result->>'success' is distinct from 'true'
     or (select status from public.team_membership_invitations where id = decline_invite) <> 'declined'
     or exists(select 1 from public.team_members where team_id = team and user_id = stranger) then
    raise exception 'FAIL: decline did not remain membership-free';
  end if;

  -- Cross-governorate users cannot be invited.
  perform set_config('request.jwt.claim.sub', captain::text, true);
  result := public.invite_team_member(team, mismatch);
  if result->>'success' is distinct from 'false' then
    raise exception 'FAIL: governorate mismatch invitation succeeded';
  end if;

  perform set_config('request.jwt.claim.sub', '', true);
  result := public.invite_team_member(team, stranger);
  if result->>'success' is distinct from 'false' then
    raise exception 'FAIL: anonymous invitation succeeded';
  end if;
end;
$contract$;
