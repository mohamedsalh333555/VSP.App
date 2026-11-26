-- =============================================================
-- VSP Phase 2C: Cairo Cron Rollover, 100% Owner Award Reimbursement,
-- and 1v1 Write RPC Retirement
-- Migration: 20261126060000_cron_and_1v1_rpc_sunset.sql
-- =============================================================
BEGIN;

-- 1. Update get_owner_financial_summary & request_owner_payout_settlement_atomic
--    so VSP-funded Monthly Free Hour bookings ('vsp_monthly_award') pay owner 100%
--    without deducting the 5% owner commission (Section 6: owner bears 0 cost).
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
begin
  if auth.uid() is not null and auth.uid()<>p_owner_id then
    select role into v_caller_role from public.users where id=auth.uid();
    if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    end if;
  end if;

  select count(*)::int into v_stadium_count from public.stadiums
  where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;

  select coalesce(sum(
           (case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end)
           * (case when b.payment_method = 'vsp_monthly_award' then 1.0 else 0.95 end)
         ),0),
         coalesce(sum(coalesce(b.platform_fee,0)),0),
         count(*)::int
  into v_realized_online_rev, v_total_platform_fees, v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status in ('paid','partially_paid') or b.is_paid=true or coalesce(b.deposit_paid,0)>0)
    and b.status in ('completed','no_show')
    and b.booking_type <> 'maintenance';

  select coalesce(sum(
           (case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end)
           * (case when b.payment_method = 'vsp_monthly_award' then 1.0 else 0.95 end)
         ),0)
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

  select coalesce(sum(
           (case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end)
           * (case when b.payment_method = 'vsp_monthly_award' then 1.0 else 0.95 end)
         ),0)
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

 select coalesce(sum(
   (case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end)
   * (case when b.payment_method = 'vsp_monthly_award' then 1.0 else 0.95 end)
 ),0)
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

-- 2. Cairo-aware hourly cron dispatcher (handles DST automatically via Africa/Cairo!)
CREATE OR REPLACE FUNCTION public.vsp_cairo_season_cron_tick()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_cairo_now timestamp := now() AT TIME ZONE 'Africa/Cairo';
  v_season    public.competition_seasons;
  v_prev_mon  text;
BEGIN
  SELECT * INTO v_season FROM public.vsp_get_active_season();
  IF v_season.id IS NULL OR now() < v_season.starts_at THEN
    RETURN;
  END IF;

  -- On the 1st of any Cairo month (during the first hour), close the just-ended month idempotently
  IF EXTRACT(DAY FROM v_cairo_now) = 1 AND EXTRACT(HOUR FROM v_cairo_now) = 0 THEN
    v_prev_mon := to_char((v_cairo_now - interval '1 day'), 'YYYY-MM');
    PERFORM public.close_monthly_ranking_period(v_prev_mon);
  END IF;

  -- On Jan 1st 00:xx Cairo time, roll over the closed calendar year idempotently
  IF EXTRACT(MONTH FROM v_cairo_now) = 1 AND EXTRACT(DAY FROM v_cairo_now) = 1
     AND now() > v_season.ends_at THEN
    PERFORM public.rollover_annual_season_atomic(v_season.id, EXTRACT(YEAR FROM v_cairo_now)::int);
  END IF;
END;
$$;

DO $$
BEGIN
  PERFORM cron.unschedule('vsp-cairo-season-tick');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
  'vsp-cairo-season-tick',
  '5 * * * *',
  $$SELECT public.vsp_cairo_season_cron_tick();$$
);

-- 3. Disable standalone 1v1 creation/registration RPCs while preserving read/refund paths
DO $$
DECLARE
  fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'admin_create_1v1_tournament_atomic',
    'save_and_publish_1v1_tournament_atomic',
    'create_1v1_payment_order_atomic',
    'join_1v1_tournament_atomic'
  ]
  LOOP
    BEGIN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION public.%I FROM PUBLIC, anon, authenticated', fn);
    EXCEPTION WHEN undefined_function THEN NULL;
    END;
  END LOOP;
END $$;

COMMIT;
