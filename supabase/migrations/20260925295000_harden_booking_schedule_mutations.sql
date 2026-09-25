-- Server-authoritative booking schedule mutations.
create or replace function public.request_booking_reschedule_atomic(p_booking_id uuid,p_new_start timestamptz,p_new_end timestamptz)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare b record;
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if p_new_end<=p_new_start then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 if b.owner_id is distinct from auth.uid() and b.user_id is distinct from auth.uid() and b.created_by_user_id is distinct from auth.uid() then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status='cancelled' then return jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); end if;
 update public.bookings set reschedule_status='pending',proposed_start_time=p_new_start,proposed_end_time=p_new_end,updated_at=now() where id=p_booking_id;
 return jsonb_build_object('success',true,'status','pending');
end $$;
create or replace function public.respond_booking_reschedule_atomic(p_booking_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare b record; v_conflict boolean; v_role text;
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 select role into v_role from public.users where id=auth.uid();
 if b.owner_id is distinct from auth.uid() and b.user_id is distinct from auth.uid() and b.created_by_user_id is distinct from auth.uid() and coalesce(v_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status='cancelled' then return jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); end if;
 if p_accept and b.proposed_start_time is not null and b.proposed_end_time is not null then
   select exists(select 1 from public.bookings x where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled' and x.start_time<b.proposed_end_time and x.end_time>b.proposed_start_time) into v_conflict;
   if v_conflict then
     update public.bookings set status='cancelled',reschedule_status='conflict_auto_cancelled',cancellation_reason='Proposed time was booked by another player',cancelled_at=now(),updated_at=now() where id=b.id;
     return jsonb_build_object('success',false,'error','CONFLICT_AUTO_CANCELLED');
   end if;
   update public.bookings set start_time=b.proposed_start_time,end_time=b.proposed_end_time,reschedule_status='accepted',proposed_start_time=null,proposed_end_time=null,updated_at=now() where id=b.id;
   return jsonb_build_object('success',true,'status','accepted');
 end if;
 update public.bookings set status='cancelled',reschedule_status='rejected',cancelled_at=now(),updated_at=now() where id=b.id;
 return jsonb_build_object('success',true,'status','rejected');
end $$;
create or replace function public.cleanup_stale_pending_bookings_atomic(p_user_id uuid,p_stadium_id uuid)
returns jsonb language plpgsql security definer set search_path='public','pg_temp' as $$
declare v_count integer;
begin
 if auth.uid() is null or (auth.uid()<>p_user_id and coalesce((select role from public.users where id=auth.uid()),'') not in ('admin','co_founder','cofounder','super_admin')) then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 update public.bookings set status='cancelled',payment_status='expired',cancellation_reason='Payment checkout expired',updated_at=now()
 where created_by_user_id=p_user_id and stadium_id=p_stadium_id and status='pending' and created_at<now()-interval '10 minutes';
 get diagnostics v_count=row_count;
 return jsonb_build_object('success',true,'cancelled_count',v_count);
end $$;
revoke all on function public.request_booking_reschedule_atomic(uuid,timestamptz,timestamptz) from public,anon;
revoke all on function public.respond_booking_reschedule_atomic(uuid,boolean) from public,anon;
revoke all on function public.cleanup_stale_pending_bookings_atomic(uuid,uuid) from public,anon;
grant execute on function public.request_booking_reschedule_atomic(uuid,timestamptz,timestamptz) to authenticated,service_role;
grant execute on function public.respond_booking_reschedule_atomic(uuid,boolean) to authenticated,service_role;
grant execute on function public.cleanup_stale_pending_bookings_atomic(uuid,uuid) to authenticated,service_role;