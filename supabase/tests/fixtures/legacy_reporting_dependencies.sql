-- TEST ONLY: two reporting dependencies and six real legacy RPC definitions.

CREATE TABLE public."payout_settlements" ("id" uuid,
"owner_id" uuid,
"amount" numeric,
"method" text,
"destination" text,
"status" text,
"admin_notes" text,
"created_at" timestamp with time zone,
"updated_at" timestamp with time zone);

CREATE TABLE public."transactions" ("id" uuid,
"user_id" uuid,
"type" text,
"amount" numeric(10,2),
"created_at" timestamp with time zone,
"booking_id" uuid,
"championship_id" uuid,
"payment_method" text,
"metadata" jsonb,
"status" text,
"description" text,
"reference_number" text,
"updated_at" timestamp with time zone,
"paymob_transaction_id" text,
"gross_amount" numeric(10,2));

CREATE OR REPLACE FUNCTION public.get_admin_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_role TEXT;
    v_total_owners int;
    v_pending_verifications int;
    v_active_stadiums int;
BEGIN
    IF (COALESCE(auth.role(), '') != 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RAISE EXCEPTION 'Unauthorized: Admin access required';
        END IF;
    END IF;

    SELECT count(*) INTO v_total_owners
    FROM public.users
    WHERE role = 'owner';

    SELECT count(*) INTO v_pending_verifications
    FROM public.users
    WHERE role = 'owner' AND verification_status = 'pending';

    SELECT count(*) INTO v_active_stadiums
    FROM public.stadiums
    WHERE is_verified = true AND is_blocked = false AND is_deleted_by_owner = false;

    RETURN jsonb_build_object(
        'total_owners', v_total_owners,
        'pending_verifications', v_pending_verifications,
        'active_stadiums', v_active_stadiums
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_admin_quick_metrics()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_total_owners integer;
  v_pending_verifications integer;
  v_active_bookings integer;
  v_total_revenue numeric;
BEGIN
  -- Verify admin authorization
  IF COALESCE(auth.role(), '') != 'service_role' AND NOT (auth.uid() IS NULL AND session_user IN ('postgres', 'supabase_admin')) THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role = ANY(ARRAY['admin', 'co_founder', 'super_admin', 'cofounder'])
    ) THEN
      RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
    END IF;
  END IF;

  SELECT count(*) INTO v_total_owners FROM public.users WHERE role = 'owner';
  SELECT count(*) INTO v_pending_verifications FROM public.users WHERE role = 'owner' AND verification_status = 'pending';
  SELECT count(*) INTO v_active_bookings FROM public.bookings WHERE status IN ('confirmed', 'upcoming');

  -- Gross platform completed turnover: only completed payments, excluding duplicates, refunds, payouts
  SELECT COALESCE(sum(amount), 0) INTO v_total_revenue 
  FROM public.transactions 
  WHERE type IN ('digital', 'cash_settlement') 
    AND status = 'completed';

  RETURN jsonb_build_object(
    'total_owners', v_total_owners,
    'pending_verifications', v_pending_verifications,
    'active_bookings', v_active_bookings,
    'total_revenue', v_total_revenue
  );
END;
$function$;

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
 if v_caller_id is null and current_user not in ('postgres','service_role') then return jsonb_build_object('success',false,'error','Authentication required'); end if;
 if v_caller_id is not null then
   select role into v_caller_role from public.users where id=v_caller_id;
   if v_caller_id<>p_owner_id and coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') and current_user not in ('postgres','service_role')
   then return jsonb_build_object('success',false,'error','Unauthorized access to owner insights'); end if;
 end if;
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
end; $function$;

CREATE OR REPLACE FUNCTION public.get_owner_ai_stadium_comparison(p_owner_id uuid, p_period text DEFAULT '30d'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_now timestamptz := now();
    v_from timestamptz;
    v_period text := lower(coalesce(trim(p_period), '30d'));
    v_days numeric;
    v_prev_from timestamptz;
    v_prev_to timestamptz;
    v_rows jsonb;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id <> p_owner_id
           AND coalesce(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to stadium comparison');
        END IF;
    END IF;

    v_from := CASE v_period
        WHEN '7d' THEN v_now - interval '7 days'
        WHEN '90d' THEN v_now - interval '90 days'
        WHEN 'all' THEN '1970-01-01 00:00:00+00'::timestamptz
        ELSE v_now - interval '30 days'
    END;

    v_days := greatest(1, extract(epoch FROM (v_now - v_from)) / 86400.0);

    IF v_period <> 'all' THEN
        v_prev_to := v_from;
        v_prev_from := v_prev_to - (v_now - v_from);
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.realized_revenue DESC, x.bookings_count DESC), '[]'::jsonb)
    INTO v_rows
    FROM (
        SELECT
            s.id AS stadium_id,
            s.name AS stadium_name,
            count(b.id)::int AS bookings_count,
            count(*) FILTER (WHERE b.status = 'completed')::int AS completed_bookings,
            count(*) FILTER (WHERE b.status = 'cancelled')::int AS cancelled_bookings,
            round(coalesce(sum(b.total_price),0),2) AS gross_booking_value,
            round(coalesce(sum(b.total_price) FILTER (
                WHERE b.status = 'completed'
                  AND (b.payment_status = 'paid' OR b.is_paid = true)
            ),0),2) AS realized_revenue,
            round(coalesce(sum(
                CASE
                    WHEN b.id IS NULL OR b.status = 'cancelled' THEN 0
                    ELSE greatest(0, extract(epoch FROM (
                        least(b.end_time, v_now) - greatest(b.start_time, v_from)
                    )) / 3600.0)
                END
            ),0),2) AS booked_hours,
            CASE
                WHEN count(b.id) > 0
                THEN round((count(*) FILTER (WHERE b.status = 'cancelled')::numeric / count(b.id)::numeric) * 100.0, 2)
                ELSE 0
            END AS cancellation_rate_pct,

            CASE WHEN v_period <> 'all' THEN (
                SELECT count(*)::int FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_bookings_count,

            CASE WHEN v_period <> 'all' THEN (
                SELECT round(coalesce(sum(pb.total_price) FILTER (
                    WHERE pb.status = 'completed'
                      AND (pb.payment_status = 'paid' OR pb.is_paid = true)
                ),0),2)
                FROM public.bookings pb
                WHERE pb.stadium_id = s.id
                  AND pb.created_at >= v_prev_from
                  AND pb.created_at < v_prev_to
            ) ELSE NULL END AS previous_realized_revenue

        FROM public.stadiums s
        LEFT JOIN public.bookings b
          ON b.stadium_id = s.id
         AND b.created_at >= v_from
         AND b.created_at <= v_now
        WHERE s.owner_id = p_owner_id
          AND coalesce(s.is_deleted_by_owner, false) = false
        GROUP BY s.id, s.name
    ) x;

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'period', v_period,
        'period_start', v_from,
        'period_end', v_now,
        'stadiums', v_rows
    );
END;
$function$;

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
  v_now timestamptz:=now();
begin
  if auth.uid() is null and current_user not in ('postgres','service_role') then
    return jsonb_build_object('success',false,'error','Authentication required');
  end if;
  if auth.uid() is not null and auth.uid()<>p_owner_id and current_user not in ('postgres','service_role') then
    select role into v_caller_role from public.users where id=auth.uid();
    if coalesce(v_caller_role,'') not in ('admin','co_founder','cofounder','super_admin') then
      return jsonb_build_object('success',false,'error','Unauthorized access to financial records');
    end if;
  end if;

  select count(*)::int into v_stadium_count from public.stadiums
  where owner_id=p_owner_id and coalesce(is_deleted_by_owner,false)=false;

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0),
         coalesce(sum(coalesce(b.platform_fee,0)),0),
         count(*)::int
  into v_realized_online_rev, v_total_platform_fees, v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
    and b.status in ('completed','no_show')
    and b.booking_type <> 'maintenance';

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
    into v_online_collected_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select count(*)::int
    into v_online_count
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and b.status<>'cancelled'
    and b.booking_type <> 'maintenance';

  select coalesce(sum(case when coalesce(b.deposit_paid,0)>0 and coalesce(b.deposit_paid,0)<b.total_price then b.deposit_paid else b.total_price end),0)
  into v_upcoming_online_rev
  from public.bookings b
  where b.owner_id=p_owner_id
    and lower(coalesce(nullif(b.payment_source,''),b.payment_method,''))<>'cash'
    and (b.payment_status='paid' or b.is_paid=true)
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

CREATE OR REPLACE FUNCTION public.get_tournament_financial_summary(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_champ record;
  v_caller uuid := auth.uid();
  v_role text;
  v_is_admin boolean := false;
  v_paid_teams_count int := 0;
  v_total_collected numeric := 0;
  v_net_profit numeric := 0;
begin
  if v_caller is null then
    return jsonb_build_object('success', false, 'error', 'Authentication required');
  end if;

  select * into v_champ
  from public.championships
  where id = p_championship_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'البطولة غير موجودة');
  end if;

  select role into v_role
  from public.users
  where id = v_caller;

  v_is_admin := coalesce(v_role in ('admin','co_founder','cofounder','super_admin'), false);

  if not v_is_admin and v_champ.owner_id is distinct from v_caller then
    return jsonb_build_object('success', false, 'error', 'غير مصرح لك بعرض البيانات المالية لهذه البطولة');
  end if;

  if coalesce(v_champ.template_type, '') = 'team_league' then
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.team_league_payments
    where championship_id = p_championship_id
      and payment_status = 'completed';
  else
    select count(distinct team_id)::int, coalesce(sum(amount),0)
    into v_paid_teams_count, v_total_collected
    from public.tournament_orders
    where championship_id = p_championship_id
      and payment_status = 'completed';
  end if;

  v_net_profit := v_total_collected - coalesce(v_champ.grand_prize, 0);

  return jsonb_build_object(
    'success', true,
    'paid_teams_count', v_paid_teams_count,
    'entry_fee', v_champ.entry_fee,
    'total_collected', round(v_total_collected, 2),
    'grand_prize', v_champ.grand_prize,
    'net_profit', round(v_net_profit, 2),
    'is_registration_locked', v_champ.registration_locked_at is not null
  );
end;
$function$;
