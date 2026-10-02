alter table public.championships
  add column if not exists owner_approval_home_seen_at timestamptz;

create or replace function public.claim_owner_championship_approval_home_notice(
  p_championship_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_owner_id uuid;
  v_is_approved boolean;
  v_creation_fee_paid boolean;
  v_seen_at timestamptz;
  v_now timestamptz := now();
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED');
  end if;

  select owner_id, is_approved, creation_fee_paid, owner_approval_home_seen_at
    into v_owner_id, v_is_approved, v_creation_fee_paid, v_seen_at
  from public.championships
  where id = p_championship_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'CHAMPIONSHIP_NOT_FOUND');
  end if;

  if v_owner_id is distinct from v_uid then
    return jsonb_build_object('success', false, 'error', 'OWNER_ONLY');
  end if;

  if coalesce(v_is_approved, false) = false then
    return jsonb_build_object(
      'success', true,
      'state', case when coalesce(v_creation_fee_paid, false) then 'pending_approval' else 'draft' end,
      'seen_at', null,
      'seen_until', null
    );
  end if;

  if v_seen_at is null then
    v_seen_at := v_now;
    update public.championships
       set owner_approval_home_seen_at = v_seen_at,
           updated_at = v_now
     where id = p_championship_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'state', 'approved',
    'seen_at', v_seen_at,
    'seen_until', v_seen_at + interval '24 hours'
  );
end;
$$;

revoke execute on function public.claim_owner_championship_approval_home_notice(uuid) from public, anon;
grant execute on function public.claim_owner_championship_approval_home_notice(uuid) to authenticated;