-- Reschedule state machine: request -> pending -> accept/reject.
-- Reject never cancels the booking. Acceptance revalidates slot and pricing under a stadium advisory lock.
create or replace function public.request_booking_reschedule_atomic(p_booking_id uuid,p_new_start timestamptz,p_new_end timestamptz)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare b record; now_ts timestamptz:=now(); duration_minutes int;
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if p_new_end<=p_new_start then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 if b.owner_id<>auth.uid() and b.user_id<>auth.uid() and b.created_by_user_id<>auth.uid() then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status in ('cancelled','completed') then return jsonb_build_object('success',false,'error','BOOKING_NOT_RESCHEDULABLE'); end if;
 if now_ts>=b.start_time then return jsonb_build_object('success',false,'error','BOOKING_ALREADY_STARTED'); end if;
 if b.reschedule_status='pending' then return jsonb_build_object('success',false,'error','RESCHEDULE_ALREADY_PENDING'); end if;
 duration_minutes:=extract(epoch from(p_new_end-p_new_start))/60;
 if duration_minutes<(select booking_min_duration_minutes from public.platform_business_rules where id=1)
    or duration_minutes>(select booking_max_duration_hours from public.platform_business_rules where id=1)*60
 then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
 if p_new_start<now_ts then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
 update public.bookings set reschedule_status='pending',proposed_start_time=p_new_start,proposed_end_time=p_new_end,updated_at=now_ts where id=p_booking_id;
 return jsonb_build_object('success',true,'status','pending','booking_id',p_booking_id);
end; $$;

create or replace function public.respond_booking_reschedule_atomic(p_booking_id uuid,p_accept boolean)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare b record; role_name text; new_total numeric; old_total numeric; duration_hours numeric; now_ts timestamptz:=now();
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 select role into role_name from public.users where id=auth.uid();
 if b.owner_id<>auth.uid() and b.user_id<>auth.uid() and b.created_by_user_id<>auth.uid()
    and coalesce(role_name,'') not in ('admin','co_founder','cofounder','super_admin')
 then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status in ('cancelled','completed') then return jsonb_build_object('success',false,'error','BOOKING_NOT_RESCHEDULABLE'); end if;
 if b.reschedule_status<>'pending' or b.proposed_start_time is null or b.proposed_end_time is null then return jsonb_build_object('success',false,'error','NO_PENDING_RESCHEDULE'); end if;
 if not p_accept then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',true,'status','rejected','booking_id',p_booking_id);
 end if;
 perform pg_advisory_xact_lock(hashtextextended(b.stadium_id::text,0));
 if exists(select 1 from public.bookings x where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled'
   and x.start_time<b.proposed_end_time and x.end_time>b.proposed_start_time) then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','SLOT_NO_LONGER_AVAILABLE');
 end if;
 duration_hours:=extract(epoch from(b.proposed_end_time-b.proposed_start_time))/3600;
 select round(coalesce(s.price_per_hour,s.base_price,0)*duration_hours+
   case when b.rent_ball then coalesce((s.features->>'ballPrice')::numeric,0) else 0 end,2)
 into new_total from public.stadiums s where s.id=b.stadium_id for update;
 old_total:=round(coalesce(b.total_price,0),2);
 if new_total is null or new_total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
 if abs(new_total-old_total)>0.01 then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','PRICE_CHANGE_REQUIRES_REBOOKING','old_total',old_total,'new_total',new_total);
 end if;
 update public.bookings set start_time=b.proposed_start_time,end_time=b.proposed_end_time,reschedule_status='accepted',
   proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
 return jsonb_build_object('success',true,'status','accepted','booking_id',p_booking_id,'total_price',old_total);
end; $$;