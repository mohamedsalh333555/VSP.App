-- P0 Security Definer & Privilege Hardening Migration
-- Eliminates insecure current_user checks across all SECURITY DEFINER functions/triggers,
-- closes auth.uid() IS NULL gaps, enables security_invoker on financial views,
-- fixes pre-login get_server_timestamp() 42501 error, and fixes admin_cancel_booking_atomic arg order.
BEGIN;

CREATE OR REPLACE FUNCTION public.vsp_is_service_or_db_owner()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_jwt_role text := COALESCE(auth.jwt()->>'role', NULLIF(current_setting('request.jwt.claim.role', true), ''), '');
  v_jwt_claims text := COALESCE(NULLIF(current_setting('request.jwt.claims', true), ''), '');
  v_sql_role text := COALESCE(NULLIF(current_setting('role', true), ''), 'none');
BEGIN
  IF v_jwt_role = 'service_role' THEN
    RETURN true;
  END IF;
  IF auth.uid() IS NULL
     AND v_jwt_claims = ''
     AND session_user IN ('postgres', 'supabase_admin')
     AND v_sql_role IN ('none', 'postgres', 'supabase_admin', 'service_role') THEN
    RETURN true;
  END IF;
  RETURN false;
END;
$function$;

REVOKE ALL ON FUNCTION public.vsp_is_service_or_db_owner() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vsp_is_service_or_db_owner() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.require_owner_or_active_admin_actor(p_owner_id uuid)
RETURNS void
LANGUAGE plpgsql
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NOT NULL AND v_uid = p_owner_id
     AND EXISTS(SELECT 1 FROM public.users u WHERE u.id = v_uid AND COALESCE(u.is_blocked, false) = false) THEN
    RETURN;
  END IF;
  PERFORM public.require_active_admin_actor();
END;
$function$;

REVOKE ALL ON FUNCTION public.require_active_admin_actor() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.require_active_admin_actor() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.require_owner_or_active_admin_actor(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.require_owner_or_active_admin_actor(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vsp_assert_admin_or_service_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vsp_assert_admin_or_service_role() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.import_paymob_reconciliation_row(p_paymob_txn_id text, p_actual_fee numeric, p_channel_class text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role TEXT;
  v_jwt_role TEXT := coalesce(auth.role(), '');
  v_tx record;
  v_diff NUMERIC(10,2);
  v_status TEXT;
BEGIN
  PERFORM public.require_active_admin_actor();

  SELECT * INTO v_tx FROM public.transactions WHERE paymob_transaction_id = p_paymob_txn_id LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'transaction_not_found');
  END IF;

  v_diff := round(coalesce(v_tx.gateway_fee_collected, (v_tx.metadata->>'gateway_fee')::numeric, 0) - coalesce(p_actual_fee, 0), 2);
  v_status := CASE WHEN abs(v_diff) <= 0.05 THEN 'matched' ELSE 'mismatch' END;

  UPDATE public.transactions
  SET paymob_actual_fee = p_actual_fee,
      reconciliation_diff = v_diff,
      reconciliation_status = v_status,
      payment_channel_class = coalesce(p_channel_class, payment_channel_class),
      updated_at = timezone('utc', now())
  WHERE id = v_tx.id;

  IF v_tx.booking_id IS NOT NULL THEN
    UPDATE public.bookings
    SET paymob_actual_fee = p_actual_fee,
        reconciliation_diff = v_diff,
        reconciliation_status = v_status,
        payment_channel_class = coalesce(p_channel_class, payment_channel_class),
        updated_at = timezone('utc', now())
    WHERE id = v_tx.booking_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_tx.id,
    'booking_id', v_tx.booking_id,
    'gateway_fee_collected', coalesce(v_tx.gateway_fee_collected, 0),
    'paymob_actual_fee', p_actual_fee,
    'reconciliation_diff', v_diff,
    'reconciliation_status', v_status
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_method text DEFAULT 'instapay'::text, p_destination text DEFAULT ''::text)
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
 IF NOT public.vsp_is_service_or_db_owner() THEN
  IF auth.uid() IS NULL THEN
   RETURN jsonb_build_object('success',false,'error','Authentication required');
  END IF;
  IF auth.uid() <> p_owner_id AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
   RETURN jsonb_build_object('success',false,'error','Unauthorized payout request');
  END IF;
  IF auth.uid() = p_owner_id AND EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND COALESCE(u.is_blocked, false) = true) THEN
   RETURN jsonb_build_object('success',false,'error','Account is blocked');
  END IF;
 END IF;
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
$function$
;

CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_stadium record; v_role text; v_actual_owner_id uuid; v_authorized boolean:=false;
v_duration numeric; v_server_total numeric; v_collected numeric; v_booking_id uuid; v_tx_id uuid; v_ref text; v_now timestamptz:=now();
begin
select * into v_stadium from public.stadiums where id=p_stadium_id for update;
if not found then return jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND'); end if;
v_actual_owner_id:=v_stadium.owner_id;
if v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) or coalesce(v_stadium.is_verified,false) is false then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
if public.vsp_is_service_or_db_owner()
   or (auth.uid() is not null and v_actual_owner_id = auth.uid() and exists (select 1 from public.users u where u.id = auth.uid() and coalesce(u.is_blocked, false) = false))
   or (auth.uid() is not null and public.is_admin_or_cofounder(auth.uid())) then
  v_authorized := true;
end if;
if not v_authorized then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
if p_end_time<=p_start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
v_duration:=extract(epoch from(p_end_time-p_start_time))/3600;
if v_duration<=0 or v_duration>(select manual_booking_max_duration_hours from public.platform_business_rules where id=1) then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
v_server_total:=round(coalesce(v_stadium.price_per_hour,v_stadium.base_price,0)*v_duration,2);
if v_server_total<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
if abs(coalesce(p_total_price,0)-v_server_total)>0.01 then return jsonb_build_object('success',false,'error','PRICE_MISMATCH','expected_total_price',v_server_total); end if;
v_collected:=round(coalesce(p_collected_amount,0),2);
if v_collected < 0 or v_collected > v_server_total then
  return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT');
end if;
if p_start_time<v_now-(select booking_past_grace_minutes from public.platform_business_rules where id=1)*interval '1 minute' then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
perform pg_advisory_xact_lock(hashtextextended(p_stadium_id::text,0));
if exists(select 1 from public.bookings b where b.stadium_id=p_stadium_id and b.status<>'cancelled' and p_start_time<b.end_time and p_end_time>b.start_time) then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end if;
v_ref:='MANUAL_'||replace(gen_random_uuid()::text,'-','');
perform set_config('vsp.manual_booking_workflow','true',true);
insert into public.bookings(stadium_id,stadium_name,owner_id,user_id,created_by_user_id,start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,total_price,vsp_commission,gateway_fee,platform_fee,deposit_paid,is_deposit_paid,is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,is_private,rent_ball,created_at,updated_at)
values(
  p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,coalesce(auth.uid(),v_actual_owner_id),
  p_start_time,p_end_time,'personal',nullif(trim(p_customer_name),''),nullif(trim(p_customer_name),''),
  nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),v_server_total,0,0,0,
  v_collected,v_collected>0,v_collected>=v_server_total,
  case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'cash',v_ref,'confirmed',null,true,false,v_now,v_now
)
returning id into v_booking_id;
insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,reference_number,description,metadata,created_at,updated_at)
values(v_actual_owner_id,v_booking_id,v_collected,'cash_settlement','completed','cash',v_ref,'تحصيل نقدي لحجز يدوي',jsonb_build_object('principal_amount',v_collected,'gross_amount',v_collected,'vsp_fee',0,'gateway_fee',0,'total_payment_fees',0,'server_recorded_at',v_now),v_now,v_now)
returning id into v_tx_id;
perform set_config('vsp.manual_booking_workflow','',true);
return jsonb_build_object(
  'success',true,
  'booking_id',v_booking_id,
  'total_price',v_server_total,
  'collected_amount',v_collected,
  'remaining_amount',greatest(v_server_total-v_collected,0),
  'payment_status',case when v_collected>=v_server_total then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end,
  'transaction_id',v_tx_id
);
exception when others then perform set_config('vsp.manual_booking_workflow','',true); return jsonb_build_object('success',false,'error',sqlerrm,'error_code',sqlstate);
end; $function$
;

CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0, p_idempotency_key text DEFAULT NULL::text, p_initial_players integer DEFAULT 1, p_total_capacity integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium record;
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_duration_hours numeric;
  v_calculated_price numeric;
  v_hourly_rate numeric;
  v_ball_price numeric := 0;
  v_final_total_price numeric;
  v_final_needs_deposit boolean;
  v_final_deposit_amount numeric;
  v_final_deposit_paid numeric := 0;
  v_final_status text;
  v_final_is_paid boolean;
  v_locked_until timestamptz;
  v_active_cash_count int := 0;
  v_conflict_count int := 0;
  v_user_blocked boolean;
  v_no_show_count int;
  v_new_booking_id uuid;
  v_existing_id uuid;
  v_existing_status text;
  v_now timestamptz := timezone('utc', now());
  v_initial_players int;
  v_capacity int;
  v_raw_type text;
  v_normalized_type text;
BEGIN
  v_raw_type := lower(trim(coalesce(p_booking_type,'')));
  IF v_raw_type='openjoin' THEN v_raw_type:='open_join'; END IF;

  IF v_raw_type NOT IN ('personal','open_join','challenge') THEN
    RETURN jsonb_build_object('success',false,'code','INVALID_BOOKING_TYPE','message','نوع الحجز غير صالح.');
  END IF;

  IF v_raw_type='challenge' THEN
    RETURN jsonb_build_object('success',false,'code','USE_CHALLENGE_RPC','message','حجوزات التحدي تتم عبر create_challenge_booking_atomic فقط.');
  END IF;

  v_normalized_type:=v_raw_type;

  IF v_caller IS NULL AND NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success',false,'message','يجب تسجيل الدخول أولاً.');
  END IF;

  IF v_caller IS NOT NULL THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id=v_caller;
    IF NOT public.vsp_is_service_or_db_owner()
       AND v_caller::text<>p_user_id
       AND NOT public.is_admin_or_cofounder(v_caller) THEN
      RETURN jsonb_build_object('success',false,'message','غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
    END IF;
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id,status INTO v_existing_id,v_existing_status
    FROM public.bookings
    WHERE idempotency_key=p_idempotency_key AND status<>'cancelled'
    LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('success',true,'booking_id',v_existing_id,'status',v_existing_status,'idempotent',true);
    END IF;
  END IF;

  v_duration_hours:=extract(epoch from(p_end_time-p_start_time))/3600.0;
  IF v_duration_hours<=0 THEN
    RETURN jsonb_build_object('success',false,'message','وقت بداية ونهاية الحجز غير صالح.');
  END IF;

  IF v_duration_hours<((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id=1)/60.0)
     OR v_duration_hours>(SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id=1) THEN
    RETURN jsonb_build_object('success',false,'message','مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id,0));

  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text=p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'message','الملعب المطلوب غير موجود.'); END IF;
  IF v_stadium.is_deleted_by_owner THEN RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب محذوف.'); END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success',false,'message','عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;


  IF NOT public.vsp_validate_stadium_booking_window(
    v_stadium.opening_time,
    v_stadium.closing_time,
    v_stadium.break_start_time,
    v_stadium.break_end_time,
    v_stadium.is_split_shift,
    v_stadium.maintenance_until,
    p_start_time,
    p_end_time
  ) THEN
    RETURN jsonb_build_object(
      'success',false,
      'code','OUTSIDE_OPERATING_HOURS',
      'message','موعد الحجز خارج ساعات تشغيل الملعب أو يتعارض مع فترة التوقف أو الصيانة.'
    );
  END IF;



  SELECT is_blocked,coalesce(no_show_count,0)
  INTO v_user_blocked,v_no_show_count
  FROM public.users WHERE id::text=p_user_id;

  IF coalesce(v_user_blocked,false) THEN
    RETURN jsonb_build_object('success',false,'message','حسابك مقيد حالياً.');
  END IF;

  IF lower(coalesce(p_payment_method,'')) NOT IN ('paymob','card','wallet','online') THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ONLINE_PAYMENT_REQUIRED',
      'message', 'الحجز عبر التطبيق متاح بالدفع الإلكتروني الكامل فقط.'
    );
  END IF;

  SELECT COUNT(*) INTO v_active_cash_count
  FROM public.bookings
  WHERE (user_id::text=p_user_id OR created_by_user_id::text=p_user_id)
    AND lower(coalesce(payment_method,''))='cash'
    AND status IN('pending','confirmed')
    AND coalesce(is_paid,false)=false
    AND end_time>v_now;

  IF lower(coalesce(p_payment_method,''))='cash' AND v_active_cash_count>0 THEN
    RETURN jsonb_build_object(
      'success',false,'code','ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online',true,
      'message','لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.'
    );
  END IF;

  v_final_needs_deposit:=false;
  v_final_deposit_amount:=0;

  -- A stadium that requires an upfront deposit must never allow a cash booking.
  -- The deposit is an online prepayment requirement; the server is authoritative.
  IF lower(coalesce(p_payment_method,''))='cash'
     AND v_final_needs_deposit
     AND v_final_deposit_amount > 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'code', 'ONLINE_DEPOSIT_REQUIRED',
      'requires_online_deposit', true,
      'deposit_amount', v_final_deposit_amount,
      'message', 'هذا الملعب يتطلب دفع العربون إلكترونياً لتأكيد الحجز.'
    );
  END IF;
  v_hourly_rate:=coalesce(v_stadium.price_per_hour,v_stadium.base_price,0);
  v_calculated_price:=round(v_hourly_rate*v_duration_hours,2);

  IF p_rent_ball THEN
    BEGIN
      v_ball_price:=coalesce((v_stadium.features->>'ballPrice')::numeric,0);
    EXCEPTION WHEN OTHERS THEN
      v_ball_price:=0;
    END;
    v_calculated_price:=v_calculated_price+v_ball_price;
  END IF;

  IF v_calculated_price<=0 THEN
    RETURN jsonb_build_object('success',false,'message','تسعيرة الملعب غير صحيحة.');
  END IF;

  v_final_total_price:=v_calculated_price;

  IF lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online') THEN
    v_final_status:='pending';
    v_final_is_paid:=false;
    v_locked_until:=v_now+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval;
  ELSE
    v_final_status:='confirmed';
    v_final_is_paid:=false;
    v_locked_until:=NULL;
  END IF;

  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text=p_stadium_id AND status<>'cancelled'
    AND NOT(status='pending' AND coalesce(locked_until,created_at+((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id=1)||' minutes')::interval)<v_now)
    AND p_start_time<end_time AND p_end_time>start_time;

  IF v_conflict_count>0 THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، هذا الموعد محجوز أو قيد الدفع من لاعب آخر حالياً.');
  END IF;

  IF v_normalized_type='open_join' THEN
    v_initial_players:=coalesce(p_initial_players,1);

    IF v_initial_players<1 THEN
      RETURN jsonb_build_object('success',false,'code','INVALID_INITIAL_PLAYERS','message','عدد اللاعبين المبدئي يجب أن يكون 1 على الأقل.');
    END IF;

    v_capacity:=v_stadium.total_field_capacity;

    IF v_capacity IS NULL OR v_capacity<1 THEN
      RETURN jsonb_build_object('success',false,'code','STADIUM_CAPACITY_NOT_CONFIGURED','message','هذا الملعب لا تتوفر له سعة محددة. لا يمكن إنشاء الحجز التجميعي حتى يقوم المالك بتحديد السعة.');
    END IF;

    IF v_initial_players>v_capacity THEN
      RETURN jsonb_build_object('success',false,'code','INITIAL_PLAYERS_EXCEED_CAPACITY','message','عدد اللاعبين المبدئي ('||v_initial_players||') لا يمكن أن يتجاوز سعة الملعب ('||v_capacity||').');
    END IF;
  ELSE
    v_initial_players:=1;
    v_capacity:=NULL;
  END IF;

  INSERT INTO public.bookings(
    stadium_id,user_id,created_by_user_id,owner_id,
    start_time,end_time,booking_type,total_price,vsp_commission,gateway_fee,platform_fee,
    stadium_name,stadium_image_url,is_private,rent_ball,
    needs_deposit,deposit_amount,deposit_paid,
    payment_method,payment_status,status,is_paid,
    player_team_id,player_team_name,opponent_team_id,opponent_team_name,challenge_status,
    joined_user_ids,current_players,initial_players_count,manual_player_count,total_field_capacity,
    locked_until,idempotency_key,created_at,updated_at
  ) VALUES(
    p_stadium_id::uuid,p_user_id::uuid,p_user_id::uuid,v_stadium.owner_id,
    p_start_time,p_end_time,v_normalized_type,
    v_final_total_price,0,0,0,
    v_stadium.name,v_stadium.image_url,
    case when v_normalized_type='open_join' then true else p_is_private end,
    p_rent_ball,
    v_final_needs_deposit,v_final_deposit_amount,v_final_deposit_paid,
    lower(coalesce(p_payment_method,'cash')),'pending',v_final_status,v_final_is_paid,
    case when p_player_team_id~'^[0-9a-fA-F-]{36}$' then p_player_team_id::uuid else null end,
    p_player_team_name,
    case when p_opponent_team_id~'^[0-9a-fA-F-]{36}$' then p_opponent_team_id::uuid else null end,
    p_opponent_team_name,
    null,
    ARRAY[p_user_id::uuid],
    v_initial_players,
    v_initial_players,
    case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    v_capacity,
    v_locked_until,p_idempotency_key,v_now,v_now
  )
  RETURNING id INTO v_new_booking_id;

  RETURN jsonb_build_object(
    'success',true,
    'booking_id',v_new_booking_id,
    'status',v_final_status,
    'total_price',v_final_total_price,
    'needs_deposit',v_final_needs_deposit,
    'deposit_amount',v_final_deposit_amount,
    'initial_players',v_initial_players,
    'manual_player_count',case when v_normalized_type='open_join' then greatest(v_initial_players-1,0) else 0 end,
    'total_capacity',v_capacity,
    'requires_full_online',(v_active_cash_count>0 AND lower(coalesce(p_payment_method,'')) IN ('paymob','card','wallet','online')),
    'locked_until',v_locked_until
  );
EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success',false,'code','SLOT_LOCKED_OR_TAKEN','message','عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_challenge_booking_atomic(p_challenge_code text, p_stadium_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_payment_method text DEFAULT 'cash'::text, p_rent_ball boolean DEFAULT false, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller                 uuid := auth.uid();
  v_caller_role            text;
  v_caller_team            record;
  v_code_entry             record;
  v_opponent_team          record;
  v_stadium                record;
  v_duration_hours         numeric;
  v_hourly_rate            numeric;
  v_price                  numeric;
  v_ball_price             numeric := 0;
  v_final_status           text;
  v_final_challenge_status text;
  v_final_is_paid          boolean;
  v_locked_until           timestamptz;
  v_conflict_count         int;
  v_active_cash_cnt        int := 0;
  v_user_blocked           boolean;
  v_no_show_count          int;
  v_new_booking_id         uuid;
  v_new_code               text;
  v_new_code_id            uuid;
  v_existing_id            uuid;
  v_existing_status        text;
  v_existing_user_id       uuid;
  v_clean_code             text;
  v_now                    timestamptz := timezone('utc', now());
BEGIN
  -- 1. Authentication check
  IF v_caller IS NULL AND NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success', false, 'error', 'AUTH_REQUIRED',
      'message', 'يجب تسجيل الدخول أولاً.');
  END IF;

  -- 2. Strengthened User-Scoped Idempotency protection
  IF p_idempotency_key IS NOT NULL AND trim(p_idempotency_key) <> '' THEN
    SELECT id, status, user_id INTO v_existing_id, v_existing_status, v_existing_user_id
    FROM public.bookings
    WHERE idempotency_key = trim(p_idempotency_key) AND status <> 'cancelled' LIMIT 1;
    IF FOUND THEN
      IF v_existing_user_id IS NOT NULL AND v_caller IS NOT NULL AND v_existing_user_id <> v_caller THEN
        RETURN jsonb_build_object(
          'success', false,
          'error',   'IDEMPOTENCY_KEY_COLLISION',
          'message', 'مفتاح العملية غير صالح أو مستخدم مسبقاً لحساب آخر.'
        );
      END IF;

      RETURN jsonb_build_object(
        'success',     true,
        'booking_id',  v_existing_id,
        'status',      v_existing_status,
        'idempotent',  true
      );
    END IF;
  END IF;

  -- Normalize challenge code (strip 'VSP-' prefix if provided)
  v_clean_code := upper(trim(COALESCE(p_challenge_code, '')));
  IF v_clean_code LIKE 'VSP-%' THEN
    v_clean_code := substring(v_clean_code from 5);
  END IF;

  IF v_clean_code = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'EMPTY_CHALLENGE_CODE',
      'message', 'يرجى إدخال كود التحدي.');
  END IF;

  -- 3. Verify caller is a captain of an active team
  SELECT t.* INTO v_caller_team 
  FROM public.teams t 
  WHERE t.captain_id = v_caller 
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_NOT_A_CAPTAIN',
      'message', 'يجب أن تكون كابتن فريق لإنشاء حجز تحدي.');
  END IF;

  -- 4. Verify & lock challenge code (match either raw code or with prefix)
  SELECT * INTO v_code_entry
  FROM public.team_challenge_codes
  WHERE (code = v_clean_code OR code = 'VSP-' || v_clean_code) AND status = 'active'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_INVALID_OR_USED',
      'message', 'كود التحدي غير صالح أو تم استخدامه مسبقاً.');
  END IF;

  IF v_code_entry.expires_at IS NOT NULL AND v_code_entry.expires_at < v_now THEN
    UPDATE public.team_challenge_codes SET status = 'expired' WHERE id = v_code_entry.id;
    RETURN jsonb_build_object('success', false, 'error', 'CHALLENGE_CODE_EXPIRED',
      'message', 'كود التحدي منتهي الصلاحية.');
  END IF;

  -- 5. Opponent team validation & Server-Side Eligibility
  SELECT * INTO v_opponent_team FROM public.teams WHERE id = v_code_entry.team_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_NOT_FOUND',
      'message', 'تعذر العثور على الفريق صاحب الكود.');
  END IF;

  IF v_caller_team.id = v_opponent_team.id THEN
    RETURN jsonb_build_object('success', false, 'error', 'CANNOT_CHALLENGE_OWN_TEAM',
      'message', 'لا يمكنك تحدي فريقك نفسه.');
  END IF;

  -- Server-Side FairPlay Eligibility (attendance_score >= 40)
  IF COALESCE(v_caller_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'CALLER_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'فريقك مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  IF COALESCE(v_opponent_team.attendance_score, 100) < 40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'OPPONENT_TEAM_FAIRPLAY_RESTRICTED',
      'message', 'الفريق المنافس مقيد من خوض مباريات التحدي بسبب انخفاض نقاط اللعب النظيف.');
  END IF;

  -- 6. Platform business rules: Duration check
  v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
  IF v_duration_hours <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_TIME_RANGE',
      'message', 'وقت بداية ونهاية الحجز غير صالح.');
  END IF;
  IF v_duration_hours < ((SELECT booking_min_duration_minutes FROM public.platform_business_rules WHERE id = 1) / 60.0)
     OR v_duration_hours > (SELECT booking_max_duration_hours FROM public.platform_business_rules WHERE id = 1)
  THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_DURATION',
      'message', 'مدة الحجز غير صالحة وفق قواعد المنصة.');
  END IF;

  -- 7. Advisory lock per stadium to serialize slot bookings
  PERFORM pg_advisory_xact_lock(hashtextextended(p_stadium_id, 0));

  -- 8. Validate stadium
  SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_NOT_FOUND',
      'message', 'الملعب المطلوب غير موجود.');
  END IF;
  IF COALESCE(v_stadium.is_deleted_by_owner, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_DELETED',
      'message', 'عذراً، هذا الملعب محذوف.');
  END IF;
  IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_UNAVAILABLE',
      'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً.');
  END IF;

  -- 9. User Account & Cash Rules (Same SSOT as create_booking_atomic)
  SELECT is_blocked, COALESCE(no_show_count, 0)
  INTO v_user_blocked, v_no_show_count
  FROM public.users WHERE id = v_caller;
  IF COALESCE(v_user_blocked, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_BLOCKED',
      'message', 'حسابك مقيد حالياً.');
  END IF;

  IF lower(COALESCE(p_payment_method, '')) NOT IN ('paymob', 'card', 'wallet', 'online') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'ONLINE_PAYMENT_REQUIRED',
      'message', 'الحجز عبر التطبيق متاح بالدفع الإلكتروني الكامل فقط.'
    );
  END IF;

  -- Cash policy: Only UNPAID active cash bookings block a new cash booking
  SELECT COUNT(*) INTO v_active_cash_cnt
  FROM public.bookings
  WHERE (user_id = v_caller OR created_by_user_id = v_caller)
    AND lower(COALESCE(payment_method, '')) = 'cash'
    AND status IN ('pending', 'confirmed') 
    AND COALESCE(is_paid, false) = false
    AND end_time > v_now;

  IF lower(COALESCE(p_payment_method, 'cash')) = 'cash' AND v_active_cash_cnt > 0 THEN
    RETURN jsonb_build_object('success', false, 'code', 'ACTIVE_CASH_BOOKING_EXISTS',
      'requires_full_online', true,
      'message', 'لديك حجز نقدي غير مسدد قائم بالفعل. يرجى سداده أولاً أو الدفع إلكترونياً.');
  END IF;

  -- 10. Authoritative Server-Side Pricing
  v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
  v_price := ROUND(v_hourly_rate * v_duration_hours, 2);
  IF p_rent_ball THEN
    BEGIN v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0);
    EXCEPTION WHEN OTHERS THEN v_ball_price := 0; END;
    v_price := v_price + v_ball_price;
  END IF;
  IF v_price <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'STADIUM_PRICE_NOT_SET',
      'message', 'تسعيرة الملعب غير صحيحة.');
  END IF;

  -- 11. Slot conflict check
  SELECT COUNT(*) INTO v_conflict_count
  FROM public.bookings
  WHERE stadium_id::text = p_stadium_id AND status <> 'cancelled'
    AND NOT (status = 'pending'
      AND COALESCE(locked_until, created_at + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval) < v_now)
    AND p_start_time < end_time AND p_end_time > start_time;

  IF v_conflict_count > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع حالياً.');
  END IF;

  -- 12. Status and Payment Lock Window: Perfect SSOT State Alignment
  IF lower(COALESCE(p_payment_method, 'cash')) IN ('paymob', 'card', 'wallet', 'online') THEN
    v_final_status           := 'pending';
    v_final_challenge_status := 'ready';       -- Ready, awaiting payment confirmation
    v_final_is_paid          := false;
    v_locked_until           := v_now + ((SELECT payment_lock_minutes FROM public.platform_business_rules WHERE id = 1) || ' minutes')::interval;
  ELSE
    v_final_status           := 'confirmed';
    v_final_challenge_status := 'confirmed';   -- Confirmed immediately for cash
    v_final_is_paid          := false;
    v_locked_until           := NULL;
  END IF;

  -- 13. Insert Booking (Player counters are strictly NULL for Challenge matches)
  INSERT INTO public.bookings (
    stadium_id, user_id, created_by_user_id, owner_id,
    start_time, end_time, booking_type,
    total_price, platform_fee, vsp_commission, gateway_fee,
    stadium_name, stadium_image_url,
    is_private, rent_ball,
    needs_deposit, deposit_amount, deposit_paid,
    payment_method, payment_status, status, is_paid,
    player_team_id, player_team_name,
    opponent_team_id, opponent_team_name,
    challenge_status,
    joined_user_ids, current_players, initial_players_count, total_field_capacity,
    locked_until, idempotency_key,
    created_at, updated_at
  ) VALUES (
    p_stadium_id::uuid, v_caller, v_caller, v_stadium.owner_id,
    p_start_time, p_end_time, 'challenge',
    v_price, 0, 0, 0,
    v_stadium.name, v_stadium.image_url,
    true, p_rent_ball,
    false,
    0,
    0,
    lower(COALESCE(p_payment_method, 'cash')), 'pending',
    v_final_status, v_final_is_paid,
    v_caller_team.id, v_caller_team.name,
    v_opponent_team.id, v_opponent_team.name,
    v_final_challenge_status,
    ARRAY[v_caller], NULL, NULL, NULL,
    v_locked_until, p_idempotency_key,
    v_now, v_now
  )
  RETURNING id INTO v_new_booking_id;

  -- 14. Consume challenge code
  UPDATE public.team_challenge_codes
  SET status = 'used', used_at = v_now, used_in_booking_id = v_new_booking_id
  WHERE id = v_code_entry.id;

  -- 15. Generate fresh replacement challenge code for opponent team with 7-day expiration
  v_new_code := public._generate_unique_challenge_code();
  INSERT INTO public.team_challenge_codes(team_id, code, status, created_at, expires_at)
  VALUES (v_opponent_team.id, v_new_code, 'active', v_now, v_now + INTERVAL '7 days')
  RETURNING id INTO v_new_code_id;

  RETURN jsonb_build_object(
    'success',            true,
    'booking_id',         v_new_booking_id,
    'status',             v_final_status,
    'challenge_status',   v_final_challenge_status,
    'total_price',        v_price,
    'player_team_id',     v_caller_team.id,
    'player_team_name',   v_caller_team.name,
    'opponent_team_id',   v_opponent_team.id,
    'opponent_team_name', v_opponent_team.name,
    'new_opponent_code',  v_new_code,
    'locked_until',       v_locked_until
  );

EXCEPTION
  WHEN unique_violation OR exclusion_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'SLOT_LOCKED_OR_TAKEN',
      'message', 'عذراً، تم حجز هذا الموعد للتو من لاعب آخر.');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_owner_dashboard_analytics(p_owner_id uuid, p_start_date timestamp with time zone, p_end_date timestamp with time zone, p_court_id uuid DEFAULT NULL::uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_result json;
  v_total_op_hours numeric := 0;
  v_booked_hours numeric := 0;
  v_total_revenue numeric := 0;
  v_cash_revenue numeric := 0;
  v_online_revenue numeric := 0;
  v_realized_revenue numeric := 0;
  v_realized_cash numeric := 0;
  v_realized_online numeric := 0;
  v_cash_collected numeric := 0;
  v_cash_uncollected numeric := 0;
  v_online_collected numeric := 0;
  v_online_pending numeric := 0;
  v_online_unavailable numeric := 0;
  v_upcoming_value numeric := 0;
  v_upcoming_cash numeric := 0;
  v_upcoming_online numeric := 0;
  v_maintenance_hours numeric := 0;
  v_total_bookings integer := 0;
  v_cash_bookings integer := 0;
  v_online_bookings integer := 0;
  v_period_days integer;
  v_avg_hourly_rate numeric := 0;
begin
  perform public.require_owner_or_active_admin_actor(p_owner_id);

  v_period_days := greatest(1, date_part('day', p_end_date - p_start_date)::integer);

  select coalesce(avg(price_per_hour), 0)
    into v_avg_hourly_rate
  from public.stadiums
  where owner_id = p_owner_id
    and (p_court_id is null or id = p_court_id)
    and price_per_hour > 0;

  if v_avg_hourly_rate is null or v_avg_hourly_rate < 0 then
    v_avg_hourly_rate := 0;
  end if;

  select coalesce(sum(
    case
      when s.closing_time is not null and s.opening_time is not null then
        (case
          when s.closing_time > s.opening_time then
            extract(epoch from (s.closing_time - s.opening_time)) / 3600.0
          else
            extract(epoch from ('24:00:00'::time - s.opening_time + s.closing_time)) / 3600.0
        end)
        - (case
            when s.is_split_shift is true and s.break_start_time is not null and s.break_end_time is not null then
              case
                when s.break_end_time > s.break_start_time then
                  extract(epoch from (s.break_end_time - s.break_start_time)) / 3600.0
                else
                  extract(epoch from ('24:00:00'::time - s.break_start_time + s.break_end_time)) / 3600.0
              end
            else 0.0
          end)
      else 0.0
    end
  ) * v_period_days, 0)
    into v_total_op_hours
  from public.stadiums s
  where s.owner_id = p_owner_id
    and (p_court_id is null or s.id = p_court_id)
    and coalesce(s.is_deleted_by_owner, false) = false;

  -- Maintenance closes capacity but is not customer demand and must not
  -- inflate occupancy or appear as lost revenue.
  select coalesce(sum(
    greatest(
      0,
      extract(
        epoch from (
          least(b.end_time, p_end_date) - greatest(b.start_time, p_start_date)
        )
      ) / 3600.0
    )
  ), 0)
  into v_maintenance_hours
  from public.bookings b
  join public.stadiums s on s.id = b.stadium_id
  where s.owner_id = p_owner_id
    and (p_court_id is null or s.id = p_court_id)
    and coalesce(s.is_deleted_by_owner, false) = false
    and b.booking_type = 'maintenance'
    and b.status <> 'cancelled'
    and b.start_time < p_end_date
    and b.end_time > p_start_date;

  v_total_op_hours := greatest(v_total_op_hours - v_maintenance_hours, 0);

  select
    count(b.id),
    count(b.id) filter (where b.payment_source = 'cash' or b.payment_method = 'cash'),
    count(b.id) filter (where lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'),
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(greatest(0, extract(epoch from (b.end_time - b.start_time)) / 3600.0)), 0)
  into
    v_total_bookings,
    v_cash_bookings,
    v_online_bookings,
    v_total_revenue,
    v_cash_revenue,
    v_online_revenue,
    v_booked_hours
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('confirmed', 'completed', 'upcoming')
    and b.booking_type <> 'maintenance';

  select
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash' then
          case when (b.payment_status = 'paid' or b.is_paid = true)
               then b.total_price
               else greatest(b.deposit_paid, 0) end
        else 0
      end
    ), 0),
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
         and (b.payment_status = 'paid' or b.is_paid = true)
        then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                  then b.deposit_paid else b.total_price end
        else 0
      end
    ), 0)
  into
    v_cash_collected,
    v_online_collected
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status <> 'cancelled'
    and b.booking_type <> 'maintenance';

  select coalesce(sum(
    case
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash' then
        case
          when (b.payment_status = 'paid' or b.is_paid = true) then 0
          else greatest(b.total_price - greatest(coalesce(b.deposit_paid, 0), 0), 0)
        end
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
           and (b.payment_status = 'paid' or b.is_paid = true)
           and b.total_price > greatest(coalesce(b.deposit_paid, 0), 0) then
        greatest(b.total_price - greatest(coalesce(b.deposit_paid, 0), 0), 0)
      else 0
    end
  ), 0)
  into v_cash_uncollected
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status <> 'cancelled';

  select coalesce(sum(
    case
      when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
       and not (b.payment_status = 'paid' or b.is_paid = true)
      then case
        when coalesce(b.needs_deposit, false) and coalesce(b.deposit_amount, 0) > 0
          then greatest(
            coalesce(b.deposit_amount, 0) - greatest(coalesce(b.deposit_paid, 0), 0),
            0
          )
        else greatest(
          coalesce(b.total_price, 0) - greatest(coalesce(b.deposit_paid, 0), 0),
          0
        )
      end
      else 0
    end
  ), 0)
  into v_online_pending
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('pending', 'confirmed', 'upcoming')
    and b.booking_type <> 'maintenance';

  -- Paid online money is collected, but remains unavailable for withdrawal
  -- until the booking reaches the terminal financial lifecycle state.
  select coalesce(sum(
    case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
         then b.deposit_paid else b.total_price end
  ), 0)
    into v_online_unavailable
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
    and (b.payment_status = 'paid' or b.is_paid = true)
    and b.status not in ('cancelled', 'completed', 'no_show');

  select
    coalesce(sum(
      case
        when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
          then case when (b.payment_status = 'paid' or b.is_paid = true)
                    then b.total_price else greatest(b.deposit_paid, 0) end
        else case when (b.payment_status = 'paid' or b.is_paid = true)
                  then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                            then b.deposit_paid else b.total_price end
                  else 0 end
      end
    ), 0),
    coalesce(sum(
      case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
        then case when (b.payment_status = 'paid' or b.is_paid = true)
                  then b.total_price else greatest(b.deposit_paid, 0) end
        else 0 end
    ), 0),
    coalesce(sum(
      case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
        and (b.payment_status = 'paid' or b.is_paid = true)
        then case when b.deposit_paid > 0 and b.deposit_paid < b.total_price
                  then b.deposit_paid else b.total_price end
        else 0 end
    ), 0)
  into v_realized_revenue, v_realized_cash, v_realized_online
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('completed', 'no_show')
    and b.booking_type <> 'maintenance';

  select
    coalesce(sum(case when b.total_price > 0 then b.total_price else b.deposit_paid end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) = 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0),
    coalesce(sum(case when lower(coalesce(nullif(b.payment_source, ''), b.payment_method, '')) <> 'cash'
      then case when b.total_price > 0 then b.total_price else b.deposit_paid end else 0 end), 0)
  into v_upcoming_value, v_upcoming_cash, v_upcoming_online
  from public.bookings b
  where b.owner_id = p_owner_id
    and (p_court_id is null or b.stadium_id = p_court_id)
    and b.start_time >= p_start_date
    and b.start_time < p_end_date
    and b.status in ('confirmed', 'upcoming')
    and b.end_time > now();

  select json_build_object(
    'meta', json_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date,
      'period_days', v_period_days
    ),
    'revenue', json_build_object(
      'total', round(v_total_revenue, 2),
      'cash', round(v_cash_revenue, 2),
      'online', round(v_online_revenue, 2),
      'cash_percentage', case when v_total_revenue > 0
        then round((v_cash_revenue / v_total_revenue) * 100, 1) else 0 end,
      'online_percentage', case when v_total_revenue > 0
        then round((v_online_revenue / v_total_revenue) * 100, 1) else 0 end,
      'realized_revenue', round(v_realized_revenue, 2),
      'realized_cash', round(v_realized_cash, 2),
      'realized_online', round(v_realized_online, 2),
      'cash_collected', round(v_cash_collected, 2),
      'cash_uncollected', round(v_cash_uncollected, 2),
      'online_collected', round(v_online_collected, 2),
      'online_pending', round(v_online_pending, 2),
      'online_unavailable', round(v_online_unavailable, 2),
      'upcoming_confirmed_value', round(v_upcoming_value, 2),
      'upcoming_cash_value', round(v_upcoming_cash, 2),
      'upcoming_online_value', round(v_upcoming_online, 2),
      'unrealized', case when v_avg_hourly_rate > 0
        then round(greatest(v_total_op_hours - v_booked_hours, 0) * v_avg_hourly_rate, 2)
        else 0 end
    ),
    'bookings', json_build_object(
      'total_count', v_total_bookings,
      'cash_count', v_cash_bookings,
      'online_count', v_online_bookings,
      'average_price', case when v_total_bookings > 0
        then round(v_total_revenue / v_total_bookings, 2) else 0 end
    ),
    'capacity', json_build_object(
      'total_operating_hours', round(v_total_op_hours, 1),
      'booked_hours', round(v_booked_hours, 1),
      'unbooked_hours', round(greatest(v_total_op_hours - v_booked_hours, 0), 1),
      'occupancy_rate', case when v_total_op_hours > 0
        then round((v_booked_hours / v_total_op_hours) * 100, 1) else 0 end
    )
  ) into v_result;

  return v_result;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_owner_ai_operational_insights(p_owner_id uuid, p_period text DEFAULT '30d'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller_id uuid:=auth.uid(); v_caller_role text; v_now timestamptz:=now(); v_from timestamptz; v_to timestamptz:=v_now;
 v_period text:=lower(coalesce(trim(p_period),'30d')); v_period_days numeric:=30;
 v_total_bookings int:=0; v_completed_bookings int:=0; v_confirmed_bookings int:=0; v_cancelled_bookings int:=0;
 v_gross_booking_value numeric:=0; v_realized_revenue numeric:=0; v_booked_hours numeric:=0; v_available_hours numeric:=0;
 v_utilization_pct numeric:=0; v_cancellation_rate_pct numeric:=0; v_avg_booking_value numeric:=0; v_stadium_count int:=0;
 v_cash_debt numeric:=0; v_debt_limit numeric:=0; v_debt_blocked boolean:=false; v_alerts jsonb:='[]'::jsonb;
begin
  PERFORM public.require_owner_or_active_admin_actor(p_owner_id);

 -- Authorization already enforced by require_owner_or_active_admin_actor(p_owner_id)
 select coalesce(accumulated_cash_debt,0),coalesce(debt_limit,0),coalesce(is_debt_blocked,false)
 into v_cash_debt,v_debt_limit,v_debt_blocked from public.users where id=p_owner_id and role='owner';
 v_from:=case v_period when '7d' then v_now-interval '7 days' when '90d' then v_now-interval '90 days' when 'all' then '1970-01-01 00:00:00+00'::timestamptz else v_now-interval '30 days' end;
 v_period_days:=greatest(1,extract(epoch from(v_to-v_from))/86400.0);
 select count(*)::int,count(*) filter(where status='completed')::int,count(*) filter(where status='confirmed')::int,count(*) filter(where status='cancelled')::int,coalesce(sum(total_price),0)
 into v_total_bookings,v_completed_bookings,v_confirmed_bookings,v_cancelled_bookings,v_gross_booking_value
 from public.bookings where owner_id=p_owner_id and created_at>=v_from and created_at<=v_to;
 select coalesce(sum(total_price),0) into v_realized_revenue from public.bookings where owner_id=p_owner_id and created_at>=v_from and created_at<=v_to and status='completed' and payment_status='paid';
 select coalesce(sum(greatest(0,extract(epoch from(least(end_time,v_to)-greatest(start_time,v_from)))/3600.0)),0) into v_booked_hours from public.bookings where owner_id=p_owner_id and status<>'cancelled' and end_time>v_from and start_time<v_to;
 select count(*)::int into v_stadium_count from public.stadiums where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;
 select coalesce(sum(((case when s.closing_time>s.opening_time then extract(epoch from(s.closing_time-s.opening_time))/3600.0 else extract(epoch from(s.closing_time-s.opening_time))/3600.0+24 end) - case when coalesce(s.is_split_shift,false) and s.break_start_time is not null and s.break_end_time is not null then case when s.break_end_time>=s.break_start_time then extract(epoch from(s.break_end_time-s.break_start_time))/3600.0 else extract(epoch from(s.break_end_time-s.break_start_time))/3600.0+24 end else 0 end)*v_period_days),0) into v_available_hours from public.stadiums s where s.owner_id=p_owner_id and coalesce(s.is_deleted_by_owner,false)=false and s.opening_time is not null and s.closing_time is not null;
 if v_available_hours>0 then v_utilization_pct:=round(v_booked_hours/v_available_hours*100,2); end if;
 if v_total_bookings>0 then v_cancellation_rate_pct:=round(v_cancelled_bookings::numeric/v_total_bookings*100,2); v_avg_booking_value:=round(v_gross_booking_value/v_total_bookings,2); end if;
 if v_cash_debt>0 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','CASH_DEBT','severity',case when v_debt_blocked or (v_debt_limit>0 and v_cash_debt>=v_debt_limit) then 'critical' else 'warning' end,'metric','accumulated_cash_debt','value',round(v_cash_debt,2),'debt_limit',round(v_debt_limit,2))); end if;
 if v_total_bookings=0 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','NO_BOOKINGS_IN_PERIOD','severity','info','metric','total_bookings','value',0,'message_ar','لا توجد حجوزات مسجلة في الفترة المحددة.','evidence',jsonb_build_object('period',v_period)));
 else
   if v_utilization_pct<25 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','LOW_UTILIZATION','severity','warning','metric','utilization_pct','value',v_utilization_pct,'threshold',25));
   elsif v_utilization_pct>=70 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','HIGH_UTILIZATION','severity','info','metric','utilization_pct','value',v_utilization_pct,'threshold',70)); end if;
   if v_cancellation_rate_pct>=15 then v_alerts:=v_alerts||jsonb_build_array(jsonb_build_object('code','HIGH_CANCELLATION_RATE','severity','warning','metric','cancellation_rate_pct','value',v_cancellation_rate_pct,'threshold',15)); end if;
 end if;
 return jsonb_build_object('success',true,'owner_id',p_owner_id,'period',v_period,'period_start',v_from,'period_end',v_to,'stadium_count',v_stadium_count,'total_bookings',v_total_bookings,'completed_bookings',v_completed_bookings,'confirmed_bookings',v_confirmed_bookings,'cancelled_bookings',v_cancelled_bookings,'gross_booking_value',round(v_gross_booking_value,2),'realized_revenue',round(v_realized_revenue,2),'booked_hours',round(v_booked_hours,2),'available_hours_estimate',round(v_available_hours,2),'utilization_pct',v_utilization_pct,'cancellation_rate_pct',v_cancellation_rate_pct,'average_booking_value',v_avg_booking_value,'accumulated_cash_debt',round(v_cash_debt,2),'debt_limit',round(v_debt_limit,2),'is_debt_blocked',v_debt_blocked,'alerts',v_alerts);
end; $function$
;

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
  perform public.require_owner_or_active_admin_actor(p_owner_id);

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
$function$
;

CREATE OR REPLACE FUNCTION public.check_owner_stadium_limit(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval record;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() AND (auth.uid() IS NULL OR (auth.uid() <> p_owner_id AND NOT public.is_admin_or_cofounder(auth.uid()))) THEN
    RETURN jsonb_build_object('allowed', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_eval FROM public.evaluate_owner_stadium_capacity(p_owner_id);
  RETURN jsonb_build_object(
    'allowed', v_eval.allowed,
    'current_count', v_eval.current_count,
    'max_allowed', v_eval.max_allowed,
    'is_trial', v_eval.is_trial,
    'is_sub_active', v_eval.is_sub_active,
    'plan_code', v_eval.plan_code,
    'message', v_eval.message
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_paid_web_subscription_for_user(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_user public.users%rowtype;
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_USER_ID');
  END IF;

  -- Caller ownership validation (prevents IDOR)
  IF NOT public.vsp_is_service_or_db_owner() AND (auth.uid() IS NULL OR (auth.uid() <> p_user_id AND NOT public.is_admin_or_cofounder(auth.uid()))) THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  SELECT * INTO v_user FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'USER_NOT_FOUND');
  END IF;

  SELECT * INTO v_order
  FROM public.owner_subscription_orders
  WHERE status = 'paid'
    AND owner_id IS NULL
    AND lower(trim(checkout_email)) = lower(trim(v_user.email))
    AND nullif(trim(checkout_phone), '') IS NOT NULL
    AND nullif(trim(v_user.phone), '') IS NOT NULL
    AND regexp_replace(checkout_phone, '[^0-9+]', '', 'g') = regexp_replace(v_user.phone, '[^0-9+]', '', 'g')
    AND (claim_expires_at IS NULL OR claim_expires_at > v_now)
  ORDER BY paid_at DESC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NO_MATCHING_PAID_WEB_SUBSCRIPTION');
  END IF;

  v_expires := greatest(v_now, coalesce(v_user.subscription_expires_at, v_now))
    + make_interval(days => coalesce(v_order.duration_days, CASE WHEN v_order.billing_period = 'annual' THEN 365 ELSE 30 END));

  UPDATE public.owner_subscription_orders
  SET owner_id = p_user_id
  WHERE id = v_order.id AND owner_id IS NULL;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'SUBSCRIPTION_ALREADY_CLAIMED');
  END IF;

  UPDATE public.users
  SET role = CASE WHEN role IN ('admin', 'co_founder') THEN role ELSE 'owner' END,
      subscription_plan = v_order.plan_code,
      subscription_expires_at = v_expires,
      trial_ends_at = NULL,
      updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.notifications(user_id, title, body, type, is_read, metadata, created_at)
  VALUES (
    p_user_id,
    'تم تفعيل اشتراك Pro',
    format('تم ربط اشتراك Pro المدفوع من الموقع بحسابك بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo', 'DD FMMonth YYYY')),
    'subscription_activated',
    false,
    jsonb_build_object('order_id', v_order.id, 'payment_source', v_order.payment_source, 'plan_code', v_order.plan_code, 'gross_amount', v_order.gross_amount),
    v_now
  );

  RETURN jsonb_build_object('success', true, 'order_id', v_order.id, 'plan_code', v_order.plan_code, 'subscription_expires_at', v_expires);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.persist_copilot_turn(p_conversation_id uuid, p_user_id uuid, p_user_content text, p_assistant_content text, p_stadium_results jsonb DEFAULT '[]'::jsonb, p_ui_metadata jsonb DEFAULT '{}'::jsonb, p_context_snapshot jsonb DEFAULT '{}'::jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_current_snapshot jsonb;
  v_current_version int := 0;
  v_incoming_version int := 0;
  v_last_seq bigint := 0;
  v_final_snapshot jsonb;
begin
  -- 1. Validation: p_user_id and p_conversation_id are required
  if p_conversation_id is null or p_user_id is null then
    raise exception 'conversation_id and user_id are required';
  end if;

  -- 2. Authorization: Allow service_role (Edge Function), postgres superuser, OR authenticated user matching p_user_id
  if not public.vsp_is_service_or_db_owner()
     and (auth.uid() is null or p_user_id is distinct from auth.uid()) then
    raise exception 'Unauthorized';
  end if;

  -- 3. Verify conversation exists and belongs to the specified user
  select context_snapshot into v_current_snapshot
  from public.copilot_conversations
  where id = p_conversation_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'conversation not found for user';
  end if;

  -- 4. Calculate sequence number
  select coalesce(max(message_sequence), 0) into v_last_seq
  from public.copilot_messages
  where conversation_id = p_conversation_id;

  -- 5. Insert user message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'user', p_user_content, '[]'::jsonb,
    jsonb_build_object('task_state', coalesce(p_ui_metadata->'task_state', '{}'::jsonb)),
    v_last_seq + 1
  );

  -- 6. Insert assistant message
  insert into public.copilot_messages(
    conversation_id, user_id, role, content, stadium_results, ui_metadata, message_sequence
  ) values (
    p_conversation_id, p_user_id, 'assistant', p_assistant_content,
    coalesce(p_stadium_results, '[]'::jsonb),
    coalesce(p_ui_metadata, '{}'::jsonb),
    v_last_seq + 2
  );

  -- 7. Snapshot version conflict resolution
  if v_current_snapshot is not null and v_current_snapshot ? 'conversation_state' then
    v_current_version := coalesce((v_current_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if p_context_snapshot is not null and p_context_snapshot ? 'conversation_state' then
    v_incoming_version := coalesce((p_context_snapshot->'conversation_state'->>'version')::int, 0);
  end if;

  if v_current_version > v_incoming_version then
    v_final_snapshot := v_current_snapshot;
  else
    v_final_snapshot := coalesce(p_context_snapshot, '{}'::jsonb);
  end if;

  -- 8. Update conversation snapshot and mark initialized
  update public.copilot_conversations
  set updated_at = now(),
      context_snapshot = v_final_snapshot,
      is_initialized = true
  where id = p_conversation_id and user_id = p_user_id;

  return true;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.increment_banner_clicks(p_banner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

BEGIN

    -- حظر الاستدعاءات الوهمية من غير المسجلين

    IF auth.uid() IS NULL AND NOT public.vsp_is_service_or_db_owner() THEN

        RETURN;

    END IF;



    UPDATE public.banners

    SET clicks_count = COALESCE(clicks_count, 0) + 1,

        updated_at = NOW()

    WHERE id = p_banner_id;

END;

$function$
;

CREATE OR REPLACE FUNCTION public.increment_banner_views(p_banner_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

BEGIN

    -- حظر هجمات البوتات والتكرار العشوائي

    IF auth.uid() IS NULL AND NOT public.vsp_is_service_or_db_owner() THEN

        RETURN;

    END IF;



    UPDATE public.banners

    SET views_count = COALESCE(views_count, 0) + 1,

        updated_at = NOW()

    WHERE id = p_banner_id;

END;

$function$
;

CREATE OR REPLACE FUNCTION public.verify_match_played(p_booking_id uuid, p_attended boolean, p_absent_team_id text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_caller_role text;
  v_is_authorized boolean := false;
BEGIN
  -- 1. Fetch booking record
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Strict Zero-Trust Authorization check (auth.uid = owner_id OR admin OR service_role)
  IF COALESCE(auth.role(), '') = 'service_role' OR (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    v_is_authorized := true;
  ELSIF auth.uid() IS NOT NULL THEN
    IF v_booking.owner_id = auth.uid() THEN
      v_is_authorized := true;
    ELSE
      SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
      IF v_caller_role IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
        v_is_authorized := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: Only the stadium owner or platform administrators can verify match attendance.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  -- 3. Idempotency Check: Do not trigger duplicate Elo calculations, penalties, or status writes
  IF p_attended THEN
    IF v_booking.is_verified_by_owner IS TRUE AND v_booking.status = 'completed' THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = true,
      status = 'completed',
      updated_at = now()
    WHERE id = p_booking_id;
  ELSE
    IF v_booking.status = 'cancelled' AND v_booking.is_verified_by_owner IS FALSE THEN
      RETURN true;
    END IF;

    UPDATE public.bookings
    SET 
      is_verified_by_owner = false,
      absent_team_id = p_absent_team_id,
      status = 'cancelled',
      updated_at = now()
    WHERE id = p_booking_id;

    IF p_absent_team_id IS NOT NULL THEN
      UPDATE public.teams SET attendance_score = GREATEST(0, attendance_score - 10) WHERE id::text = p_absent_team_id;
      UPDATE public.users SET no_show_count = no_show_count + 1 WHERE id = (SELECT captain_id FROM public.teams WHERE id::text = p_absent_team_id);
    END IF;
  END IF;

  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_late_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
  v_is_owner boolean := false;
  v_cutoff numeric := 6;
  v_grace numeric := 20;
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    v_is_owner := auth.uid() IS NOT NULL AND auth.uid() = OLD.owner_id;

    IF auth.uid() IS NOT NULL THEN
      SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    END IF;

    IF NOT v_is_owner
       AND NOT public.is_admin_or_cofounder(auth.uid())
       AND NOT public.vsp_is_service_or_db_owner() THEN

      IF OLD.status <> 'pending' THEN
        IF now() > OLD.start_time - ((SELECT player_cancellation_cutoff_hours FROM public.platform_business_rules WHERE id=1) * interval '1 hour')
           AND now() > OLD.created_at + ((SELECT player_cancellation_grace_minutes FROM public.platform_business_rules WHERE id=1) * interval '1 minute')
        THEN
          RAISE EXCEPTION 'cannot_cancel_within_6_hours';
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_booking_payment_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  is_admin BOOLEAN := FALSE;
BEGIN
  SELECT (role = ANY (ARRAY['admin'::text, 'co_founder'::text, 'super_admin'::text]))
  INTO is_admin
  FROM public.users
  WHERE id = auth.uid();

  IF public.vsp_is_service_or_db_owner()
     OR current_setting('vsp.system_override', true) = 'true'
     OR current_setting('vsp.internal_payment_call', true) = 'true' THEN
    RETURN NEW;
  END IF;
  is_admin := COALESCE(public.is_admin_or_cofounder(auth.uid()), FALSE);

  IF NOT COALESCE(is_admin, FALSE) THEN
    -- منع اللاعب من تأكيد الدفع مباشرة
    IF (NEW.is_paid IS TRUE AND OLD.is_paid IS FALSE)
      AND (NEW.payment_method = 'paymob')
      AND (OLD.payment_status = 'pending') THEN
        IF auth.uid() IS NOT NULL AND auth.uid() = OLD.created_by_user_id THEN
          RAISE EXCEPTION 'Access Denied: Payment confirmation must go through the payment gateway webhook.';
        END IF;
    END IF;

    -- منع تقليل السعر الإجمالي
    IF NEW.total_price < OLD.total_price AND (OLD.payment_transaction_id NOT LIKE 'MANUAL%') THEN
      RAISE EXCEPTION 'Access Denied: You cannot reduce the booking total price.';
    END IF;

    -- منع اللاعب من تعديل refund fields مباشرة
    IF NEW.refund_transaction_id IS DISTINCT FROM OLD.refund_transaction_id
      AND OLD.refund_transaction_id IS NOT NULL THEN
        RAISE EXCEPTION 'Security Alert: Refund transaction ID cannot be modified after being set.';
    END IF;

  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_championship_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_caller_role      TEXT;
  v_has_participants BOOLEAN := false;
  v_has_fixtures     BOOLEAN := false;
BEGIN
  IF public.vsp_is_service_or_db_owner() OR current_setting('vsp.system_override', true) = 'true' THEN RETURN NEW; END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  IF v_caller_role IN ('admin','co_founder','super_admin','cofounder') THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    IF COALESCE(NEW.is_approved, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Non-admin users cannot create pre-approved championships.';
    END IF;
    IF COALESCE(NEW.creation_fee_paid, false) = true THEN
      RAISE EXCEPTION 'Security Alert: Creation fee status is server-authoritative.';
    END IF;
    RETURN NEW;
  END IF;

  v_has_participants := (
    cardinality(COALESCE(OLD.paid_teams,   ARRAY[]::TEXT[])) > 0 OR
    cardinality(COALESCE(OLD.joined_teams, ARRAY[]::TEXT[])) > 0 OR
    OLD.registration_locked_at IS NOT NULL
  );

  SELECT EXISTS(
    SELECT 1 FROM public.tournament_matches WHERE championship_id = OLD.id LIMIT 1
  ) INTO v_has_fixtures;

  IF NEW.is_approved IS DISTINCT FROM OLD.is_approved OR
     NEW.champion_team_id IS DISTINCT FROM OLD.champion_team_id OR
     NEW.winner_team_id IS DISTINCT FROM OLD.winner_team_id OR
     NEW.champion_user_id IS DISTINCT FROM OLD.champion_user_id OR
     NEW.paid_teams IS DISTINCT FROM OLD.paid_teams OR
     NEW.joined_teams IS DISTINCT FROM OLD.joined_teams OR
     NEW.prize_pool IS DISTINCT FROM OLD.prize_pool OR
     NEW.creation_fee_paid IS DISTINCT FROM OLD.creation_fee_paid OR
     NEW.creation_payment_id IS DISTINCT FROM OLD.creation_payment_id OR
     NEW.prize_delivered IS DISTINCT FROM OLD.prize_delivered OR
     NEW.prize_delivered_at IS DISTINCT FROM OLD.prize_delivered_at OR
     NEW.prize_delivered_by IS DISTINCT FROM OLD.prize_delivered_by OR
     NEW.prize_delivery_notes IS DISTINCT FROM OLD.prize_delivery_notes OR
     NEW.registration_locked_at IS DISTINCT FROM OLD.registration_locked_at THEN
    RAISE EXCEPTION 'Security Alert: Championship financial, roster, approval and result fields are server-authoritative.';
  END IF;

  IF (v_has_participants OR v_has_fixtures) AND (
     NEW.entry_fee IS DISTINCT FROM OLD.entry_fee OR
     NEW.grand_prize IS DISTINCT FROM OLD.grand_prize OR
     NEW.max_teams IS DISTINCT FROM OLD.max_teams OR
     NEW.min_players_per_team IS DISTINCT FROM OLD.min_players_per_team OR
     NEW.max_players_per_team IS DISTINCT FROM OLD.max_players_per_team OR
     NEW.type IS DISTINCT FROM OLD.type OR
     NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups OR
     NEW.qualifying_per_group IS DISTINCT FROM OLD.qualifying_per_group OR
     NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs OR
     NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth OR
     NEW.winning_points IS DISTINCT FROM OLD.winning_points OR
     NEW.draw_points IS DISTINCT FROM OLD.draw_points OR
     NEW.loss_points IS DISTINCT FROM OLD.loss_points
  ) THEN
    RAISE EXCEPTION 'Security Alert: Championship structure cannot change after registration or fixture generation. Fixtures exist: %', v_has_fixtures;
  END IF;

  IF OLD.template_type = 'team_league' AND (
     NEW.entry_fee IS DISTINCT FROM OLD.entry_fee OR
     NEW.max_teams IS DISTINCT FROM OLD.max_teams OR
     NEW.winning_points IS DISTINCT FROM OLD.winning_points OR
     NEW.draw_points IS DISTINCT FROM OLD.draw_points OR
     NEW.loss_points IS DISTINCT FROM OLD.loss_points OR
     NEW.is_back_and_forth IS DISTINCT FROM OLD.is_back_and_forth OR
     NEW.number_of_groups IS DISTINCT FROM OLD.number_of_groups OR
     NEW.is_two_legs IS DISTINCT FROM OLD.is_two_legs OR
     NEW.grand_prize IS DISTINCT FROM OLD.grand_prize
  ) THEN
    RAISE EXCEPTION 'Security Alert: Team League structure is always fixed — cannot override VSP rules.';
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_stadium_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_caller_role text;
begin
  if public.vsp_is_service_or_db_owner() or current_setting('vsp.system_override', true) = 'true' then return new; end if;

  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','cofounder','super_admin') then return new; end if;

  if new.is_verified is distinct from old.is_verified then
    if new.is_verified=true then
      raise exception 'Security Alert: Stadium verification requires admin approval.';
    else
      -- Owner may request a re-review by un-verifying, but cannot approve it.
      new.is_verified:=false;
    end if;
  end if;

  if new.is_blocked is distinct from old.is_blocked then
    raise exception 'Security Alert: Stadium blocking state requires admin approval.';
  end if;

  if new.rating is distinct from old.rating then
    new.rating:=old.rating;
  end if;

  if new.reviews_count is distinct from old.reviews_count then
    new.reviews_count:=old.reviews_count;
  end if;

  if new.is_featured is distinct from old.is_featured and new.is_featured=true then
    raise exception 'Security Alert: Featuring a stadium requires admin approval.';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_team_sensitive_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_caller_role text;
begin
  if public.vsp_is_service_or_db_owner() or current_setting('vsp.system_override', true) = 'true' then return new; end if;

  select role into v_caller_role from public.users where id=auth.uid();
  if v_caller_role in ('admin','co_founder','cofounder','super_admin') then return new; end if;

  if new.captain_id is distinct from old.captain_id then
    raise exception 'Security Alert: Team captain changes require the official team-management workflow.';
  end if;

  if new.is_verified is distinct from old.is_verified and new.is_verified=true then
    raise exception 'Security Alert: Team verification requires admin approval.';
  end if;

  if new.is_blocked is distinct from old.is_blocked and new.is_blocked=false then
    raise exception 'Security Alert: Team unblocking requires admin approval.';
  end if;

  new.points:=old.points;
  new.wins:=old.wins;
  new.draws:=old.draws;
  new.losses:=old.losses;
  new.matches_played:=old.matches_played;
  new.current_winning_streak:=old.current_winning_streak;
  new.championships_won:=old.championships_won;
  new.elo_rating:=old.elo_rating;
  new.attendance_score:=old.attendance_score;
  new.verified_badge:=old.verified_badge;
  new.is_official:=old.is_official;
  new.has_1v1_champion:=old.has_1v1_champion;
  new.beaten_opponents:=old.beaten_opponents;
  new.played_opponents:=old.played_opponents;
  new.unlocked_badges:=old.unlocked_badges;
  new.last_reset_year:=old.last_reset_year;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.vsp_guard_direct_booking_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
BEGIN
  IF public.vsp_is_service_or_db_owner()
     OR current_setting('vsp.system_override', true) = 'true'
     OR current_setting('vsp.internal_payment_call', true) = 'true'
  THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
  IF coalesce(v_role, '') IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
    RETURN NEW;
  END IF;

  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id
     OR NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.created_by_user_id IS DISTINCT FROM OLD.created_by_user_id
     OR NEW.stadium_id IS DISTINCT FROM OLD.stadium_id
     OR NEW.total_price IS DISTINCT FROM OLD.total_price
     OR NEW.vsp_commission IS DISTINCT FROM OLD.vsp_commission
     OR NEW.gateway_fee IS DISTINCT FROM OLD.gateway_fee
     OR NEW.platform_fee IS DISTINCT FROM OLD.platform_fee
     OR NEW.deposit_paid IS DISTINCT FROM OLD.deposit_paid
     OR NEW.is_deposit_paid IS DISTINCT FROM OLD.is_deposit_paid
     OR NEW.is_paid IS DISTINCT FROM OLD.is_paid
     OR NEW.payment_status IS DISTINCT FROM OLD.payment_status
     OR NEW.payment_method IS DISTINCT FROM OLD.payment_method
     OR NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
     OR NEW.status IS DISTINCT FROM OLD.status
     OR NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
     OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'BOOKING_CORE_FIELDS_REQUIRE_SERVER_WORKFLOW';
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_expire_pending_1v1_orders()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_count INT := 0;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة للسيرفر فقط.';
  END IF;

  UPDATE public.vsp_1v1_tournament_orders
  SET payment_status = 'expired',
      updated_at = timezone('utc'::text, now())
  WHERE payment_status = 'pending'
    AND expires_at < timezone('utc'::text, now())
    AND expires_at IS NOT NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'expired_count', v_count);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_booking_gateway_refund_atomic(p_booking_id uuid, p_reason text DEFAULT 'cancelled'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_existing_refund record;
  v_source_tx record;
  v_source_count integer := 0;
  v_now timestamptz := timezone('utc', now());
  v_lease_until timestamptz;
  v_refund_amount numeric(10,2);
  v_refund_gross numeric(10,2);
  v_source_paymob_id text;
  v_meta jsonb;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF lower(coalesce(v_booking.payment_method, '')) = 'cash' THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash_booking_not_supported');
  END IF;

  SELECT count(*)
  INTO v_source_count
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL);

  IF v_source_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_refundable_paymob_payment');
  END IF;

  -- A booking may have deposit + final-payment transactions. Do not silently refund
  -- only the latest transaction; route multi-transaction cases to controlled review.
  IF v_source_count > 1 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'multiple_paymob_payments_require_manual_refund',
      'payment_count', v_source_count
    );
  END IF;

  SELECT *
  INTO v_source_tx
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND status = 'completed'
    AND type IN ('payment', 'deposit')
    AND lower(coalesce(payment_method, '')) <> 'cash'
    AND (paymob_transaction_id IS NOT NULL OR reference_number IS NOT NULL)
  ORDER BY created_at DESC
  LIMIT 1;

  v_source_paymob_id := coalesce(v_source_tx.paymob_transaction_id, v_source_tx.reference_number);
  IF nullif(trim(v_source_paymob_id), '') IS NULL OR coalesce(v_source_tx.amount, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_refundable_paymob_transaction');
  END IF;

  v_refund_amount := round(coalesce(v_source_tx.amount, 0), 2);
  v_refund_gross := round(coalesce(v_source_tx.gross_amount, v_source_tx.amount), 2);
  v_lease_until := v_now + interval '5 minutes';

  SELECT id, status, metadata
  INTO v_existing_refund
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type = 'refund'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND AND v_existing_refund.status = 'completed' THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_refunded', true,
      'booking_id', p_booking_id
    );
  END IF;

  IF FOUND AND v_existing_refund.status = 'pending' THEN
    v_meta := coalesce(v_existing_refund.metadata, '{}'::jsonb);

    IF coalesce((v_meta->>'refund_lease_expires_at')::timestamptz, 'epoch'::timestamptz) > v_now THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'refund_in_progress',
        'booking_id', p_booking_id,
        'refund_transaction_id', v_existing_refund.id,
        'lease_expires_at', v_meta->>'refund_lease_expires_at'
      );
    END IF;

    UPDATE public.transactions
    SET amount = v_refund_amount,
        gross_amount = v_refund_gross,
        payment_method = coalesce(nullif(v_source_tx.payment_method, ''), payment_method),
        metadata = v_meta || jsonb_build_object(
          'source_transaction_id', v_source_tx.id,
          'paymob_transaction_id', v_source_paymob_id,
          'refund_principal', v_refund_amount,
          'refund_gross', v_refund_gross,
          'refund_reason', coalesce(p_reason, 'cancelled'),
          'refund_lease_expires_at', v_lease_until,
          'refund_claimed_at', v_now
        ),
        updated_at = v_now
    WHERE id = v_existing_refund.id;

    UPDATE public.bookings
    SET status = 'cancelled',
        payment_status = 'refund_pending',
        payment_reconcile_state = 'refund_pending',
        refund_amount = v_refund_amount,
        cancellation_reason = coalesce(p_reason, cancellation_reason),
        cancelled_at = coalesce(cancelled_at, v_now),
        updated_at = v_now
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'claimed', true,
      'refund_transaction_id', v_existing_refund.id,
      'source_transaction_id', v_source_tx.id,
      'paymob_transaction_id', v_source_paymob_id,
      'refund_amount', v_refund_amount,
      'refund_gross_amount', v_refund_gross,
      'lease_expires_at', v_lease_until
    );
  END IF;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status,
    payment_method, reference_number, description, metadata, created_at, updated_at
  )
  VALUES (
    coalesce(v_booking.created_by_user_id, v_booking.user_id),
    p_booking_id,
    v_refund_amount,
    v_refund_gross,
    'refund',
    'pending',
    coalesce(nullif(v_source_tx.payment_method, ''), 'paymob'),
    'REFUND_CLAIM_' || p_booking_id::text,
    'استرداد Paymob قيد المعالجة',
    jsonb_build_object(
      'source_transaction_id', v_source_tx.id,
      'paymob_transaction_id', v_source_paymob_id,
      'refund_principal', v_refund_amount,
      'refund_gross', v_refund_gross,
      'refund_reason', coalesce(p_reason, 'cancelled'),
      'refund_lease_expires_at', v_lease_until,
      'refund_claimed_at', v_now
    ),
    v_now, v_now
  )
  RETURNING id INTO v_existing_refund.id;

  UPDATE public.bookings
  SET status = 'cancelled',
      payment_status = 'refund_pending',
      payment_reconcile_state = 'refund_pending',
      refund_amount = v_refund_amount,
      cancellation_reason = coalesce(p_reason, cancellation_reason),
      cancelled_at = coalesce(cancelled_at, v_now),
      updated_at = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'claimed', true,
    'refund_transaction_id', v_existing_refund.id,
    'source_transaction_id', v_source_tx.id,
    'paymob_transaction_id', v_source_paymob_id,
    'refund_amount', v_refund_amount,
    'refund_gross_amount', v_refund_gross,
    'lease_expires_at', v_lease_until
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'refund_already_claimed');
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_next_1v1_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_1v1_cancellation_refund_atomic is restricted to service_role';
  END IF;

  SELECT * INTO v_row
  FROM public.vsp_1v1_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Escalate to manual review after 3 failed lease cycles
  IF v_row.retry_count >= 3 THEN
    UPDATE public.vsp_1v1_cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.vsp_1v1_tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.order_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- Transition to processing with 15-minute lease
  UPDATE public.vsp_1v1_cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'tournament_id', v_row.tournament_id,
      'order_id', v_row.order_id,
      'user_id', v_row.user_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', v_row.currency,
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_next_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  -- Strict Access Control: ONLY service_role or postgres internal caller
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_cancellation_refund_atomic is restricted to service_role';
  END IF;

  -- 1. Select pending row OR abandoned processing row whose 15-minute lease expired
  SELECT * INTO v_row
  FROM public.cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- 2. Max Retry Invariant: Escalate to failed_manual_review after 3 failed attempts
  IF v_row.retry_count >= 3 THEN
    UPDATE public.cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.order_id;

    UPDATE public.championship_registrations
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.registration_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- 3. Atomically transition to processing with 15-minute lease
  UPDATE public.cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'championship_id', v_row.championship_id,
      'order_id', v_row.order_id,
      'registration_id', v_row.registration_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', v_row.currency,
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.claim_next_team_league_cancellation_refund_atomic()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row RECORD;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RAISE EXCEPTION 'Unauthorized: claim_next_team_league_cancellation_refund_atomic is restricted to service_role';
  END IF;

  SELECT * INTO v_row
  FROM public.team_league_cancellation_refund_queue
  WHERE status = 'pending'
     OR (status = 'processing' AND locked_until IS NOT NULL AND locked_until < now())
     OR (status = 'processing' AND locked_until IS NULL AND updated_at < now() - INTERVAL '15 minutes')
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  -- Escalate to manual review after 3 failed lease cycles
  IF v_row.retry_count >= 3 THEN
    UPDATE public.team_league_cancellation_refund_queue
    SET status = 'failed_manual_review',
        failure_reason = 'Escalated to manual review: 3 failed lease cycles exceeded',
        locked_until = NULL,
        updated_at = now()
    WHERE id = v_row.id;

    UPDATE public.team_league_payments
    SET payment_status = 'refund_failed_manual_review',
        updated_at = now()
    WHERE id = v_row.payment_id;

    -- Update transaction to failed_manual_review as well to keep ledger coherent
    UPDATE public.transactions
    SET status = 'failed_manual_review',
        metadata = jsonb_set(coalesce(metadata, '{}'::jsonb), '{failure_reason}', '"Escalated to manual review: 3 failed lease cycles exceeded"'),
        updated_at = now()
    WHERE championship_id = v_row.championship_id
      AND type = 'refund_request'
      AND paymob_transaction_id = v_row.paymob_transaction_id;

    RETURN jsonb_build_object(
      'found', false,
      'escalated_to_manual_review', true,
      'queue_id', v_row.id
    );
  END IF;

  -- Transition to processing with 15-minute lease
  UPDATE public.team_league_cancellation_refund_queue
  SET status = 'processing',
      processing_started_at = now(),
      locked_until = now() + INTERVAL '15 minutes',
      retry_count = v_row.retry_count + 1,
      updated_at = now()
  WHERE id = v_row.id;

  RETURN jsonb_build_object(
    'found', true,
    'refund', jsonb_build_object(
      'id', v_row.id,
      'championship_id', v_row.championship_id,
      'payment_id', v_row.payment_id,
      'user_id', v_row.user_id,
      'paymob_transaction_id', v_row.paymob_transaction_id,
      'amount', v_row.amount,
      'currency', coalesce(v_row.currency, 'EGP'),
      'retry_count', v_row.retry_count + 1,
      'locked_until', now() + INTERVAL '15 minutes'
    )
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finalize_championship_cancellation_refund_atomic(p_championship_id uuid, p_order_reference text, p_refund_success boolean, p_refund_txn_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_order    RECORD;
  v_champ    RECORD;
  v_now      TIMESTAMPTZ := now();
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order
  FROM public.tournament_orders
  WHERE order_reference = p_order_reference AND championship_id = p_championship_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id;

  IF p_refund_success THEN
    UPDATE public.tournament_orders
    SET payment_status = 'refunded',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    -- Record completed refund transaction
    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'completed',
      'استرداد رسوم اشتراك بطولة ملغاة: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id',        p_championship_id,
        'order_reference',        p_order_reference,
        'original_paymob_txn_id', v_order.paymob_transaction_id,
        'paymob_refund_id',       p_refund_txn_id,
        'amount',                 v_order.amount
      ),
      v_now, v_now
    );

    -- Financial audit log
    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'cancellation_refund_completed',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_refund_txn_id,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'status', 'refunded'
      ),
      v_now
    );

    RETURN jsonb_build_object('success', true, 'status', 'refunded', 'order_reference', p_order_reference);

  ELSE
    -- Refund failed with Paymob: flag for urgent manual admin review
    UPDATE public.tournament_orders
    SET payment_status = 'refund_failed_manual_review',
        updated_at     = v_now
    WHERE order_reference = p_order_reference;

    INSERT INTO public.transactions (
      user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
    ) VALUES (
      v_order.captain_user_id,
      v_order.amount,
      'refund',
      'paymob',
      'failed',
      'تعذر استرداد رسوم اشتراك بطولة ملغاة تلقائياً: ' || COALESCE(v_champ.name, ''),
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now, v_now
    );

    INSERT INTO public.financial_audit_logs (
      action_type, owner_id, user_id, amount, fee, transaction_ref, metadata, created_at
    ) VALUES (
      'refund_failed_manual_review',
      v_champ.owner_id,
      v_order.captain_user_id,
      v_order.amount,
      0,
      p_order_reference,
      jsonb_build_object(
        'championship_id', p_championship_id,
        'order_reference', p_order_reference,
        'error',           p_error_message
      ),
      v_now
    );

    RETURN jsonb_build_object('success', false, 'status', 'refund_failed_manual_review', 'error', p_error_message);
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.finalize_team_withdrawal_refund_atomic(p_championship_id uuid, p_team_id uuid, p_order_reference text, p_refund_success boolean, p_refund_amount numeric, p_refund_txn_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_captain uuid; v_now timestamptz:=now();
begin
  if not public.vsp_is_service_or_db_owner() then
    return jsonb_build_object('success',false,'error','Unauthorized');
  end if;

  select * into v_order from public.tournament_orders
  where order_reference=p_order_reference and championship_id=p_championship_id and team_id=p_team_id for update;

  if not found then
    select * into v_order from public.team_league_payments
    where order_reference=p_order_reference and championship_id=p_championship_id and team_id=p_team_id for update;
  end if;

  if not found then return jsonb_build_object('success',false,'error','Payment order not found'); end if;

  if p_refund_success then
    update public.tournament_orders set payment_status='refunded',updated_at=v_now where order_reference=p_order_reference;
    update public.team_league_payments set payment_status='refunded',updated_at=v_now where order_reference=p_order_reference;

    update public.championships
    set joined_teams=array_remove(coalesce(joined_teams,array[]::text[]),p_team_id::text),
        paid_teams=array_remove(coalesce(paid_teams,array[]::text[]),p_team_id::text),
        updated_at=v_now
    where id=p_championship_id;

    select captain_id into v_captain from public.teams where id=p_team_id;

    if v_captain is not null and p_refund_amount>0 and not exists(
      select 1 from public.transactions
      where user_id=v_captain and type='refund' and status='completed'
        and coalesce(metadata->>'order_reference','')=p_order_reference
    ) then
      insert into public.transactions(
        user_id,amount,type,payment_method,status,description,metadata,created_at,updated_at
      ) values(
        v_captain,round(p_refund_amount,2),'refund','paymob','completed',
        'استرداد انسحاب من البطولة: '||(select name from public.championships where id=p_championship_id),
        jsonb_build_object('order_reference',p_order_reference,'paymob_refund_id',p_refund_txn_id,'principal_amount',v_order.amount,'refund_amount',p_refund_amount),
        v_now,v_now
      );
    end if;
    return jsonb_build_object('success',true,'status','refunded','refund_amount',round(p_refund_amount,2));
  end if;

  update public.tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where order_reference=p_order_reference;
  update public.team_league_payments set payment_status='refund_failed_manual_review',updated_at=v_now where order_reference=p_order_reference;
  return jsonb_build_object('success',true,'status','refund_failed_manual_review','refund_amount',round(coalesce(p_refund_amount,0),2),'error',p_error_message);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_role TEXT;
    v_champ RECORD;
BEGIN
    IF NOT public.vsp_is_service_or_db_owner() THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized: Admin access required');
        END IF;
    END IF;

    SELECT * INTO v_champ FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tournament not found');
    END IF;

    -- Archive whatever was previously published IN THE SAME GOVERNORATE ONLY
    UPDATE public.vsp_1v1_tournaments
    SET status = 'archived'
    WHERE governorate = v_champ.governorate AND status = 'published' AND id != p_tournament_id;

    -- Publish the target tournament
    UPDATE public.vsp_1v1_tournaments
    SET status = 'published', published_at = timezone('utc'::text, now())
    WHERE id = p_tournament_id;

    RETURN jsonb_build_object('success', true, 'tournament_id', p_tournament_id, 'governorate', v_champ.governorate);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.record_1v1_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_admin_id uuid;
begin
 if not public.vsp_is_service_or_db_owner() then return jsonb_build_object('success',false,'error','غير مصرح.'); end if;
 select * into v_order from public.vsp_1v1_tournament_orders where order_reference=p_order_reference for update;
 if not found then return jsonb_build_object('success',false,'error','الطلب غير موجود.'); end if;
 if v_order.payment_status='refunded' then return jsonb_build_object('success',true,'already_refunded',true,'status','refunded'); end if;
 if v_order.payment_status not in ('paid','refund_requested','failed_over_capacity','refund_failed_manual_review') then
   return jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','status',v_order.payment_status);
 end if;
 -- Canonical refundable amount is the tournament entry principal; fees are not refundable.
 v_amount:=round(coalesce(v_order.amount,0),2);
 if v_amount<=0 then return jsonb_build_object('success',false,'error','مبلغ الاسترداد غير صالح.'); end if;
 if p_refund_success then
   update public.vsp_1v1_tournament_orders set payment_status='refunded',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refunded',updated_at=v_now where tournament_id=v_order.tournament_id and user_id=v_order.user_id and payment_order_id=v_order.id;
   update public.transactions set amount=v_amount,status='completed',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_amount',v_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(coalesce(v_order.gross_amount,v_amount)-v_amount,0),2),'refund_recorded_at',v_now),updated_at=v_now
   where user_id=v_order.user_id and type='refund_request' and metadata->>'order_reference'=p_order_reference;
   insert into public.notifications(user_id,title,body,type,created_at)
   values(v_order.user_id,'استرداد رسوم البطولة بنجاح 💳','تم إرجاع مبلغ '||v_amount||' ج.م إلى وسيلة الدفع الخاصة بك بنجاح.','tournament_refund',v_now);
 else
   update public.vsp_1v1_tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where tournament_id=v_order.tournament_id and user_id=v_order.user_id and payment_order_id=v_order.id;
   update public.transactions set status='failed_manual_review',metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('refund_error',p_error_message,'refund_amount',v_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(coalesce(v_order.gross_amount,v_amount)-v_amount,0),2),'refund_recorded_at',v_now),updated_at=v_now
   where user_id=v_order.user_id and type='refund_request' and metadata->>'order_reference'=p_order_reference;
   for v_admin_id in select id from public.users where role in ('admin','co_founder','cofounder','super_admin') loop
     insert into public.notifications(user_id,title,body,type,created_at)
     values(v_admin_id,'تنبيه مالي: فشل استرداد بطولة 1v1','فشل استرداد الطلب '||p_order_reference||' بمبلغ '||v_amount||' ج.م. السبب: '||coalesce(p_error_message,'Paymob API error'),'admin_alert',v_now);
   end loop;
 end if;
 return jsonb_build_object('success',true,'status',case when p_refund_success then 'refunded' else 'refund_failed_manual_review' end,'refund_amount',v_amount,'paymob_refund_id',p_paymob_refund_id);
end; $function$
;

CREATE OR REPLACE FUNCTION public.record_booking_gateway_refund_atomic(p_booking_id uuid, p_refund_amount numeric, p_refund_txn_id text, p_refund_payment_method text DEFAULT 'card'::text, p_refund_gross_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  b       record;
  t       record;
  v_gross numeric;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO b FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'Booking not found'); END IF;
  IF p_refund_amount IS NULL OR p_refund_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid refund amount');
  END IF;

  v_gross := coalesce(p_refund_gross_amount, p_refund_amount);

  IF EXISTS (
    SELECT 1 FROM public.transactions
    WHERE booking_id = p_booking_id
      AND type = 'refund'
      AND status = 'completed'
      AND coalesce(metadata->>'paymob_refund_transaction_id', '') = coalesce(p_refund_txn_id, '')
  ) THEN
    RETURN jsonb_build_object('success', true, 'already_recorded', true, 'booking_id', p_booking_id);
  END IF;

  SELECT id INTO t FROM public.transactions
  WHERE booking_id = p_booking_id AND type = 'refund' AND status = 'pending'
  ORDER BY created_at DESC LIMIT 1 FOR UPDATE;

  IF FOUND THEN
    UPDATE public.transactions SET
      status         = 'completed',
      amount         = round(p_refund_amount, 2),
      gross_amount   = round(v_gross, 2),
      payment_method = coalesce(nullif(p_refund_payment_method, ''), payment_method),
      metadata       = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
                         'paymob_refund_transaction_id', p_refund_txn_id,
                         'refund_gross_amount',          round(v_gross, 2)
                       ),
      updated_at     = timezone('utc', now())
    WHERE id = t.id;
  ELSE
    INSERT INTO public.transactions (
      user_id, booking_id, amount, gross_amount, type, status,
      payment_method, description, metadata, created_at, updated_at
    ) VALUES (
      coalesce(b.created_by_user_id, b.user_id),
      p_booking_id,
      round(p_refund_amount, 2),
      round(v_gross, 2),
      'refund', 'completed',
      coalesce(nullif(p_refund_payment_method, ''), 'card'),
      'استرداد Paymob مؤكد للحجز',
      jsonb_build_object(
        'paymob_refund_transaction_id', p_refund_txn_id,
        'refund_gross_amount',          round(v_gross, 2)
      ),
      timezone('utc', now()), timezone('utc', now())
    ) RETURNING id INTO t;
  END IF;

  UPDATE public.bookings SET
    status                  = 'cancelled',
    payment_status          = 'refunded',
    refund_transaction_id   = p_refund_txn_id,
    refund_amount           = round(p_refund_amount, 2),
    refunded_at             = timezone('utc', now()),
    refund_payment_method   = coalesce(nullif(p_refund_payment_method, ''), 'card'),
    cancelled_at            = coalesce(cancelled_at, timezone('utc', now())),
    updated_at              = timezone('utc', now())
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success',       true,
    'booking_id',    p_booking_id,
    'transaction_id', t.id,
    'refund_amount',  round(p_refund_amount, 2),
    'refund_gross',   round(v_gross, 2)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.record_booking_payment_atomic(p_booking_id uuid, p_user_id uuid, p_paymob_transaction_id text, p_paymob_order_id text, p_payment_method text, p_principal_amount numeric, p_gross_amount numeric, p_is_deposit boolean DEFAULT false, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking          record;
  v_existing_tx      record;
  v_attempt          record;
  v_pricing          jsonb;
  v_total_collected  numeric := 0;
  v_total_gross      numeric := 0;
  v_remaining_before numeric := 0;
  v_player_vsp_fee   numeric := 0;
  v_owner_vsp_fee    numeric := 0;
  v_total_vsp_comm   numeric := 0;
  v_owner_net        numeric := 0;
  v_gateway_fee      numeric := 0;
  v_expected_gross   numeric := 0;
  v_fee_version      text;
  v_new_collected    numeric;
  v_new_gross        numeric;
  v_is_final         boolean;
  v_now              timestamptz := timezone('utc', now());
  v_tx_id            uuid;
  v_payment_method   text := lower(coalesce(p_payment_method, 'card'));
  v_card_origin      text := lower(coalesce(p_metadata->>'card_origin', 'local'));
  v_channel          text;
BEGIN
  IF NOT public.vsp_is_service_or_db_owner() THEN
    RETURN jsonb_build_object('success', false, 'error', 'service_role_required');
  END IF;

  IF p_booking_id IS NULL OR p_user_id IS NULL
     OR nullif(trim(p_paymob_transaction_id), '') IS NULL
     OR p_principal_amount IS NULL OR p_principal_amount <= 0
     OR p_gross_amount    IS NULL OR p_gross_amount    <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_arguments');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  -- Idempotency check by Paymob transaction ID
  SELECT id, amount, status, booking_id
  INTO v_existing_tx
  FROM public.transactions
  WHERE paymob_transaction_id = p_paymob_transaction_id
     OR reference_number = p_paymob_transaction_id
     OR reference_number = 'PAYMOB_' || p_paymob_transaction_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    IF v_existing_tx.booking_id IS DISTINCT FROM p_booking_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'transaction_already_bound_to_other_booking');
    END IF;
    RETURN jsonb_build_object('success', true, 'idempotent', true,
      'transaction_id', v_existing_tx.id, 'booking_id', p_booking_id,
      'principal_amount', v_existing_tx.amount);
  END IF;

  IF coalesce(v_booking.created_by_user_id, v_booking.user_id) IS DISTINCT FROM p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_user_mismatch');
  END IF;

  SELECT
    coalesce(sum(amount), 0),
    coalesce(sum(coalesce(gross_amount, amount)), 0)
  INTO v_total_collected, v_total_gross
  FROM public.transactions
  WHERE booking_id = p_booking_id
    AND type IN ('payment', 'deposit')
    AND status = 'completed';

  v_remaining_before := round(greatest(coalesce(v_booking.total_price, 0) - v_total_collected, 0), 2);

  IF p_principal_amount > v_remaining_before + 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'payment_exceeds_remaining_booking_balance',
      'remaining_amount', v_remaining_before, 'attempted_amount', p_principal_amount);
  END IF;

  v_channel := CASE
    WHEN v_payment_method = 'wallet' THEN 'wallet'
    WHEN v_card_origin = 'foreign' THEN 'foreign_card'
    ELSE 'local_card'
  END;

  -- Prefer the exact locked payment_attempt snapshot for this paymob_order_id
  SELECT * INTO v_attempt
  FROM public.payment_attempts
  WHERE booking_id = p_booking_id
    AND (p_paymob_order_id IS NULL OR paymob_order_id = p_paymob_order_id)
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    v_player_vsp_fee := round(v_attempt.player_vsp_fee_piasters / 100.0, 2);
    v_owner_vsp_fee  := round(v_attempt.owner_vsp_fee_piasters / 100.0, 2);
    v_total_vsp_comm := v_player_vsp_fee + v_owner_vsp_fee;
    v_owner_net      := round(v_attempt.owner_net_piasters / 100.0, 2);
    v_gateway_fee    := round(v_attempt.gateway_fee_piasters / 100.0, 2);
    v_expected_gross := round(v_attempt.approved_total_piasters / 100.0, 2);
    v_fee_version    := v_attempt.fee_version;
  ELSE
    v_pricing := public.calculate_booking_pricing_v2(p_principal_amount, v_channel);
    IF coalesce((v_pricing->>'success')::boolean, false) IS NOT TRUE THEN
      RETURN jsonb_build_object('success', false, 'error', coalesce(v_pricing->>'error', 'payment_fee_configuration_unavailable'));
    END IF;
    v_player_vsp_fee := (v_pricing->>'player_vsp_fee')::numeric;
    v_owner_vsp_fee  := (v_pricing->>'owner_vsp_fee')::numeric;
    v_total_vsp_comm := (v_pricing->>'total_vsp_commission')::numeric;
    v_owner_net      := (v_pricing->>'owner_net_amount')::numeric;
    v_gateway_fee    := (v_pricing->>'gateway_fee')::numeric;
    v_expected_gross := (v_pricing->>'total_due')::numeric;
    v_fee_version    := v_pricing->>'fee_version';
  END IF;

  IF abs(p_gross_amount - v_expected_gross) > 0.01 THEN
    RETURN jsonb_build_object('success', false, 'error', 'gross_amount_mismatch',
      'expected_gross_amount', v_expected_gross, 'received_gross_amount', p_gross_amount,
      'principal_amount', p_principal_amount, 'player_vsp_fee', v_player_vsp_fee, 'gateway_fee', v_gateway_fee);
  END IF;

  v_new_collected := round(v_total_collected + p_principal_amount, 2);
  v_new_gross     := round(v_total_gross     + p_gross_amount,     2);
  v_is_final      := v_new_collected >= round(coalesce(v_booking.total_price, 0), 2) - 0.01;

  INSERT INTO public.transactions (
    user_id, booking_id, amount, gross_amount, type, status, payment_method,
    reference_number, paymob_transaction_id, description, metadata,
    player_vsp_fee, owner_vsp_fee, owner_net_amount, gateway_fee_collected,
    fee_version, payment_channel_class, reconciliation_status,
    created_at, updated_at
  ) VALUES (
    p_user_id, p_booking_id, p_principal_amount, p_gross_amount,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'payment' ELSE 'deposit' END,
    'completed', v_payment_method,
    p_paymob_transaction_id, p_paymob_transaction_id,
    CASE WHEN v_is_final AND NOT p_is_deposit THEN 'دفع حجز ملعب' ELSE 'دفع عربون حجز ملعب' END,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'principal_amount',     p_principal_amount,
      'gross_amount_charged', p_gross_amount,
      'vsp_fee',              v_player_vsp_fee,
      'player_vsp_fee',       v_player_vsp_fee,
      'owner_vsp_fee',        v_owner_vsp_fee,
      'total_vsp_commission', v_total_vsp_comm,
      'owner_net_amount',     v_owner_net,
      'gateway_fee',          v_gateway_fee,
      'total_payment_fees',   round(v_player_vsp_fee + v_gateway_fee, 2),
      'fee_version',          v_fee_version,
      'paymob_order_id',      p_paymob_order_id,
      'server_recorded_at',   v_now
    ),
    v_player_vsp_fee, v_owner_vsp_fee, v_owner_net, v_gateway_fee,
    v_fee_version, v_channel, 'pending_reconciliation',
    v_now, v_now
  ) RETURNING id INTO v_tx_id;

  IF v_attempt.id IS NOT NULL THEN
    UPDATE public.payment_attempts
    SET status = 'paid', updated_at = v_now
    WHERE id = v_attempt.id;
  END IF;

  UPDATE public.bookings SET
    status                  = 'confirmed',
    is_paid                 = v_is_final,
    payment_status          = CASE WHEN v_is_final THEN 'paid' ELSE 'partially_paid' END,
    is_deposit_paid         = true,
    deposit_paid            = v_new_collected,
    gross_amount_charged    = v_new_gross,
    payment_transaction_id  = 'PAYMOB_' || p_paymob_transaction_id,
    paymob_txn_id           = p_paymob_transaction_id,
    paymob_order_id         = p_paymob_order_id,
    paymob_transaction_id   = p_paymob_transaction_id,
    payment_method          = v_payment_method,
    webhook_verified        = true,
    webhook_processed_at    = v_now,
    player_vsp_fee          = coalesce(player_vsp_fee, 0) + v_player_vsp_fee,
    owner_vsp_fee           = coalesce(owner_vsp_fee, 0) + v_owner_vsp_fee,
    total_vsp_commission    = coalesce(total_vsp_commission, 0) + v_total_vsp_comm,
    vsp_commission          = coalesce(vsp_commission, 0) + v_total_vsp_comm,
    owner_net_amount        = coalesce(owner_net_amount, 0) + v_owner_net,
    gateway_fee             = coalesce(gateway_fee, 0) + v_gateway_fee,
    fee_version             = coalesce(fee_version, v_fee_version),
    payment_channel_class   = coalesce(payment_channel_class, v_channel),
    updated_at              = v_now
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'transaction_id', v_tx_id,
    'booking_id', p_booking_id,
    'principal_amount', p_principal_amount,
    'gross_amount', p_gross_amount,
    'player_vsp_fee', v_player_vsp_fee,
    'owner_vsp_fee', v_owner_vsp_fee,
    'total_vsp_commission', v_total_vsp_comm,
    'owner_net_amount', v_owner_net,
    'gateway_fee', v_gateway_fee,
    'is_final_payment', v_is_final,
    'remaining_amount', round(greatest(coalesce(v_booking.total_price, 0) - v_new_collected, 0), 2)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.rollover_annual_season_atomic(p_closing_season_id uuid, p_next_year integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_closing RECORD;
  v_next_yr int;
  v_next_id uuid;
  v_prog    RECORD;
  v_archived int := 0;
BEGIN
  -- Fail-closed: require service_role/postgres OR active admin actor (never allow anon).
  IF NOT public.vsp_is_service_or_db_owner() THEN
    PERFORM public.require_active_admin_actor();
  END IF;

  PERFORM set_config('vsp.system_override', 'true', true);

  SELECT * INTO v_closing FROM public.competition_seasons WHERE id = p_closing_season_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'SEASON_NOT_FOUND'); END IF;
  IF v_closing.status = 'archived' THEN RETURN jsonb_build_object('success', true, 'already_archived', true); END IF;

  v_next_yr := COALESCE(p_next_year, v_closing.year_number + 1);

  FOR v_prog IN
    SELECT p.*,
           (SELECT min(r.final_rank) FROM public.team_monthly_rankings r WHERE r.season_id = p_closing_season_id AND r.team_id = p.team_id AND r.final_rank IS NOT NULL) AS best_rank,
           (SELECT e.reward_status FROM public.immortal_reward_entitlements e WHERE e.season_id = p_closing_season_id AND e.team_id = p.team_id LIMIT 1) AS imm_status
    FROM public.team_season_progress p
    WHERE p.season_id = p_closing_season_id
  LOOP
    INSERT INTO public.team_season_history (
      season_id, team_id, year_number, final_xp, highest_shield,
      challenges_total, challenges_weighted, wins_total, best_monthly_rank,
      immortal_qualified, immortal_reward_status, archived_at
    ) VALUES (
      p_closing_season_id, v_prog.team_id, v_closing.year_number, v_prog.season_xp, v_prog.highest_shield,
      v_prog.challenges_total, v_prog.challenges_weighted, v_prog.wins_total, v_prog.best_rank,
      v_prog.immortal_qualified, COALESCE(v_prog.imm_status, 'not_qualified'), now()
    ) ON CONFLICT (season_id, team_id) DO NOTHING;
    v_archived := v_archived + 1;
  END LOOP;

  UPDATE public.competition_seasons SET status = 'archived', closed_at = now(), updated_at = now()
  WHERE id = p_closing_season_id;

  INSERT INTO public.competition_seasons (
    season_code, name_ar, name_en, year_number, starts_at, ends_at, status, rules_config
  ) VALUES (
    v_next_yr::text,
    'موسم ' || v_next_yr::text,
    'Season ' || v_next_yr::text,
    v_next_yr,
    make_timestamptz(v_next_yr, 1, 1, 0, 0, 0, 'Africa/Cairo'),
    make_timestamptz(v_next_yr, 12, 31, 23, 59, 59, 'Africa/Cairo'),
    'active',
    v_closing.rules_config
  )
  ON CONFLICT (season_code) DO UPDATE SET status = 'active', updated_at = now()
  RETURNING id INTO v_next_id;

  RETURN jsonb_build_object('success', true, 'archived_teams', v_archived, 'next_season_id', v_next_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_order record; v_admin_id uuid; v_now timestamptz:=timezone('utc',now());
BEGIN
 IF NOT public.vsp_is_service_or_db_owner() THEN
  RETURN jsonb_build_object('success',false,'error','غير مصرح: تحديث حالة الاسترداد مقتصر على الخادم.');
 END IF;
 IF p_refund_status NOT IN ('refunded','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); END IF;
 SELECT * INTO v_order FROM public.tournament_orders WHERE order_reference=p_order_reference FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); END IF;
 IF v_order.payment_status='refunded' THEN RETURN jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); END IF;
 IF v_order.payment_status NOT IN ('paid','refund_failed_manual_review') THEN RETURN jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); END IF;
 UPDATE public.tournament_orders SET payment_status=p_refund_status,updated_at=v_now WHERE id=v_order.id;
 UPDATE public.transactions SET status=CASE WHEN p_refund_status='refunded' THEN 'completed' ELSE 'failed' END,
  metadata=coalesce(metadata,'{}')||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now)
  WHERE championship_id=v_order.championship_id AND type='refund' AND metadata->>'order_reference'=p_order_reference;
 IF p_refund_status='refunded' THEN
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_order.amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 ELSE
  INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_order.amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  FOR v_admin_id IN SELECT id FROM public.users WHERE role IN ('admin','co_founder','cofounder','super_admin') LOOP
   INSERT INTO public.notifications(user_id,title,body,type,created_at) VALUES(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_order.amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  END LOOP;
 END IF;
 RETURN jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id);
END;$function$
;

CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_admin_id uuid; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_updated integer:=0;
begin
 if not public.vsp_is_service_or_db_owner() then return jsonb_build_object('success',false,'error','غير مصرح: تحديث حالة الاسترداد مقتصر على الخادم.'); end if;
 if p_refund_status not in ('refunded','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الاسترداد غير صالحة.'); end if;
 select * into v_order from public.tournament_orders where order_reference=p_order_reference for update;
 if not found then return jsonb_build_object('success',false,'error','طلب اشتراك البطولة غير موجود.'); end if;
 if v_order.payment_status='refunded' then return jsonb_build_object('success',true,'already_refunded',true,'order_reference',p_order_reference,'status','refunded'); end if;
 if v_order.payment_status not in ('paid','failed_over_capacity','refund_failed_manual_review') then return jsonb_build_object('success',false,'error','حالة الطلب لا تسمح بتسجيل الاسترداد.','current_status',v_order.payment_status); end if;
 v_amount:=round(coalesce(nullif(p_refund_amount,0),v_order.amount),2);
 if v_amount<=0 then return jsonb_build_object('success',false,'error','مبلغ الاسترداد غير صالح.'); end if;
 update public.tournament_orders set payment_status=p_refund_status,updated_at=v_now where id=v_order.id;
 update public.transactions set amount=v_amount,status=case when p_refund_status='refunded' then 'completed' else 'failed' end,
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount)
 where championship_id=v_order.championship_id and type='refund' and metadata->>'order_reference'=p_order_reference;
 get diagnostics v_updated = row_count;
 if v_updated=0 then
  insert into public.transactions(user_id,championship_id,amount,type,status,payment_method,reference_number,metadata,created_at,updated_at)
  values(v_order.captain_user_id,v_order.championship_id,v_amount,'refund',case when p_refund_status='refunded' then 'completed' else 'failed' end,'paymob',
   'REFUND_'||p_order_reference,jsonb_build_object('order_reference',p_order_reference,'paymob_refund_id',p_paymob_refund_id,'refund_error',p_error_message,'refund_recorded_at',v_now,'refund_amount',v_amount,'principal_amount',v_order.amount),v_now,v_now);
 end if;
 if p_refund_status='refunded' then
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'تم استرداد رسوم اشتراك البطولة بنجاح','تمت إعادة مبلغ رسوم الاشتراك ('||v_amount||' ج.م) بنجاح عبر Paymob (مرجع: '||coalesce(p_paymob_refund_id,'')||').','tournament_refund',v_now);
 else
  insert into public.notifications(user_id,title,body,type,created_at) values(v_order.captain_user_id,'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)','تعذر الاسترداد التلقائي للرسوم ('||v_amount||' ج.م). تم تحويل العملية للمراجعة اليدوية.','tournament_refund_manual',v_now);
  for v_admin_id in select id from public.users where role in ('admin','co_founder','cofounder','super_admin') loop
   insert into public.notifications(user_id,title,body,type,created_at) values(v_admin_id,'تنبيه مالي: فشل استرداد رسوم بطولة فرق','فشل استرداد الطلب '||p_order_reference||' (المبلغ: '||v_amount||' ج.م). السبب: '||coalesce(p_error_message,'Paymob API error')||'.','admin_alert',v_now);
  end loop;
 end if;
 return jsonb_build_object('success',true,'order_reference',p_order_reference,'status',p_refund_status,'paymob_refund_id',p_paymob_refund_id,'refund_amount',v_amount,'ledger_recorded',true);
end; $function$
;

REVOKE ALL ON FUNCTION public.auto_expire_pending_1v1_orders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.auto_expire_pending_1v1_orders() TO service_role;
REVOKE ALL ON FUNCTION public.claim_booking_gateway_refund_atomic(p_booking_id uuid, p_reason text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_booking_gateway_refund_atomic(p_booking_id uuid, p_reason text) TO service_role;
REVOKE ALL ON FUNCTION public.claim_next_1v1_cancellation_refund_atomic() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_next_1v1_cancellation_refund_atomic() TO service_role;
REVOKE ALL ON FUNCTION public.claim_next_cancellation_refund_atomic() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_next_cancellation_refund_atomic() TO service_role;
REVOKE ALL ON FUNCTION public.claim_next_team_league_cancellation_refund_atomic() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_next_team_league_cancellation_refund_atomic() TO service_role;
REVOKE ALL ON FUNCTION public.claim_paid_web_subscription_for_user(p_user_id uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_paid_web_subscription_for_user(p_user_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.enforce_real_sender_name() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_real_sender_name() TO service_role;
REVOKE ALL ON FUNCTION public.finalize_championship_cancellation_refund_atomic(p_championship_id uuid, p_order_reference text, p_refund_success boolean, p_refund_txn_id text, p_error_message text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_championship_cancellation_refund_atomic(p_championship_id uuid, p_order_reference text, p_refund_success boolean, p_refund_txn_id text, p_error_message text) TO service_role;
REVOKE ALL ON FUNCTION public.finalize_team_withdrawal_refund_atomic(p_championship_id uuid, p_team_id uuid, p_order_reference text, p_refund_success boolean, p_refund_amount numeric, p_refund_txn_id text, p_error_message text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_team_withdrawal_refund_atomic(p_championship_id uuid, p_team_id uuid, p_order_reference text, p_refund_success boolean, p_refund_amount numeric, p_refund_txn_id text, p_error_message text) TO service_role;
REVOKE ALL ON FUNCTION public.prevent_late_cancellation() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.prevent_late_cancellation() TO service_role;
REVOKE ALL ON FUNCTION public.protect_booking_payment_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protect_booking_payment_fields() TO service_role;
REVOKE ALL ON FUNCTION public.protect_booking_sensitive_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protect_booking_sensitive_fields() TO service_role;
REVOKE ALL ON FUNCTION public.protect_championship_sensitive_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protect_championship_sensitive_fields() TO service_role;
REVOKE ALL ON FUNCTION public.protect_stadium_sensitive_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protect_stadium_sensitive_fields() TO service_role;
REVOKE ALL ON FUNCTION public.protect_team_sensitive_fields() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protect_team_sensitive_fields() TO service_role;
REVOKE ALL ON FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publish_1v1_tournament_atomic(p_tournament_id uuid) TO service_role;
REVOKE ALL ON FUNCTION public.record_1v1_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text, p_error_message text, p_refund_amount numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_1v1_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text, p_error_message text, p_refund_amount numeric) TO service_role;
REVOKE ALL ON FUNCTION public.record_booking_gateway_refund_atomic(p_booking_id uuid, p_refund_amount numeric, p_refund_txn_id text, p_refund_payment_method text, p_refund_gross_amount numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_booking_gateway_refund_atomic(p_booking_id uuid, p_refund_amount numeric, p_refund_txn_id text, p_refund_payment_method text, p_refund_gross_amount numeric) TO service_role;
REVOKE ALL ON FUNCTION public.record_booking_payment_atomic(p_booking_id uuid, p_user_id uuid, p_paymob_transaction_id text, p_paymob_order_id text, p_payment_method text, p_principal_amount numeric, p_gross_amount numeric, p_is_deposit boolean, p_metadata jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_booking_payment_atomic(p_booking_id uuid, p_user_id uuid, p_paymob_transaction_id text, p_paymob_order_id text, p_payment_method text, p_principal_amount numeric, p_gross_amount numeric, p_is_deposit boolean, p_metadata jsonb) TO service_role;
REVOKE ALL ON FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text, p_error_message text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text, p_error_message text) TO service_role;
REVOKE ALL ON FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text, p_error_message text, p_refund_amount numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(p_order_reference text, p_refund_status text, p_paymob_refund_id text, p_error_message text, p_refund_amount numeric) TO service_role;
REVOKE ALL ON FUNCTION public.rollover_annual_season_atomic(p_closing_season_id uuid, p_next_year integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rollover_annual_season_atomic(p_closing_season_id uuid, p_next_year integer) TO service_role;
REVOKE ALL ON FUNCTION public.vsp_guard_direct_booking_mutation() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vsp_guard_direct_booking_mutation() TO service_role;

CREATE OR REPLACE FUNCTION public.get_server_timestamp()
RETURNS timestamp with time zone
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
  SELECT pg_catalog.timezone('utc'::text, pg_catalog.now());
$function$;

REVOKE ALL ON FUNCTION public.get_server_timestamp() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_server_timestamp() TO anon, authenticated, service_role;

ALTER VIEW public.admin_pending_refunds SET (security_invoker = true);
ALTER VIEW public.admin_stadium_settlements SET (security_invoker = true);
ALTER VIEW public.v_financial_reconciliation SET (security_invoker = true);

CREATE OR REPLACE FUNCTION public.admin_cancel_booking_atomic(p_booking_id uuid, p_reason text DEFAULT 'Cancelled by Admin'::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_result jsonb;
BEGIN
  PERFORM public.require_active_admin_actor();
  v_result := public.cancel_booking_with_refund_atomic(
    p_booking_id,
    v_actor_id,
    coalesce(nullif(trim(p_reason), ''), 'Cancelled by Admin')
  );
  RETURN v_result;
END;
$function$;

COMMIT;
