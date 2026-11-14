-- P1/SEC-07 branch-only proposal. No Staging/production deployment.
-- Legacy reject_join_request used NULL-unsafe <> ownership comparisons.
-- This version cannot remove another team's pending request via nullable owner.
create or replace function public.reject_join_request(
  p_booking_id text, p_user_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_booking record;
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
  v_caller := auth.uid();
  select * into v_booking
  from public.bookings
  where id = v_booking_uuid
  for update;

  if not found then
    return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND');
  end if;

  if coalesce(auth.role(),'') <> 'service_role' and (
    v_caller is null or (
      v_caller is distinct from v_booking.created_by_user_id and
      v_caller is distinct from v_booking.owner_id
    )
  ) then
    return jsonb_build_object('success',false,'error','FORBIDDEN');
  end if;

  -- Repeating an authorized rejection is intentionally harmless.
  if not (p_user_id = any(coalesce(
    v_booking.pending_user_ids,array[]::text[]
  ))) then
    return jsonb_build_object('success',true,'already_removed',true);
  end if;

  update public.bookings
  set pending_user_ids = array_remove(
        coalesce(pending_user_ids,array[]::text[]),p_user_id
      ),
      updated_at = now()
  where id = v_booking_uuid;

  return jsonb_build_object('success',true,'already_removed',false);
end;
$function$;

revoke all on function public.reject_join_request(text,text)
  from public, anon;
grant execute on function public.reject_join_request(text,text)
  to authenticated, service_role;
