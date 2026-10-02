-- Manual owner bookings: no player count, no owner payment-confirmation workflow, no no-show workflow.
-- Production functions were updated to mark the owner-created record paid cash and keep current_players NULL.

CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(
  p_owner_id uuid, p_stadium_id uuid, p_start_time timestamptz, p_end_time timestamptz,
  p_customer_name text, p_customer_phone text DEFAULT NULL, p_notes text DEFAULT NULL,
  p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
declare v_stadium record; v_role text; v_actual_owner_id uuid; v_authorized boolean:=false;
v_duration numeric; v_server_total numeric; v_collected numeric; v_booking_id uuid; v_tx_id uuid; v_ref text; v_now timestamptz:=now();
begin
select * into v_stadium from public.stadiums where id=p_stadium_id for update;
if not found then return jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND'); end if;
v_actual_owner_id:=v_stadium.owner_id;
if v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) or coalesce(v_stadium.is_verified,false) is false then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
select role into v_role from public.users where id=auth.uid();
if auth.role()='service_role' or current_user in ('postgres','service_role') or v_actual_owner_id=auth.uid() or coalesce(v_role,'') in ('admin','co_founder','cofounder','super_admin') then v_authorized:=true; end if;
if not v_authorized then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if p_end_time<=p_start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
v_duration:=extract(epoch from(p_end_time-p_start_time))/3600;
if v_duration<=0 or v_duration>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
v_server_total:=round(coalesce(v_stadium.price_per_hour,v_stadium.base_price,0)*v_duration,2);
if v_server_total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
if abs(coalesce(p_total_price,0)-v_server_total)>0.01 then return jsonb_build_object('success',false,'error','PRICE_MISMATCH','expected_total_price',v_server_total); end if;
v_collected:=v_server_total;
if p_start_time<v_now-(select booking_past_grace_minutes from public.platform_business_rules where id=1)*interval '1 minute' then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
perform pg_advisory_xact_lock(hashtextextended(p_stadium_id::text,0));
if exists(select 1 from public.bookings b where b.stadium_id=p_stadium_id and b.status<>'cancelled' and p_start_time<b.end_time and p_end_time>b.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
v_ref:='MANUAL_'||replace(gen_random_uuid()::text,'-','');
perform set_config('vsp.manual_booking_workflow','true',true);
insert into public.bookings(stadium_id,stadium_name,owner_id,user_id,created_by_user_id,start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,total_price,vsp_commission,gateway_fee,platform_fee,deposit_paid,is_deposit_paid,is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,is_private,rent_ball,created_at,updated_at)
values(p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,coalesce(auth.uid(),v_actual_owner_id),p_start_time,p_end_time,'personal',nullif(trim(p_customer_name),''),nullif(trim(p_customer_name),''),nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),v_server_total,0,0,0,v_collected,true,true,'paid','cash',v_ref,'confirmed',null,true,false,v_now,v_now)
returning id into v_booking_id;
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(v_actual_owner_id,v_booking_id,v_collected,'cash_settlement','completed','cash',v_ref,'تحصيل نقدي لحجز يدوي',jsonb_build_object('principal_amount',v_collected,'gross_amount',v_collected,'vsp_fee',0,'gateway_fee',0,'total_payment_fees',0,'server_recorded_at',v_now),v_now,v_now)
returning id into v_tx_id;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object('success',true,'booking_id',v_booking_id,'total_price',v_server_total,'collected_amount',v_collected,'remaining_amount',0,'payment_status','paid','transaction_id',v_tx_id);
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$;

CREATE OR REPLACE FUNCTION public.owner_update_manual_booking_atomic(
  p_booking_id uuid, p_end_time timestamptz, p_customer_name text, p_customer_phone text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_current_players integer DEFAULT 1, p_collected_amount numeric DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
declare b record; s record; r text; role_name text; dur numeric; total numeric; new_col numeric; old_col numeric; delta numeric; now_ts timestamptz:=now();
begin
select * into b from public.bookings where id=p_booking_id for update;
if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
select role into role_name from public.users where id=auth.uid();
if b.owner_id is distinct from auth.uid() and coalesce(role_name,'') not in ('admin','co_founder','cofounder','super_admin') and auth.role()<>'service_role' then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if b.status='cancelled' then return jsonb_build_object('success',false,'error','BOOKING_CANCELLED'); end if;
if b.payment_method<>'cash' or (coalesce(b.payment_transaction_id,'') not like 'MANUAL%' and b.created_by_user_id<>b.owner_id) then return jsonb_build_object('success',false,'error','MANUAL_BOOKING_ONLY'); end if;
if p_end_time<=b.start_time or now_ts>=b.start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
select * into s from public.stadiums where id=b.stadium_id for update;
if not found or s.is_deleted_by_owner or coalesce(s.is_blocked,false) then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
dur:=extract(epoch from(p_end_time-b.start_time))/3600;
if dur<=0 or dur>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
total:=round(coalesce(s.price_per_hour,s.base_price,0)*dur,2);
if total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
new_col:=total;
perform pg_advisory_xact_lock(hashtextextended(b.stadium_id::text,0));
if exists(select 1 from public.bookings x where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled' and b.start_time<x.end_time and p_end_time>x.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
old_col:=round(coalesce(b.deposit_paid,0),2); delta:=round(new_col-old_col,2); r:=coalesce(nullif(b.payment_transaction_id,''),'MANUAL_'||replace(gen_random_uuid()::text,'-',''));
perform set_config('vsp.manual_booking_workflow','true',true);
update public.bookings set end_time=p_end_time,player_team_name=coalesce(nullif(trim(p_customer_name),''),player_team_name),host_name=coalesce(nullif(trim(p_customer_name),''),host_name),player_phone=nullif(trim(p_customer_phone),''),notes=nullif(trim(p_notes),''),current_players=null,total_price=total,deposit_paid=new_col,is_deposit_paid=true,is_paid=true,payment_status='paid',payment_transaction_id=r,updated_at=now_ts where id=p_booking_id;
if abs(delta)>0.009 then
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(b.owner_id,p_booking_id,abs(delta),case when delta>0 then 'cash_settlement' else 'refund_cash' end,'completed','cash',r||case when delta>0 then '_ADJ_' else '_REF_' end||replace(gen_random_uuid()::text,'-',''),case when delta>0 then 'تعديل تحصيل نقدي لحجز يدوي' else 'تعديل/رد تحصيل نقدي لحجز يدوي' end,jsonb_build_object('previous_collected',old_col,'new_collected',new_col,'delta',delta,'manual_booking',true),now_ts,now_ts);
end if;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object('success',true,'booking_id',p_booking_id,'total_price',total,'collected_amount',new_col,'remaining_amount',0,'payment_status','paid');
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$;