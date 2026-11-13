-- P1/SEC-07 proposed patch: prevent arbitrary/duplicate user admission.
-- Branch-only. Run on an isolated DB first; NOT applied to staging/production.
-- The deployed legacy function could add any passed user without a pending
-- request, and a NULL owner_id made its old != authorization unsafe.
create or replace function public.accept_join_request(
  p_booking_id text, p_user_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_booking record;
  v_user_uuid uuid;
  v_booking_uuid uuid;
  v_caller uuid;
begin
  if coalesce(p_booking_id,'') !~
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     or coalesce(p_user_id,'') !~
      '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    return jsonb_build_object('success',false,'error','INVALID_IDENTIFIER');
  end if;

  v_booking_uuid := p_booking_id::uuid;
  v_user_uuid := p_user_id::uuid;
  v_caller := auth.uid();

  select * into v_booking
  from public.bookings
  where id = v_booking_uuid
  for update;

  if not found then
    return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND');
  end if;

  -- IS DISTINCT FROM is mandatory: owner_id/created_by_user_id can be NULL.
  -- A comparison with NULL in the old function yielded NULL, not TRUE,
  -- allowing unauthorized callers to reach the update.
  if coalesce(auth.role(),'') <> 'service_role' and (
    v_caller is null or (
      v_caller is distinct from v_booking.created_by_user_id and
      v_caller is distinct from v_booking.owner_id
    )
  ) then
    return jsonb_build_object('success',false,'error','FORBIDDEN');
  end if;

  if lower(coalesce(v_booking.status,'')) in
      ('cancelled','canceled','expired','rejected','completed') then
    return jsonb_build_object('success',false,'error','BOOKING_NOT_ACTIVE');
  end if;

  -- Do not credit another player slot for repeated/racing approvals.
  -- A successful retry is idempotent when this user is already joined.
  if v_user_uuid = any(coalesce(v_booking.joined_user_ids, array[]::uuid[])) then
    return jsonb_build_object('success',true,'already_joined',true);
  end if;

  -- Explicit prior join request: a captain cannot enroll a third party
  -- merely by guessing their user ID. A missing pending row fails closed.
  if not (p_user_id = any(coalesce(
      v_booking.pending_user_ids, array[]::text[]
  ))) then
    return jsonb_build_object('success',false,'error','JOIN_REQUEST_REQUIRED');
  end if;

  if coalesce(v_booking.current_players,0) >=
     coalesce(v_booking.total_field_capacity,10) then
    return jsonb_build_object('success',false,'error','BOOKING_FULL');
  end if;

  update public.bookings
  set pending_user_ids = array_remove(
        coalesce(pending_user_ids,array[]::text[]),p_user_id
      ),
      joined_user_ids = array_append(
        coalesce(joined_user_ids,array[]::uuid[]),v_user_uuid
      ),
      current_players = coalesce(current_players,0) + 1,
      updated_at = now()
  where id = v_booking_uuid;

  return jsonb_build_object('success',true,'already_joined',false);
end;
$function$;

-- Keep direct user-facing approval available, with internal ownership and
-- pending-request checks performed inside the SECURITY DEFINER body.
revoke all on function public.accept_join_request(text,text)
  from public, anon;
grant execute on function public.accept_join_request(text,text)
  to authenticated, service_role;
