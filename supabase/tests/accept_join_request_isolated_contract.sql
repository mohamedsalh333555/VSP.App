-- Disposable PostgreSQL-only fixture. No Supabase connection, no real users.
-- Function body injected at the marker below by the protected CI runner.
create schema auth;
create function auth.uid()
returns uuid language sql stable as $uid$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$uid$;
create function auth.role()
returns text language sql stable as $role$
  select coalesce(nullif(current_setting('request.jwt.claim.role',true),''),'anon')
$role$;
create table public.bookings(
  id uuid primary key,
  created_by_user_id uuid,
  owner_id uuid,
  booking_type text default 'open_join',
  status text not null default 'confirmed',
  current_players integer,
  total_field_capacity integer,
  pending_user_ids text[],
  joined_user_ids uuid[],
  updated_at timestamptz default now()
);

-- ACCEPT_JOIN_FUNCTION_HERE

do $contract$
declare
  b1 constant uuid := '10000000-0000-4000-8000-000000000001';
  b2 constant uuid := '10000000-0000-4000-8000-000000000002';
  host constant uuid := '20000000-0000-4000-8000-000000000001';
  player constant uuid := '30000000-0000-4000-8000-000000000001';
  stranger constant uuid := '40000000-0000-4000-8000-000000000001';
  outcome jsonb;
begin
  perform set_config('request.jwt.claim.role','authenticated',true);
  perform set_config('request.jwt.claim.sub',host::text,true);

  insert into public.bookings(id,created_by_user_id,owner_id,current_players,total_field_capacity)
  values(b1,host,null,1,10);

  outcome := public.accept_join_request(b1::text,player::text);
  if outcome->>'success' is distinct from 'false'
     or (select current_players from public.bookings where id=b1) <> 1 then
    raise exception 'FAIL: no pending consent must reject admission';
  end if;

  -- An unrelated caller cannot exploit a NULL owner_id (old function could).
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  outcome := public.accept_join_request(b1::text,player::text);
  if outcome->>'success' is distinct from 'false' then
    raise exception 'FAIL: NULL owner_id must not bypass caller authorization';
  end if;

  perform set_config('request.jwt.claim.sub',host::text,true);
  update public.bookings set pending_user_ids=array[player::text] where id=b1;
  outcome := public.accept_join_request(b1::text,player::text);
  if outcome->>'success' is distinct from 'true'
     or (select current_players from public.bookings where id=b1) <> 2
     or (select cardinality(joined_user_ids) from public.bookings where id=b1) <> 1
     or (select cardinality(pending_user_ids) from public.bookings where id=b1) <> 0 then
    raise exception 'FAIL: accepted request must atomically join one player';
  end if;

  outcome := public.accept_join_request(b1::text,player::text);
  if outcome->>'success' is distinct from 'true'
     or (select current_players from public.bookings where id=b1) <> 2
     or (select cardinality(joined_user_ids) from public.bookings where id=b1) <> 1 then
    raise exception 'FAIL: repeated approval must be idempotent';
  end if;

  -- A full active booking cannot admit an additional pending player.
  insert into public.bookings(
    id,created_by_user_id,owner_id,status,current_players,
    total_field_capacity,pending_user_ids
  ) values(b2,host,null,'confirmed',10,10,array[stranger::text]);
  outcome := public.accept_join_request(b2::text,stranger::text);
  if outcome->>'success' is distinct from 'false'
     or (select current_players from public.bookings where id=b2) <> 10 then
    raise exception 'FAIL: capacity violation';
  end if;

  update public.bookings set current_players=1,status='cancelled' where id=b2;
  outcome := public.accept_join_request(b2::text,stranger::text);
  if outcome->>'success' is distinct from 'false' then
    raise exception 'FAIL: cancelled booking must reject join';
  end if;

  outcome := public.accept_join_request('not-a-uuid',player::text);
  if outcome->>'success' is distinct from 'false' then
    raise exception 'FAIL: malformed booking id must fail closed';
  end if;

  perform set_config('request.jwt.claim.sub','',true);
  outcome := public.accept_join_request(b2::text,player::text);
  if outcome->>'success' is distinct from 'false' then
    raise exception 'FAIL: anonymous actor must fail closed';
  end if;
end;
$contract$;
