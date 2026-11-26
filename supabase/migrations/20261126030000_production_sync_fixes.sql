-- =============================================================
-- VSP Production Safe Patch (Verified against live schema)
-- Applied directly to production database
-- =============================================================
BEGIN;

-- 1. Update platform_fee_config to 5% player + 5% owner
ALTER TABLE public.platform_fee_config
  ADD COLUMN IF NOT EXISTS owner_vsp_rate  NUMERIC(5,4) DEFAULT 0.05,
  ADD COLUMN IF NOT EXISTS player_vsp_rate NUMERIC(5,4) DEFAULT 0.05;

UPDATE public.platform_fee_config
SET
  booking_vsp_rate = 0.05,
  player_vsp_rate  = 0.05,
  owner_vsp_rate   = 0.05;

-- 2. Fix CRASH-05: allow 'no_show' in bookings status constraint
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending','confirmed','completed','cancelled','expired','no_show'));

-- 3. Fix SEC-08: restore INSERT grant on notifications
GRANT INSERT ON TABLE public.notifications TO authenticated;

-- 4. Fix SEC-02: restrict high-risk admin RPCs to service_role
REVOKE EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic(uuid, text, integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_set_owner_subscription_atomic(uuid, text, integer) TO service_role;

REVOKE EXECUTE ON FUNCTION public.confirm_owner_subscription_payment(uuid, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.confirm_owner_subscription_payment(uuid, text, numeric) TO service_role;

REVOKE EXECUTE ON FUNCTION public.admin_finalize_1v1_tournament_atomic(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.admin_finalize_1v1_tournament_atomic(uuid, uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_1v1_prize_delivered_atomic(uuid, text) TO service_role;

-- 5. Fix SEC-04: fix inverted maintenance check in vsp_validate_stadium_booking_window
CREATE OR REPLACE FUNCTION public.vsp_validate_stadium_booking_window(
  p_opening_time time without time zone,
  p_closing_time time without time zone,
  p_break_start_time time without time zone,
  p_break_end_time time without time zone,
  p_is_split_shift boolean,
  p_maintenance_until timestamp with time zone,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_local_start timestamp;
  v_local_end timestamp;
  v_day date;
  v_open_ts timestamp;
  v_close_ts timestamp;
  v_break_start_ts timestamp;
  v_break_end_ts timestamp;
begin
  if p_end_time <= p_start_time then return false; end if;
  -- FIXED: reject bookings starting BEFORE maintenance ends (previously > blocked all future bookings)
  if p_maintenance_until is not null and p_start_time < p_maintenance_until then return false; end if;

  v_local_start := timezone('Africa/Cairo', p_start_time);
  v_local_end := timezone('Africa/Cairo', p_end_time);
  v_day := v_local_start::date;

  if p_opening_time is null or p_closing_time is null then return false; end if;

  v_open_ts := v_day + p_opening_time;
  v_close_ts := v_day + p_closing_time;

  if p_closing_time <= p_opening_time then
    v_close_ts := v_close_ts + interval '1 day';
    if v_local_start < v_open_ts then
      v_open_ts := v_open_ts - interval '1 day';
      v_close_ts := v_close_ts - interval '1 day';
    end if;
  end if;

  if v_local_start < v_open_ts or v_local_end > v_close_ts then return false; end if;

  if coalesce(p_is_split_shift,false)
     and p_break_start_time is not null
     and p_break_end_time is not null
     and p_break_start_time <> p_break_end_time then
    v_break_start_ts := v_day + p_break_start_time;
    v_break_end_ts := v_day + p_break_end_time;

    if p_break_end_time <= p_break_start_time then
      v_break_end_ts := v_break_end_ts + interval '1 day';
      if v_local_start < v_break_start_ts then
        v_break_start_ts := v_break_start_ts - interval '1 day';
        v_break_end_ts := v_break_end_ts - interval '1 day';
      end if;
    end if;

    if v_local_start < v_break_end_ts and v_local_end > v_break_start_ts then
      return false;
    end if;
  end if;

  return true;
end;
$function$;

-- 6. Fix CRASH-03: fix typo excluded.opponent_team_logo -> excluded.opponent_team_logo_url
CREATE OR REPLACE FUNCTION public.sync_booking_public_feed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op='DELETE' then
    delete from public.booking_public_feed where id=old.id;
    return old;
  end if;

  if new.is_private=false
     and new.booking_type<>'open_join'
     and new.status in ('pending','confirmed','completed') then
    insert into public.booking_public_feed (
      id,stadium_id,stadium_name,stadium_image_url,start_time,end_time,operational_date,
      booking_type,player_team_id,player_team_name,player_team_logo_url,host_name,host_avatar_url,
      opponent_team_id,opponent_team_name,opponent_team_logo_url,is_private,rent_ball,total_price,currency,
      status,match_result_status,home_score,away_score,final_outcome,current_players,players_per_team,
      total_field_capacity,matchup_mode,matchup_closed_at,created_at,updated_at
    ) values (
      new.id,new.stadium_id,new.stadium_name,new.stadium_image_url,new.start_time,new.end_time,new.operational_date,
      new.booking_type,new.player_team_id,new.player_team_name,new.player_team_logo_url,new.host_name,new.host_avatar_url,
      new.opponent_team_id,new.opponent_team_name,new.opponent_team_logo_url,new.is_private,new.rent_ball,new.total_price,new.currency,
      new.status,new.match_result_status,new.home_score,new.away_score,new.final_outcome,new.current_players,new.max_players,
      new.total_field_capacity,new.matchup_mode,new.matchup_closed_at,new.created_at,new.updated_at
    )
    on conflict(id) do update set
      stadium_id=excluded.stadium_id,stadium_name=excluded.stadium_name,stadium_image_url=excluded.stadium_image_url,
      start_time=excluded.start_time,end_time=excluded.end_time,operational_date=excluded.operational_date,
      booking_type=excluded.booking_type,player_team_id=excluded.player_team_id,player_team_name=excluded.player_team_name,
      player_team_logo_url=excluded.player_team_logo_url,host_name=excluded.host_name,host_avatar_url=excluded.host_avatar_url,
      opponent_team_id=excluded.opponent_team_id,opponent_team_name=excluded.opponent_team_name,
      opponent_team_logo_url=excluded.opponent_team_logo_url,is_private=excluded.is_private,rent_ball=excluded.rent_ball,
      total_price=excluded.total_price,currency=excluded.currency,status=excluded.status,
      match_result_status=excluded.match_result_status,home_score=excluded.home_score,away_score=excluded.away_score,
      final_outcome=excluded.final_outcome,current_players=excluded.current_players,players_per_team=excluded.players_per_team,
      total_field_capacity=excluded.total_field_capacity,matchup_mode=excluded.matchup_mode,
      matchup_closed_at=excluded.matchup_closed_at,created_at=excluded.created_at,updated_at=excluded.updated_at;
  else
    delete from public.booking_public_feed where id=new.id;
  end if;
  return new;
end;
$function$;

-- 7. Fix SEC-05: set_config in respond_booking_reschedule_atomic
CREATE OR REPLACE FUNCTION public.respond_booking_reschedule_atomic(p_booking_id uuid, p_accept boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare b record; role_name text; new_total numeric; old_total numeric; duration_hours numeric; now_ts timestamptz:=now();
begin
 if auth.uid() is null then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 perform set_config('vsp.system_override', 'true', true);
 select * into b from public.bookings where id=p_booking_id for update;
 if not found then return jsonb_build_object('success',false,'error','BOOKING_NOT_FOUND'); end if;
 select role into role_name from public.users where id=auth.uid();
 if b.owner_id<>auth.uid() and b.user_id<>auth.uid() and b.created_by_user_id<>auth.uid()
    and coalesce(role_name,'') not in ('admin','co_founder','cofounder','super_admin')
 then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if b.status in ('cancelled','completed') then return jsonb_build_object('success',false,'error','BOOKING_NOT_RESCHEDULABLE'); end if;
 if b.reschedule_status<>'pending' or b.proposed_start_time is null or b.proposed_end_time is null
 then return jsonb_build_object('success',false,'error','NO_PENDING_RESCHEDULE'); end if;

 if not p_accept then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',true,'status','rejected','booking_id',p_booking_id);
 end if;

 if now_ts>=b.start_time then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','BOOKING_ALREADY_STARTED');
 end if;

 perform pg_advisory_xact_lock(hashtextextended(b.stadium_id::text,0));

 if exists(
   select 1 from public.bookings x
   where x.stadium_id=b.stadium_id and x.id<>b.id and x.status<>'cancelled'
     and x.start_time<b.proposed_end_time and x.end_time>b.proposed_start_time
 ) then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','SLOT_NO_LONGER_AVAILABLE');
 end if;

 duration_hours:=extract(epoch from(b.proposed_end_time-b.proposed_start_time))/3600;
 if duration_hours <= 0 or duration_hours > (select booking_max_duration_hours from public.platform_business_rules where id=1) then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','INVALID_DURATION');
 end if;

 select round(coalesce(s.price_per_hour,s.base_price,0)*duration_hours +
   case when b.rent_ball then coalesce((s.features->>'ballPrice')::numeric,0) else 0 end,2)
 into new_total
 from public.stadiums s where s.id=b.stadium_id for update;

 old_total:=round(coalesce(b.total_price,0),2);
 if new_total is null or new_total<=0 then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE');
 end if;

 if abs(new_total-old_total)>0.01 then
   update public.bookings set reschedule_status='rejected',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts where id=p_booking_id;
   return jsonb_build_object('success',false,'error','PRICE_CHANGE_REQUIRES_REBOOKING','old_total',old_total,'new_total',new_total);
 end if;

 update public.bookings set start_time=b.proposed_start_time,end_time=b.proposed_end_time,
   reschedule_status='accepted',proposed_start_time=null,proposed_end_time=null,updated_at=now_ts
 where id=p_booking_id;
 return jsonb_build_object('success',true,'status','accepted','booking_id',p_booking_id,'total_price',old_total);
end;
$function$;

-- 8. Fix FIN-06: auto_reconcile_all_past_bookings includes challenge/matchup/team
CREATE OR REPLACE FUNCTION public.auto_reconcile_all_past_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  UPDATE public.bookings
  SET status = 'completed',
      updated_at = NOW()
  WHERE end_time < NOW()
    AND status = 'confirmed'
    AND is_verified_by_owner IS TRUE;
END;
$function$;

-- 9. Fix FIN-04 & 5% owner cut in get_owner_financial_summary
CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller_role text;
  v_stadium_count int:=0;
  v_total_bookings int:=0;
  v_realized_online_rev numeric:=0;
  v_upcoming_online_rev numeric:=0;
  v_online_collected_rev numeric:=0;
  v_total_platform_fees numeric:=0;
  v_online_count int:=0;
  v_cash_revenue numeric:=0;
  v_cash_collected numeric:=0;
  v_cash_outstanding numeric:=0;
  v_cash_bookings int:=0;
  v_total_withdrawn numeric:=0;
  v_pending_payouts numeric:=0;
  v_available_balance numeric:=0;
  v_cash_debt numeric:=0;
  v_debt_limit numeric:=0;
  v_debt_blocked boolean:=false;
  v_now timestamptz:=timezone('utc',now());
  v_owner_rate numeric:=0.95; -- 5% deducted for VSP
begin
  if auth.uid() is not null and auth.uid()<>p_owner_id then
    select role into v_caller_role from public.users where id=auth.uid();
    if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    end if;
  end if;

  select count(*)::int into v_stadium_count from public.stadiums
  where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;

  select coalesce(sum((case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end) * v_owner_rate),0),
         coalesce(sum(coalesce(b.platform_fee,0)),0),
         count(*)::int
  into v_realized_online_rev, v_total_platform_fees, v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status in ('paid','partially_paid') or b.is_paid=true or coalesce(b.deposit_paid,0)>0)
    and b.status in ('completed','no_show')
    and b.booking_type <> 'maintenance';

  select coalesce(sum((case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end) * v_owner_rate),0)
    into v_online_collected_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status in ('paid','partially_paid') or b.is_paid=true or coalesce(b.deposit_paid,0)>0)
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select count(*)::int
    into v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select coalesce(sum((case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end) * v_owner_rate),0)
  into v_upcoming_online_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status in ('paid','partially_paid') or b.is_paid=true or coalesce(b.deposit_paid,0)>0)
    and b.status in ('confirmed','upcoming')
    and b.booking_type <> 'maintenance'
    and b.end_time>v_now;

  select coalesce(sum(
           case when (b.payment_status='paid' or b.is_paid=true)
                then greatest(coalesce(b.total_price,0),0)
                else greatest(coalesce(b.deposit_paid,0),0)
           end
         ),0),
         coalesce(sum(
           case when (b.total_price>0) then b.total_price else b.deposit_paid end
         ),0),
         count(*)::int
  into v_cash_collected,v_cash_revenue,v_cash_bookings
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))='cash'
    and b.status<>'cancelled';

  select coalesce(sum(
      case when not (b.payment_status='paid' or b.is_paid=true)
           then greatest(coalesce(b.total_price,0)-greatest(coalesce(b.deposit_paid,0),0),0)
           else 0 end
    ),0)
  into v_cash_outstanding
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))='cash'
    and b.status<>'cancelled';

  select count(*)::int into v_total_bookings
  from public.bookings
  where owner_id=p_owner_id
    and status<>'cancelled'
    and booking_type <> 'maintenance';

  select coalesce(sum(amount),0) into v_total_withdrawn from public.payout_settlements where owner_id=p_owner_id and status='completed';
  select coalesce(sum(amount),0) into v_pending_payouts from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');

  v_available_balance:=greatest(0,v_realized_online_rev-v_total_withdrawn-v_pending_payouts);

  select coalesce(accumulated_cash_debt,0),coalesce(debt_limit,0),coalesce(is_debt_blocked,false)
  into v_cash_debt,v_debt_limit,v_debt_blocked from public.users where id=p_owner_id;

  return jsonb_build_object(
    'success',true,'owner_id',p_owner_id,'stadium_count',v_stadium_count,
    'total_bookings_count',v_total_bookings,
    'realized_online_revenue',round(v_realized_online_rev,2),
    'upcoming_online_revenue',round(v_upcoming_online_rev,2),
    'online_collected_revenue',round(v_online_collected_rev,2),
    'net_online_earnings',round(v_realized_online_rev,2),
    'owner_online_earnings',round(v_realized_online_rev,2),
    'total_platform_fees',round(v_total_platform_fees,2),
    'total_withdrawn',round(v_total_withdrawn,2),
    'pending_payouts',round(v_pending_payouts,2),
    'available_balance',round(v_available_balance,2),
    'cash_revenue',round(v_cash_revenue,2),'cash_collected',round(v_cash_collected,2),
    'cash_outstanding',round(v_cash_outstanding,2),'cash_bookings_count',v_cash_bookings,
    'online_bookings_count',v_online_count,'accumulated_cash_debt',round(v_cash_debt,2),
    'debt_limit',round(v_debt_limit,2),'is_debt_blocked',v_debt_blocked
  );
end;
$function$;

-- 10. Fix FIN-04 & 5% owner cut in request_owner_payout_settlement_atomic
CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(
  p_owner_id uuid,
  p_amount numeric,
  p_method text DEFAULT 'instapay'::text,
  p_destination text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_owner record; v_pending_count int:=0; v_settlement_id uuid; v_caller_role text;
 v_now timestamptz:=timezone('utc',now()); v_online_earned numeric:=0;
 v_total_withdrawn numeric:=0; v_pending_payouts numeric:=0; v_available_balance numeric:=0;
 v_method text; v_destination text;
begin
 if auth.uid() is null and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','Authentication required'); end if;
 if auth.uid() is not null and auth.uid()<>p_owner_id and current_user not in ('postgres','service_role') then
  select role into v_caller_role from public.users where id=auth.uid();
  if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then return jsonb_build_object('success',false,'error','Unauthorized payout request'); end if;
 end if;
 if p_amount is null or p_amount<=0 then return jsonb_build_object('success',false,'error','يجب أن يكون مبلغ السحب أكبر من الصفر.'); end if;
 select * into v_owner from public.users where id=p_owner_id for update;
 if not found then return jsonb_build_object('success',false,'error','حساب المالك غير موجود.'); end if;

 v_method:=lower(trim(coalesce(p_method,'')));
 v_method:=case v_method when 'wallet' then 'vodafone_cash' when 'vodafone' then 'vodafone_cash' when 'bank' then 'bank_transfer' else v_method end;
 if v_method not in ('instapay','vodafone_cash','bank_transfer') then return jsonb_build_object('success',false,'error','وسيلة السحب غير مدعومة.'); end if;

 v_destination:=case v_method
  when 'instapay' then trim(coalesce(v_owner.p2p_instapay,''))
  when 'vodafone_cash' then trim(coalesce(v_owner.p2p_vodafone,''))
  when 'bank_transfer' then trim(coalesce(v_owner.p2p_bank,''))
 end;
 if v_destination='' then return jsonb_build_object('success',false,'error','بيانات جهة التحويل لهذه الوسيلة غير مسجلة في حسابك.'); end if;
 if p_destination is not null and trim(p_destination)<>'' and trim(p_destination)<>v_destination then
  return jsonb_build_object('success',false,'error','بيانات جهة التحويل تغيرت عن البيانات المسجلة. حدّث إعدادات الحساب ثم أعد المحاولة.'); end if;

 select count(*) into v_pending_count from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 if v_pending_count>0 then return jsonb_build_object('success',false,'error','لديك طلب سحب قيد المراجعة بالفعل.'); end if;

 select coalesce(sum((case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end) * 0.95),0)
 into v_online_earned
 from public.bookings b
 where b.owner_id=p_owner_id
   and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
   and (b.payment_status in ('paid','partially_paid') or b.is_paid=true or coalesce(b.deposit_paid,0)>0)
   and b.status in ('completed','no_show');

 select coalesce(sum(amount),0) into v_total_withdrawn from public.payout_settlements where owner_id=p_owner_id and status='completed';
 select coalesce(sum(amount),0) into v_pending_payouts from public.payout_settlements where owner_id=p_owner_id and status in ('pending','approved');
 v_available_balance:=greatest(0,v_online_earned-v_total_withdrawn-v_pending_payouts);

 if round(p_amount,2)>round(v_available_balance,2)+0.01 then
  return jsonb_build_object('success',false,'error','المبلغ المطلوب ('||round(p_amount,2)||' ج.م) يتجاوز رصيدك المتاح للسحب ('||round(v_available_balance,2)||' ج.م).','available_balance',round(v_available_balance,2));
 end if;

 insert into public.payout_settlements(owner_id,amount,method,destination,status,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),v_method,v_destination,'pending',v_now,v_now) returning id into v_settlement_id;

 insert into public.transactions(user_id,amount,type,status,payment_method,metadata,created_at,updated_at)
 values(p_owner_id,round(p_amount,2),'payout_pending','pending',v_method,
 jsonb_build_object('settlement_id',v_settlement_id,'destination',v_destination,'owner_name',coalesce(v_owner.name,'Unknown Owner'),
 'owner_phone',coalesce(v_owner.phone,''),'remaining_balance_after',round(v_available_balance-p_amount,2)),v_now,v_now);

 insert into public.notifications(user_id,title,body,type,is_read,created_at)
 select id,'طلب سحب أرباح جديد','طلب المالك '||coalesce(v_owner.name,'مالك')||' سحب '||round(p_amount,2)||' ج.م عبر '||v_method,'payout',false,v_now
 from public.users where role in ('admin','co_founder','cofounder','super_admin');

 return jsonb_build_object('success',true,'settlement_id',v_settlement_id,'available_balance',round(v_available_balance-p_amount,2),
 'method',v_method,'destination',v_destination,'message','تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.');
end;
$function$;

COMMIT;
