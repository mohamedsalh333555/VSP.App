-- Ephemeral SQL-only contract. All row IDs are synthetic and never external.
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
  pending_user_ids text[],
  updated_at timestamptz default now()
);

-- REJECT_JOIN_FUNCTION_HERE

do $contract$
declare
  b1 constant uuid := '10000000-0000-4000-8000-000000000001';
  host constant uuid := '20000000-0000-4000-8000-000000000001';
  invited constant uuid := '30000000-0000-4000-8000-000000000001';
  stranger constant uuid := '40000000-0000-4000-8000-000000000001';
  outcome jsonb;
begin
  insert into public.bookings(id,created_by_user_id,owner_id,pending_user_ids)
  values(b1,host,null,array[invited::text]);

  perform set_config('request.jwt.claim.role','authenticated',true);
  perform set_config('request.jwt.claim.sub',stranger::text,true);
  outcome := public.reject_join_request(b1::text,invited::text);
  if outcome->>'success' is distinct from 'false'
     or (select cardinality(pending_user_ids) from public.bookings where id=b1) <> 1 then
    raise exception 'FAIL: foreign caller with NULL owner must not erase request';
  end if;

  perform set_config('request.jwt.claim.sub',host::text,true);
  outcome := public.reject_join_request(b1::text,invited::text);
  if outcome->>'success' is distinct from 'true'
     or (select cardinality(pending_user_ids) from public.bookings where id=b1) <> 0 then
    raise exception 'FAIL: actual booking host should reject one request';
  end if;

  outcome := public.reject_join_request(b1::text,invited::text);
  if outcome->>'success' is distinct from 'true'
     or (select cardinality(pending_user_ids) from public.bookings where id=b1) <> 0 then
    raise exception 'FAIL: repeated rejection must be idempotent';
  end if;

  outcome := public.reject_join_request('forged-id',invited::text);
  if outcome->>'success' is distinct from 'false' then
    raise exception 'FAIL: malformed booking ID must be rejected';
  end if;

  update public.bookings set pending_user_ids=array[invited::text] where id=b1;
  perform set_config('request.jwt.claim.sub','',true);
  outcome := public.reject_join_request(b1::text,invited::text);
  if outcome->>'success' is distinct from 'false'
     or (select cardinality(pending_user_ids) from public.bookings where id=b1) <> 1 then
    raise exception 'FAIL: missing authenticated caller must not remove request';
  end if;
end;
$contract$;
