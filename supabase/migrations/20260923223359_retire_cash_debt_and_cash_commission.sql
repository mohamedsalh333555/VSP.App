CREATE OR REPLACE FUNCTION public.admin_settle_owner_cash_debt_atomic(p_owner_id uuid, p_amount numeric, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_caller_role text;
BEGIN
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    SELECT role INTO v_caller_role
    FROM public.users
    WHERE id = auth.uid();

    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'Unauthorized: Admin privileges required'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'CASH_DEBT_SYSTEM_RETIRED',
    'message', 'نظام مديونية العمولات النقدية متوقف. لا توجد عمولة أو مديونية على الحجوزات النقدية.'
  );
END;
$function$


CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  RETURN public.confirm_cash_booking_atomic(p_booking_id,p_owner_id,p_total_price,NULL);
END;
$function$


CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric, p_collected_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_booking record;
  v_owner record;
  v_caller_role text;
  v_payment_amount numeric;
  v_previous_collected numeric;
  v_total_price numeric;
  v_new_collected numeric;
  v_existing_vsp_commission numeric := 0;
  v_existing_platform_fee numeric := 0;
  v_payment_status text;
  v_now timestamptz := timezone('utc', now());
  v_tx_id uuid;
  v_ref text;
BEGIN
  SELECT * INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'message','الحجز غير موجود.');
  END IF;

  IF coalesce(auth.role(),'') <> 'service_role'
     AND current_user NOT IN ('postgres','service_role') THEN
    SELECT role INTO v_caller_role
    FROM public.users
    WHERE id = auth.uid();

    IF v_booking.owner_id IS DISTINCT FROM auth.uid()
       AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','cofounder','super_admin') THEN
      RETURN jsonb_build_object(
        'success',false,
        'message','غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.'
      );
    END IF;
  END IF;

  IF v_booking.status='cancelled' THEN
    RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
      USING errcode='P0003';
  END IF;

  SELECT * INTO v_owner
  FROM public.users
  WHERE id = v_booking.owner_id
  FOR UPDATE;

  v_total_price := coalesce(v_booking.total_price, p_total_price, 0);
  v_previous_collected := greatest(coalesce(v_booking.deposit_paid,0),0);
  v_payment_amount := round(
    greatest(coalesce(p_collected_amount, v_total_price-v_previous_collected),0),
    2
  );

  IF v_payment_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success',false,
      'error','NO_REMAINING_CASH_BALANCE',
      'message','لا يوجد مبلغ نقدي متبقٍ للتحصيل.'
    );
  END IF;

  IF v_payment_amount > greatest(round(v_total_price-v_previous_collected,2),0)+0.01 THEN
    RETURN jsonb_build_object(
      'success',false,
      'error','CASH_AMOUNT_EXCEEDS_REMAINING'
    );
  END IF;

  v_new_collected := round(v_previous_collected+v_payment_amount,2);
  v_payment_status := CASE
    WHEN v_new_collected >= v_total_price-0.01 THEN 'paid'
    WHEN v_new_collected > 0 THEN 'partially_paid'
    ELSE 'pending'
  END;

  v_existing_vsp_commission := coalesce(v_booking.vsp_commission,0);
  v_existing_platform_fee := coalesce(v_booking.platform_fee,0);

  UPDATE public.bookings
  SET
    is_paid = (v_payment_status='paid'),
    payment_status = v_payment_status,
    status = 'confirmed',
    payment_method = 'cash',
    vsp_commission = v_existing_vsp_commission,
    platform_fee = v_existing_platform_fee,
    gateway_fee = coalesce(v_booking.gateway_fee,0),
    deposit_paid = v_new_collected,
    is_deposit_paid = v_new_collected > 0,
    webhook_verified = true,
    webhook_processed_at = v_now,
    updated_at = v_now
  WHERE id=p_booking_id;

  v_ref := 'CASH_' || replace(gen_random_uuid()::text,'-','');

  INSERT INTO public.transactions(
    user_id,booking_id,amount,type,status,payment_method,reference_number,
    description,metadata,created_at,updated_at
  ) VALUES (
    coalesce(v_booking.user_id,v_booking.created_by_user_id),
    p_booking_id,
    v_payment_amount,
    CASE WHEN v_payment_status='paid' THEN 'payment' ELSE 'deposit' END,
    'completed','cash',v_ref,
    'تحصيل نقدي لحجز ملعب',
    jsonb_build_object(
      'principal_amount',v_payment_amount,
      'gross_amount',v_payment_amount,
      'vsp_fee',0,
      'gateway_fee',0,
      'total_payment_fees',0,
      'server_recorded_at',v_now
    ),
    v_now,v_now
  )
  RETURNING id INTO v_tx_id;

  INSERT INTO public.notifications(user_id,title,body,type,created_at)
  VALUES (
    v_booking.owner_id,
    'تم استلام دفعة نقدية',
    'تم تسجيل دفعة نقدية بقيمة '||v_payment_amount||' ج.م للحجز.',
    'payment_received',
    v_now
  );

  IF coalesce(v_booking.user_id,v_booking.created_by_user_id) IS NOT NULL THEN
    INSERT INTO public.notifications(user_id,title,body,type,created_at)
    VALUES (
      coalesce(v_booking.user_id,v_booking.created_by_user_id),
      CASE WHEN v_payment_status='paid' THEN 'تم تأكيد السداد' ELSE 'تم تسجيل الدفعة' END,
      CASE
        WHEN v_payment_status='paid'
          THEN 'تم تسجيل سداد الحجز بالكامل بقيمة '||v_payment_amount||' ج.م.'
        ELSE 'تم تسجيل دفعة بقيمة '||v_payment_amount||' ج.م. والمتبقي '||
          greatest(v_total_price-v_new_collected,0)||' ج.م.'
      END,
      'booking_payment',
      v_now
    );
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'booking_id',p_booking_id,
    'transaction_id',v_tx_id,
    'amount',v_payment_amount,
    'vsp_commission',0,
    'cash_payment_fee',0,
    'accumulated_cash_debt',0,
    'is_debt_blocked',false,
    'total_price',v_total_price,
    'total_collected',v_new_collected,
    'remaining_amount',greatest(round(v_total_price-v_new_collected,2),0),
    'is_final_payment',(v_payment_status='paid'),
    'payment_status',v_payment_status
  );
END;
$function$


CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_caller_id uuid := auth.uid();
  v_caller_role text;
  v_owner record;
  v_vsp_rate numeric;
  v_gateway_rate numeric;
  v_gateway_fixed numeric;
  v_completed_online_revenue numeric := 0;
  v_escrow_online_revenue numeric := 0;
  v_completed_cash_revenue numeric := 0;
  v_total_vsp_fees numeric := 0;
  v_total_gateway_fees numeric := 0;
  v_total_withdrawn numeric := 0;
  v_pending_payouts numeric := 0;
  v_available_balance numeric := 0;
  v_completed_bookings_count integer := 0;
  v_legacy_unreconciled_bookings integer := 0;
  v_legacy_unreconciled_amount numeric := 0;
begin
  if p_owner_id is null then
    return jsonb_build_object('success',false,'error','Owner ID is required');
  end if;

  if v_caller_id is null and current_user not in ('postgres','service_role') then
    return jsonb_build_object('success',false,'error','Authentication required');
  end if;

  if v_caller_id is not null then
    select role into v_caller_role from public.users where id=v_caller_id;

    if v_caller_id is distinct from p_owner_id
       and coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin')
       and current_user not in ('postgres','service_role') then
      return jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    end if;
  end if;

  select * into v_owner
  from public.users
  where id=p_owner_id
    and role in ('owner','admin','co_founder','cofounder','super_admin');

  if not found then
    return jsonb_build_object('success',false,'error','Owner not found');
  end if;

  select booking_vsp_rate,
         booking_paymob_local_rate,
         booking_paymob_fixed_fee
  into v_vsp_rate,v_gateway_rate,v_gateway_fixed
  from public.platform_fee_config
  where id=1;

  if v_vsp_rate is null or v_gateway_rate is null or v_gateway_fixed is null then
    return jsonb_build_object('success',false,'error','Payment fee configuration unavailable');
  end if;

  with raw_payments as (
    select t.*,b.status booking_status,b.payment_method booking_payment_method,
      row_number() over (
        partition by t.booking_id,
          regexp_replace(
            coalesce(t.paymob_transaction_id,t.reference_number,t.id::text),
            '^PAYMOB_',''
          )
        order by case when t.type in ('payment','deposit') then 0 else 1 end,
          t.created_at asc
      ) rn
    from public.transactions t
    join public.bookings b on b.id=t.booking_id
    where b.owner_id=p_owner_id
      and t.status='completed'
      and t.type in ('payment','deposit','digital','cash','cash_settlement')
  ),
  deduped as (
    select * from raw_payments where rn=1
  ),
  booking_payment_totals as (
    select booking_id,sum(amount) principal_total
    from deduped
    group by booking_id
  ),
  refunds as (
    select booking_id,sum(amount) refunded_amount
    from public.transactions
    where booking_id is not null
      and type in ('refund','refund_card','refund_wallet','refund_cash')
      and status='completed'
    group by booking_id
  ),
  allocated as (
    select d.*,
      coalesce(r.refunded_amount,0) booking_refund,
      greatest(
        least(
          d.amount,
          coalesce(r.refunded_amount,0) *
          case when bpt.principal_total>0 then d.amount/bpt.principal_total else 0 end
        ),
        0
      ) allocated_refund
    from deduped d
    join booking_payment_totals bpt on bpt.booking_id=d.booking_id
    left join refunds r on r.booking_id=d.booking_id
  )
  select
    coalesce(sum(
      case
        when booking_status='completed'
         and lower(coalesce(payment_method,booking_payment_method,''))<>'cash'
        then greatest(amount-allocated_refund,0)
        else 0
      end
    ),0),
    coalesce(sum(
      case
        when booking_status='confirmed'
         and lower(coalesce(payment_method,booking_payment_method,''))<>'cash'
        then greatest(amount-allocated_refund,0)
        else 0
      end
    ),0),
    coalesce(sum(
      case
        when booking_status='completed'
         and lower(coalesce(payment_method,booking_payment_method,''))='cash'
        then greatest(amount-allocated_refund,0)
        else 0
      end
    ),0),
    coalesce(sum(
      greatest(
        coalesce(
          nullif(metadata->>'vsp_fee','')::numeric,
          case
            when lower(coalesce(payment_method,booking_payment_method,''))='cash'
            then 0
            else round(amount*v_vsp_rate,2)
          end
        ) *
        case when amount>0 then greatest(1-(allocated_refund/amount),0) else 0 end,
        0
      )
    ),0),
    coalesce(sum(
      case
        when lower(coalesce(payment_method,booking_payment_method,''))<>'cash'
        then coalesce(
          nullif(metadata->>'gateway_fee','')::numeric,
          round(
            amount * (
              case
                when lower(coalesce(payment_method,booking_payment_method,''))='wallet'
                then (
                  select booking_paymob_wallet_rate
                  from public.platform_fee_config
                  where id=1
                )
                else v_gateway_rate
              end
            ) + v_gateway_fixed,
            2
          )
        )
        else 0
      end
    ),0)
  into v_completed_online_revenue,
       v_escrow_online_revenue,
       v_completed_cash_revenue,
       v_total_vsp_fees,
       v_total_gateway_fees
  from allocated;

  select count(*),
         coalesce(sum(
           case
             when lower(coalesce(payment_method,''))='cash'
             then coalesce(nullif(deposit_paid,0),total_price,0)
             else coalesce(nullif(deposit_paid,0),total_price,0)
           end
         ),0)
  into v_legacy_unreconciled_bookings,v_legacy_unreconciled_amount
  from public.bookings b
  where b.owner_id=p_owner_id
    and b.status in ('confirmed','completed')
    and (b.is_paid is true or b.payment_status in ('paid','partially_paid'))
    and not exists (
      select 1
      from public.transactions t
      where t.booking_id=b.id
        and t.status='completed'
        and t.type in ('payment','deposit','cash','cash_settlement','digital')
    );

  select count(*)
  into v_completed_bookings_count
  from public.bookings
  where owner_id=p_owner_id
    and status='completed';

  select coalesce(sum(amount),0)
  into v_total_withdrawn
  from public.payout_settlements
  where owner_id=p_owner_id
    and status in ('completed','paid');

  select coalesce(sum(amount),0)
  into v_pending_payouts
  from public.payout_settlements
  where owner_id=p_owner_id
    and status in ('pending','approved');

  v_available_balance := greatest(
    round(v_completed_online_revenue-v_total_withdrawn-v_pending_payouts,2),
    0
  );

  return jsonb_build_object(
    'success',true,
    'owner_id',p_owner_id,
    'total_online_revenue',round(v_completed_online_revenue+v_escrow_online_revenue,2),
    'completed_online_revenue',round(v_completed_online_revenue,2),
    'escrow_online_revenue',round(v_escrow_online_revenue,2),
    'total_gateway_fees',round(v_total_gateway_fees,2),
    'total_vsp_commission',round(v_total_vsp_fees,2),
    'net_online_earnings',round(v_completed_online_revenue,2),
    'owner_online_earnings',round(v_completed_online_revenue,2),
    'available_balance',round(v_available_balance,2),
    'total_withdrawn',round(v_total_withdrawn,2),
    'pending_payouts',round(v_pending_payouts,2),
    'cash_revenue',round(v_completed_cash_revenue,2),
    -- Backward-compatible response keys only; cash debt is retired and always zero.
    'accumulated_cash_debt',0,
    'debt_limit',0,
    'is_debt_blocked',false,
    'owner_total_revenue',round(v_completed_online_revenue+v_completed_cash_revenue,2),
    'completed_bookings_count',v_completed_bookings_count,
    'legacy_unreconciled_bookings',v_legacy_unreconciled_bookings,
    'legacy_unreconciled_amount',round(v_legacy_unreconciled_amount,2)
  );
end;
$function$


CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stadium record;
  v_overlap_count int;
  v_now timestamptz := timezone('utc',now());
  v_booking_id uuid;
  v_payment_status text;
  v_is_paid boolean;
  v_customer_clean text;
  v_caller_role text;
  v_actual_owner_id uuid;
  v_is_authorized boolean := false;
  v_duration_hours numeric;
  v_server_total_price numeric;
  v_collected numeric;
  v_tx_id uuid;
  v_payment_reference text;
BEGIN
  SELECT * INTO v_stadium
  FROM public.stadiums
  WHERE id=p_stadium_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND');
  END IF;

  v_actual_owner_id := v_stadium.owner_id;

  IF v_stadium.is_deleted_by_owner IS TRUE OR coalesce(v_stadium.is_blocked,false) THEN
    RETURN jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE');
  END IF;

  IF coalesce(v_stadium.is_verified,false) IS FALSE THEN
    RETURN jsonb_build_object('success',false,'error','STADIUM_NOT_VERIFIED');
  END IF;

  IF auth.role()='service_role' OR current_user IN ('postgres','service_role') THEN
    v_is_authorized := true;
  ELSIF auth.uid() IS NOT NULL THEN
    IF v_actual_owner_id=auth.uid() THEN
      v_is_authorized := true;
    ELSE
      SELECT role INTO v_caller_role
      FROM public.users
      WHERE id=auth.uid();

      IF v_caller_role IN ('admin','co_founder','super_admin','cofounder') THEN
        v_is_authorized := true;
      END IF;
    END IF;
  END IF;

  IF NOT v_is_authorized THEN
    RETURN jsonb_build_object('success',false,'error','UNAUTHORIZED');
  END IF;

  IF p_owner_id IS NOT NULL
     AND p_owner_id<>v_actual_owner_id
     AND coalesce(v_caller_role,'') NOT IN ('admin','co_founder','super_admin','cofounder')
     AND auth.role()<>'service_role'
     AND current_user NOT IN ('postgres','service_role') THEN
    RETURN jsonb_build_object('success',false,'error','OWNER_MISMATCH');
  END IF;

  IF p_end_time<=p_start_time THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_TIME_RANGE');
  END IF;

  v_duration_hours := extract(epoch from (p_end_time-p_start_time))/3600.0;

  IF v_duration_hours <= 0
     OR v_duration_hours > (
       SELECT manual_booking_max_duration_hours
       FROM public.platform_business_rules
       WHERE id=1
     ) THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_DURATION');
  END IF;

  v_server_total_price := round(v_stadium.price_per_hour*v_duration_hours,2);

  IF v_server_total_price<=0 THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE');
  END IF;

  IF abs(coalesce(p_total_price,0)-v_server_total_price)>0.01 THEN
    RETURN jsonb_build_object(
      'success',false,
      'error','PRICE_MISMATCH',
      'expected_total_price',v_server_total_price
    );
  END IF;

  IF p_collected_amount<0 OR p_collected_amount>v_server_total_price THEN
    RETURN jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT');
  END IF;

  v_collected := round(coalesce(p_collected_amount,0),2);

  IF p_start_time < v_now - (
       SELECT booking_past_grace_minutes
       FROM public.platform_business_rules
       WHERE id=1
     ) * INTERVAL '1 minute' THEN
    RETURN jsonb_build_object('success',false,'error','START_TIME_IN_PAST');
  END IF;

  SELECT count(*) INTO v_overlap_count
  FROM public.bookings
  WHERE stadium_id=p_stadium_id
    AND status<>'cancelled'
    AND p_start_time<end_time
    AND p_end_time>start_time;

  IF v_overlap_count>0 THEN
    RETURN jsonb_build_object(
      'success',false,
      'error','conflict',
      'code','SLOT_LOCKED_OR_TAKEN'
    );
  END IF;

  v_is_paid := v_collected>=v_server_total_price;
  v_payment_status := CASE
    WHEN v_is_paid THEN 'paid'
    WHEN v_collected>0 THEN 'partially_paid'
    ELSE 'pending'
  END;

  v_customer_clean := coalesce(nullif(trim(p_customer_name),''),'حجز يدوي');
  v_payment_reference := 'MANUAL_' || replace(gen_random_uuid()::text,'-','');

  BEGIN
    INSERT INTO public.bookings(
      stadium_id,stadium_name,owner_id,user_id,created_by_user_id,
      start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,
      total_price,vsp_commission,gateway_fee,platform_fee,deposit_paid,is_deposit_paid,
      is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,
      is_private,rent_ball,created_at,updated_at
    )
    VALUES(
      p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,
      coalesce(auth.uid(),v_actual_owner_id),
      p_start_time,p_end_time,'personal',v_customer_clean,v_customer_clean,
      nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),
      v_server_total_price,0,0,0,v_collected,
      (v_collected>0),v_is_paid,v_payment_status,'cash',
      v_payment_reference,'confirmed',p_current_players,true,false,v_now,v_now
    )
    RETURNING id INTO v_booking_id;
  EXCEPTION
    WHEN unique_violation OR exclusion_violation THEN
      RETURN jsonb_build_object(
        'success',false,
        'error','conflict',
        'code','SLOT_LOCKED_OR_TAKEN'
      );
  END;

  IF v_collected>0 THEN
    INSERT INTO public.transactions(
      user_id,booking_id,amount,type,status,payment_method,reference_number,
      description,metadata,created_at,updated_at
    )
    VALUES(
      v_actual_owner_id,
      v_booking_id,
      v_collected,
      CASE WHEN v_is_paid THEN 'payment' ELSE 'deposit' END,
      'completed','cash',v_payment_reference,
      'تحصيل نقدي لحجز يدوي',
      jsonb_build_object(
        'principal_amount',v_collected,
        'gross_amount',v_collected,
        'vsp_fee',0,
        'gateway_fee',0,
        'total_payment_fees',0,
        'server_recorded_at',v_now
      ),
      v_now,v_now
    )
    RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'booking_id',v_booking_id,
    'total_price',v_server_total_price,
    'vsp_commission',0,
    'gateway_fee',0,
    'cash_payment_fee',0,
    'collected_amount',v_collected,
    'remaining_amount',greatest(round(v_server_total_price-v_collected,2),0),
    'accumulated_cash_debt',0,
    'is_debt_blocked',false,
    'transaction_id',v_tx_id,
    'payment_status',v_payment_status
  );
END;
$function$


UPDATE public.users
SET accumulated_cash_debt=0,
    is_debt_blocked=false,
    updated_at=timezone('utc',now())
WHERE role IN ('owner','admin','co_founder','cofounder','super_admin')
  AND (COALESCE(accumulated_cash_debt,0) <> 0 OR COALESCE(is_debt_blocked,false) IS TRUE);
