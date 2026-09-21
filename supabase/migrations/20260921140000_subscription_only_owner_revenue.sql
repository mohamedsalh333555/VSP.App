CREATE OR REPLACE FUNCTION public.owner_create_manual_booking_atomic(p_owner_id uuid, p_stadium_id uuid, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_customer_name text, p_customer_phone text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_total_price numeric DEFAULT 0, p_collected_amount numeric DEFAULT 0, p_current_players integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_stadium record; v_owner record; v_overlap_count int; v_now timestamptz:=timezone('utc',now()); v_booking_id uuid; v_payment_status text; v_is_paid boolean; v_customer_clean text; v_caller_role text; v_actual_owner_id uuid; v_is_authorized boolean:=false; v_vsp_commission numeric; v_new_debt numeric; v_is_blocked boolean; v_duration_hours numeric; v_server_total_price numeric; v_collected numeric;
begin
 select * into v_stadium from public.stadiums where id=p_stadium_id for update;
 if not found then return jsonb_build_object('success',false,'error','STADIUM_NOT_FOUND'); end if;
 v_actual_owner_id:=v_stadium.owner_id;
 if v_stadium.is_deleted_by_owner is true or coalesce(v_stadium.is_blocked,false) then return jsonb_build_object('success',false,'error','STADIUM_UNAVAILABLE'); end if;
 if coalesce(v_stadium.is_verified,false) is false then return jsonb_build_object('success',false,'error','STADIUM_NOT_VERIFIED'); end if;
 if auth.role()='service_role' then v_is_authorized:=true;
 elsif auth.uid() is not null then
   if v_actual_owner_id=auth.uid() then v_is_authorized:=true;
   else select role into v_caller_role from public.users where id=auth.uid(); if v_caller_role in ('admin','co_founder','super_admin','cofounder') then v_is_authorized:=true; end if; end if;
 end if;
 if not v_is_authorized then return jsonb_build_object('success',false,'error','UNAUTHORIZED'); end if;
 if p_owner_id is not null and p_owner_id<>v_actual_owner_id and coalesce(v_caller_role,'') not in ('admin','co_founder','super_admin','cofounder') and auth.role()<>'service_role' then return jsonb_build_object('success',false,'error','OWNER_MISMATCH'); end if;
 if p_end_time<=p_start_time then return jsonb_build_object('success',false,'error','INVALID_TIME_RANGE'); end if;
 v_duration_hours:=extract(epoch from (p_end_time-p_start_time))/3600.0;
 if v_duration_hours<=0 or v_duration_hours>24 then return jsonb_build_object('success',false,'error','INVALID_DURATION'); end if;
 v_server_total_price:=round(v_stadium.price_per_hour*v_duration_hours,2);
 if v_server_total_price<=0 then return jsonb_build_object('success',false,'error','INVALID_STADIUM_PRICE'); end if;
 if abs(coalesce(p_total_price,0)-v_server_total_price)>0.01 then return jsonb_build_object('success',false,'error','PRICE_MISMATCH','expected_total_price',v_server_total_price); end if;
 if p_collected_amount<0 or p_collected_amount>v_server_total_price then return jsonb_build_object('success',false,'error','INVALID_COLLECTED_AMOUNT'); end if;
 v_collected:=round(coalesce(p_collected_amount,0),2);
 if p_start_time<v_now-interval '5 minutes' then return jsonb_build_object('success',false,'error','START_TIME_IN_PAST'); end if;
 select * into v_owner from public.users where id=v_actual_owner_id for update;
 
 select count(*) into v_overlap_count from public.bookings where stadium_id=p_stadium_id and status<>'cancelled' and p_start_time<end_time and p_end_time>start_time;
 if v_overlap_count>0 then return jsonb_build_object('success',false,'error','conflict'); end if;
 v_is_paid:=v_collected>=v_server_total_price; v_payment_status:=case when v_is_paid then 'paid' when v_collected>0 then 'partially_paid' else 'pending' end; v_customer_clean:=coalesce(nullif(trim(p_customer_name),''),'حجز يدوي'); v_vsp_commission := 0.00; -- Subscription-only model
 begin
  insert into public.bookings(stadium_id,stadium_name,owner_id,user_id,created_by_user_id,start_time,end_time,booking_type,player_team_name,host_name,player_phone,notes,total_price,vsp_commission,gateway_fee,deposit_paid,is_deposit_paid,is_paid,payment_status,payment_method,payment_transaction_id,status,current_players,is_private,rent_ball,created_at,updated_at)
  values(p_stadium_id,v_stadium.name,v_actual_owner_id,v_actual_owner_id,coalesce(auth.uid(),v_actual_owner_id),p_start_time,p_end_time,'personal',v_customer_clean,v_customer_clean,nullif(trim(p_customer_phone),''),nullif(trim(p_notes),''),v_server_total_price,v_vsp_commission,0,v_collected,(v_collected>0),v_is_paid,v_payment_status,'cash','MANUAL_'||extract(epoch from v_now)::bigint,'confirmed',p_current_players,true,false,v_now,v_now) returning id into v_booking_id;
 exception when unique_violation or exclusion_violation then return jsonb_build_object('success',false,'error','conflict','code','SLOT_LOCKED_OR_TAKEN'); end;
 v_new_debt:=coalesce(v_owner.accumulated_cash_debt,0)+v_vsp_commission; v_is_blocked:=v_new_debt>=coalesce(v_owner.debt_limit,500);
 perform set_config('vsp.system_override','true',true);
 update public.users set accumulated_cash_debt=v_new_debt,is_debt_blocked=v_is_blocked,updated_at=v_now where id=v_actual_owner_id;
 if v_collected>0 then insert into public.transactions(user_id,booking_id,amount,type,status,payment_method,description,created_at,updated_at) values(v_actual_owner_id,v_booking_id,v_collected,'cash','completed','cash','دفع حجز يدوي: '||coalesce(v_stadium.name,'الملعب'),v_now,v_now); end if;
 return jsonb_build_object('success',true,'booking_id',v_booking_id,'total_price',v_server_total_price,'vsp_commission',0,'accumulated_cash_debt',0,'is_debt_blocked',false);
end; $function$;

CREATE OR REPLACE FUNCTION public.confirm_cash_booking_atomic(p_booking_id uuid, p_owner_id uuid, p_total_price numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_booking RECORD;
    v_owner RECORD;
    v_caller_role TEXT;
    v_cash_amount NUMERIC;
    v_commission NUMERIC;
    v_new_debt NUMERIC;
    v_is_blocked BOOLEAN;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Fetch & lock booking row
    SELECT * INTO v_booking 
    FROM public.bookings 
    WHERE id = p_booking_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الحجز غير موجود.');
    END IF;

    -- 2. Authorization check
    IF (COALESCE(auth.role(), '') NOT IN ('service_role')) AND (current_user NOT IN ('postgres', 'service_role')) THEN
        SELECT role INTO v_caller_role 
        FROM public.users 
        WHERE id = auth.uid();

        IF (v_booking.owner_id IS DISTINCT FROM auth.uid()) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح: تأكيد استلام الكاش متاح فقط لمالك هذا الملعب أو إدارة التطبيق.');
        END IF;
    END IF;

    -- 3. Prevent confirming cancelled booking
    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'CANNOT_CONFIRM_CANCELLED_BOOKING: لا يمكن تحصيل حجز ملغي'
            USING ERRCODE = 'P0003', DETAIL = 'BOOKING_CANCELLED';
    END IF;

    -- 4. Idempotency Check
    IF v_booking.is_paid IS TRUE AND v_booking.payment_status = 'paid' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'الحجز مؤكد ومسدد بالفعل مسبقاً.',
            'already_confirmed', true,
            'booking_id', p_booking_id,
            'amount', 0,
            'total_price', v_booking.total_price
        );
    END IF;

    -- 5. Lock owner row
    SELECT * INTO v_owner
    FROM public.users
    WHERE id = v_booking.owner_id
    FOR UPDATE;

    -- 6. Calculate cash amount & commission
    v_cash_amount := GREATEST(0, COALESCE(v_booking.total_price, p_total_price, 0) - COALESCE(v_booking.deposit_paid, 0));
    IF v_cash_amount = 0 AND COALESCE(v_booking.total_price, 0) > 0 THEN
        v_cash_amount := v_booking.total_price;
    END IF;

    v_commission := 0.00; -- Subscription-only: no booking commission;
    v_new_debt := 0.00;
    v_is_blocked := false;
    -- 7. Subscription-only model: no owner debt is accrued.
    -- 8. FIX: Update booking correctly
    -- deposit_paid = المبلغ المحصّل فعلاً (كامل السعر للتحصيل النقدي)
    -- payment_method = 'cash' دايماً في مسار التحصيل اليدوي (مش 'online')
    UPDATE public.bookings
    SET is_paid = true,
        payment_status = 'paid',
        status = 'confirmed',
        payment_method = 'cash',
        vsp_commission = 0.00,
        deposit_paid = v_cash_amount,
        updated_at = v_now
    WHERE id = p_booking_id;

    -- 9. Insert ledger transaction
    INSERT INTO public.transactions (
        user_id,
        booking_id,
        amount,
        type,
        status,
        payment_method,
        description,
        created_at
    ) VALUES (
        v_booking.owner_id,
        p_booking_id,
        v_cash_amount,
        'cash_settlement',
        'completed',
        'cash',
        'تحصيل كاش مؤكد بالملعب لحجز #' || substring(p_booking_id::text, 1, 8),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'already_confirmed', false,
        'booking_id', p_booking_id,
        'amount', v_cash_amount,
        'vsp_commission', v_commission,
        'accumulated_cash_debt', v_new_debt,
        'is_debt_blocked', v_is_blocked,
        'total_price', COALESCE(v_booking.total_price, p_total_price)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_owner_financial_summary(p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_completed_online_rev NUMERIC := 0.0;
    v_escrow_online_rev NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_completed_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_completed_cash_rev NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
    v_debt_limit NUMERIC := 500.0;
    v_is_debt_blocked BOOLEAN := false;
    v_completed_bookings_count INT := 0;
BEGIN
    IF v_caller_id IS NULL AND current_user NOT IN ('postgres', 'service_role') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id != p_owner_id
           AND COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')
           AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized access to financial records');
        END IF;
    END IF;

    SELECT accumulated_cash_debt, debt_limit, is_debt_blocked
    INTO v_accumulated_debt, v_debt_limit, v_is_debt_blocked
    FROM public.users WHERE id = p_owner_id;

    -- ✅ المكتملة فقط - قابلة للسحب
    SELECT
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0),
        COUNT(*)
    INTO v_completed_online_rev, v_total_gateway_fees, v_total_vsp_commission, v_completed_bookings_count
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    -- ⏳ محتجزة - للعرض فقط
    SELECT COALESCE(SUM(total_price), 0.0)
    INTO v_escrow_online_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'confirmed';

    v_net_completed_earnings := v_completed_online_rev; -- compatibility field: owner earnings are gross

    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_completed_online_rev - v_total_withdrawn - v_pending_payouts);

    SELECT COALESCE(SUM(total_price), 0.0) INTO v_completed_cash_rev
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) = 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    RETURN jsonb_build_object(
        'success', true,
        'owner_id', p_owner_id,
        'total_online_revenue', ROUND(v_completed_online_rev + v_escrow_online_rev, 2),
        'completed_online_revenue', ROUND(v_completed_online_rev, 2),
        'escrow_online_revenue', ROUND(v_escrow_online_rev, 2),
        'total_gateway_fees', 0.0,
        'total_vsp_commission', 0.0,
        'net_online_earnings', ROUND(v_completed_online_rev, 2),
        'owner_online_earnings', ROUND(v_completed_online_rev, 2),
        'available_balance', ROUND(v_available_balance, 2),
        'total_withdrawn', ROUND(v_total_withdrawn, 2),
        'pending_payouts', ROUND(v_pending_payouts, 2),
        'cash_revenue', ROUND(v_completed_cash_rev, 2),
        'accumulated_cash_debt', 0.0,
        'debt_limit', 0.0,
        'is_debt_blocked', false,
        'owner_total_revenue', ROUND(v_completed_online_rev + v_completed_cash_rev, 2),
        'completed_bookings_count', v_completed_bookings_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0.0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_new_booking_id UUID;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0;
    v_duration_hours NUMERIC;
    v_final_total_price NUMERIC;
    v_vsp_commission NUMERIC;
    v_gateway_fee NUMERIC := 0.00;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_deposit_paid NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_locked_until TIMESTAMPTZ;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_conflict_count INT;
    v_final_owner_id UUID;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    
    -- Operating hours variables (Cairo local time)
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
BEGIN
    -- 1. Identity & Zero-Trust Caller check
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. Duration validity (30 minutes to 8 hours)
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;

    IF v_duration_hours < 0.5 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تقل عن 30 دقيقة.');
    END IF;

    IF v_duration_hours > 8.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تتجاوز 8 ساعات في المرة الواحدة.');
    END IF;

    -- 3. Concurrency Lock on Stadium (Advisory Lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Verify stadium existence and status
    SELECT * INTO v_stadium
    FROM public.stadiums 
    WHERE id::text = p_stadium_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;

    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;

    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. Operating Hours & Split-Shift Validation (Cairo Local Time)
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;

    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
        ELSE
            -- Overnight shift (e.g. 16:00 to 01:00 next day)
            IF v_start_cairo::time >= v_stadium.opening_time THEN
                v_open_ts := v_date_cairo + v_stadium.opening_time;
                v_close_ts := (v_date_cairo + interval '1 day') + v_stadium.closing_time;
            ELSE
                v_open_ts := (v_date_cairo - interval '1 day') + v_stadium.opening_time;
                v_close_ts := v_date_cairo + v_stadium.closing_time;
            END IF;
        END IF;

        IF v_start_cairo < v_open_ts OR v_end_cairo > v_close_ts THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'OUTSIDE_OPERATING_HOURS',
                'message', 'عذراً، هذا الموعد خارج أوقات عمل الملعب الرسمية (' || v_stadium.opening_time || ' - ' || v_stadium.closing_time || ').'
            );
        END IF;

        -- Split-shift break validation
        IF v_stadium.is_split_shift IS TRUE AND v_stadium.break_start_time IS NOT NULL AND v_stadium.break_end_time IS NOT NULL THEN
            IF v_stadium.break_start_time >= v_stadium.opening_time THEN
                v_break_start_ts := v_open_ts::date + v_stadium.break_start_time;
            ELSE
                v_break_start_ts := (v_open_ts::date + interval '1 day') + v_stadium.break_start_time;
            END IF;

            IF v_stadium.break_end_time >= v_stadium.break_start_time THEN
                v_break_end_ts := v_break_start_ts::date + v_stadium.break_end_time;
            ELSE
                v_break_end_ts := (v_break_start_ts::date + interval '1 day') + v_stadium.break_end_time;
            END IF;

            IF v_start_cairo < v_break_end_ts AND v_end_cairo > v_break_start_ts THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'code', 'OUTSIDE_OPERATING_HOURS',
                    'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).'
                );
            END IF;
        END IF;
    END IF;

    -- 6. Server-Side Price Calculation
    v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
    v_calculated_price := round(v_hourly_rate * v_duration_hours, 2);

    IF p_rent_ball IS TRUE THEN
        BEGIN
            v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0.0);
        EXCEPTION WHEN OTHERS THEN
            v_ball_price := 0.0;
        END;
        v_calculated_price := v_calculated_price + v_ball_price;
    END IF;

    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.'
        );
    END IF;

    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE 
        WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) 
        ELSE 0 
    END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. Calculate Platform Commission and Gateway Fee
    v_vsp_commission := 0.00; -- Subscription-only: owner keeps 100% of booking value;  -- 2% عمولة VSP
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        -- ✅ FIX: 0.0475 → 0.024 (رسوم Paymob الفعلية حسب العقد)
        v_gateway_fee := round((v_final_total_price * 0.024) + 3.0, 2);
    ELSE
        v_gateway_fee := 0.00;
    END IF;

    -- 8. User state & No-show checks
    SELECT is_blocked, COALESCE(no_show_count, 0) 
    INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;

    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;

    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. Cash Booking: no owner commission/debt; retain only player successive-cash restriction.
    IF p_payment_method = 'cash' THEN
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash'
          AND is_paid = FALSE
          AND status IN ('pending', 'confirmed')
          AND end_time > v_now;

        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Conflict detection against active bookings
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SLOT_LOCKED_OR_TAKEN',
            'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.'
        );
    END IF;

    -- 11. Booking status assignment
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := v_now + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 12. Insert Booking Record
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, user_id, created_by_user_id, owner_id,
            start_time, end_time, booking_type, total_price, 
            vsp_commission, gateway_fee, platform_fee,
            stadium_name, stadium_image_url, is_private, rent_ball,
            needs_deposit, deposit_amount, deposit_paid,
            payment_method, payment_status, status, is_paid,
            player_team_id, player_team_name, opponent_team_id, opponent_team_name,
            joined_user_ids, locked_until, created_at, updated_at
        ) VALUES (
            CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
            p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
            p_start_time, p_end_time, p_booking_type, v_final_total_price,
            v_vsp_commission, v_gateway_fee, v_vsp_commission,  -- ✅ FIX: platform_fee = v_vsp_commission
            COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name), 
            COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url), 
            p_is_private, p_rent_ball,
            v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
            p_payment_method, 'pending', v_final_status, v_final_is_paid,
            CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
            p_player_team_name,
            CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
            p_opponent_team_name,
            ARRAY[p_user_id::uuid], v_locked_until, v_now, v_now
        )
        RETURNING id INTO v_new_booking_id;

    -- ✅ FIX: Exception Guard - يمسك Race Condition في اللحظة الأخيرة
    EXCEPTION 
        WHEN unique_violation OR exclusion_violation THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'SLOT_LOCKED_OR_TAKEN',
                'message', 'عذراً، تم حجز هذا الموعد للتو من قِبل لاعب آخر. يرجى اختيار موعد مختلف.'
            );
    END;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'vsp_commission', v_vsp_commission,
        'gateway_fee', v_gateway_fee,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.request_owner_payout_settlement_atomic(p_owner_id uuid, p_amount numeric, p_method text DEFAULT 'instapay'::text, p_destination text DEFAULT ''::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_pending_count INT;
    v_settlement_id UUID;
    v_owner RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_total_online_revenue NUMERIC := 0.0;
    v_total_gateway_fees NUMERIC := 0.0;
    v_total_vsp_commission NUMERIC := 0.0;
    v_net_online_earnings NUMERIC := 0.0;
    v_total_withdrawn NUMERIC := 0.0;
    v_pending_payouts NUMERIC := 0.0;
    v_available_balance NUMERIC := 0.0;
    v_accumulated_debt NUMERIC := 0.0;
BEGIN
    IF (auth.uid() IS NULL AND current_user NOT IN ('postgres', 'service_role')) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Authentication required');
    END IF;

    IF auth.uid() IS NOT NULL AND auth.uid() != p_owner_id AND current_user NOT IN ('postgres', 'service_role') THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin', 'cofounder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'Unauthorized payout request');
        END IF;
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون مبلغ السحب أكبر من الصفر.');
    END IF;

    IF p_destination IS NULL OR LENGTH(TRIM(p_destination)) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'بيانات جهة التحويل مطلوبة.');
    END IF;

    SELECT * INTO v_owner FROM public.users WHERE id = p_owner_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'حساب المالك غير موجود.');
    END IF;

    v_accumulated_debt := COALESCE(v_owner.accumulated_cash_debt, 0.0);

    SELECT COUNT(*) INTO v_pending_count
    FROM public.payout_settlements
    WHERE owner_id = p_owner_id AND status = 'pending';

    IF v_pending_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'لديك طلب تسوية قيد المراجعة بالفعل. يرجى الانتظار حتى اكتماله.');
    END IF;

    -- ✅ من المكتمل فقط - حماية مالية
    SELECT
        COALESCE(SUM(total_price), 0.0),
        COALESCE(SUM(COALESCE(gateway_fee, platform_fee, 0.0)), 0.0),
        COALESCE(SUM(COALESCE(vsp_commission, round(total_price * 0.02, 2))), 0.0)
    INTO v_total_online_revenue, v_total_gateway_fees, v_total_vsp_commission
    FROM public.bookings
    WHERE owner_id = p_owner_id
      AND LOWER(COALESCE(payment_method, '')) != 'cash'
      AND (payment_status = 'paid' OR is_paid = true)
      AND status = 'completed';

    v_net_online_earnings := v_total_online_revenue; -- compatibility field: owner receives 100% of completed online booking value

    SELECT COALESCE(SUM(amount), 0.0) INTO v_total_withdrawn
    FROM public.payout_settlements WHERE owner_id = p_owner_id AND status = 'completed';

    SELECT COALESCE(SUM(amount), 0.0) INTO v_pending_payouts
    FROM public.payout_settlements WHERE owner_id = p_owner_id AND status IN ('pending', 'approved');

    v_available_balance := GREATEST(0.0, v_total_online_revenue - v_total_withdrawn - v_pending_payouts);

    IF p_amount > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'المبلغ المطلوب (' || p_amount || ' ج.م) يتجاوز رصيدك المتاح للسحب (' || ROUND(v_available_balance, 2) || ' ج.م). ملاحظة: مبالغ المباريات القادمة محتجزة حتى تكتمل.'
        );
    END IF;

    INSERT INTO public.payout_settlements (
        owner_id, amount, method, destination, status, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, COALESCE(p_method, 'instapay'), p_destination, 'pending', v_now, v_now
    ) RETURNING id INTO v_settlement_id;

    INSERT INTO public.transactions (
        user_id, amount, type, status, payment_method, metadata, created_at, updated_at
    ) VALUES (
        p_owner_id, p_amount, 'payout_pending', 'pending', COALESCE(p_method, 'instapay'),
        jsonb_build_object(
            'settlement_id', v_settlement_id,
            'destination', p_destination,
            'owner_name', COALESCE(v_owner.name, 'Unknown Owner'),
            'owner_phone', COALESCE(v_owner.phone, ''),
            'remaining_balance_after', ROUND(v_available_balance - p_amount, 2)
        ),
        v_now, v_now
    );

    INSERT INTO public.notifications (user_id, title, body, type, is_read, created_at)
    SELECT id,
        'طلب تسوية أرباح جديد',
        'طلب المالك ' || COALESCE(v_owner.name, 'مالك') || ' تسوية رصيد بقيمة ' || p_amount || ' ج.م عبر ' || p_destination,
        'payout', false, v_now
    FROM public.users WHERE role IN ('admin', 'co_founder');

    RETURN jsonb_build_object(
        'success', true,
        'settlement_id', v_settlement_id,
        'available_balance', ROUND(v_available_balance - p_amount, 2),
        'message', 'تم تقديم طلب سحب الأرباح بنجاح وجارٍ مراجعته من الإدارة.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_booking_atomic(p_stadium_id text, p_user_id text, p_owner_id text, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_booking_type text, p_total_price numeric, p_stadium_name text DEFAULT ''::text, p_stadium_image_url text DEFAULT ''::text, p_is_private boolean DEFAULT true, p_rent_ball boolean DEFAULT false, p_needs_deposit boolean DEFAULT false, p_deposit_amount numeric DEFAULT 0, p_payment_method text DEFAULT 'cash'::text, p_payment_status text DEFAULT 'pending'::text, p_player_team_id text DEFAULT NULL::text, p_player_team_name text DEFAULT NULL::text, p_opponent_team_id text DEFAULT NULL::text, p_opponent_team_name text DEFAULT NULL::text, p_platform_fee numeric DEFAULT 0.0, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_stadium RECORD;
    v_owner RECORD;
    v_new_booking_id UUID;
    v_hourly_rate NUMERIC;
    v_calculated_price NUMERIC;
    v_ball_price NUMERIC := 0;
    v_duration_hours NUMERIC;
    v_final_total_price NUMERIC;
    v_vsp_commission NUMERIC;
    v_gateway_fee NUMERIC := 0.00;
    v_final_needs_deposit BOOLEAN;
    v_final_deposit_amount NUMERIC;
    v_final_deposit_paid NUMERIC;
    v_final_status TEXT;
    v_final_is_paid BOOLEAN;
    v_locked_until TIMESTAMPTZ;
    v_user_blocked BOOLEAN;
    v_no_show_count INT;
    v_active_cash_count INT;
    v_conflict_count INT;
    v_final_owner_id UUID;
    v_caller_id UUID := auth.uid();
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_start_cairo TIMESTAMP;
    v_end_cairo TIMESTAMP;
    v_date_cairo DATE;
    v_open_ts TIMESTAMP;
    v_close_ts TIMESTAMP;
    v_break_start_ts TIMESTAMP;
    v_break_end_ts TIMESTAMP;
    -- Phase 5: Idempotency
    v_existing_booking_id UUID;
    v_existing_status TEXT;
BEGIN
    -- Phase 5: Idempotency Check — return existing booking if key already used
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, status INTO v_existing_booking_id, v_existing_status
        FROM public.bookings
        WHERE idempotency_key = p_idempotency_key
          AND status != 'cancelled'
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'success', true,
                'booking_id', v_existing_booking_id,
                'status', v_existing_status,
                'idempotent', true,
                'message', 'تم إرجاع حجز موجود مسبقاً (idempotent response).'
            );
        END IF;
    END IF;

    -- 1. Identity & Zero-Trust Caller check
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        IF v_caller_id::text <> p_user_id AND (v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'co_founder')) AND current_user NOT IN ('postgres', 'service_role') THEN
            RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بإجراء حجز نيابة عن مستخدم آخر.');
        END IF;
    END IF;

    -- 2. Duration validity
    v_duration_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600.0;
    IF v_duration_hours <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'وقت بداية ونهاية الحجز غير صالح.');
    END IF;
    IF v_duration_hours < 0.5 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تقل عن 30 دقيقة.');
    END IF;
    IF v_duration_hours > 8.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'مدة الحجز لا يمكن أن تتجاوز 8 ساعات في المرة الواحدة.');
    END IF;

    -- 3. Concurrency Lock on Stadium
    PERFORM pg_advisory_xact_lock(hashtext(p_stadium_id));

    -- 4. Verify stadium
    SELECT * INTO v_stadium FROM public.stadiums WHERE id::text = p_stadium_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'الملعب المطلوب غير موجود.');
    END IF;
    IF v_stadium.is_deleted_by_owner IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب محذوف ولا يمكن الحجز فيه.');
    END IF;
    IF v_stadium.is_verified IS NOT TRUE OR v_stadium.is_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، هذا الملعب غير متاح للحجز حالياً أو قيد المراجعة.');
    END IF;

    -- 5. Operating Hours
    v_start_cairo := timezone('Africa/Cairo', p_start_time);
    v_end_cairo := timezone('Africa/Cairo', p_end_time);
    v_date_cairo := v_start_cairo::date;
    IF v_stadium.opening_time IS NOT NULL AND v_stadium.closing_time IS NOT NULL THEN
        IF v_stadium.closing_time > v_stadium.opening_time THEN
            v_open_ts := v_date_cairo + v_stadium.opening_time;
            v_close_ts := v_date_cairo + v_stadium.closing_time;
        ELSE
            IF v_start_cairo::time >= v_stadium.opening_time THEN
                v_open_ts := v_date_cairo + v_stadium.opening_time;
                v_close_ts := (v_date_cairo + interval '1 day') + v_stadium.closing_time;
            ELSE
                v_open_ts := (v_date_cairo - interval '1 day') + v_stadium.opening_time;
                v_close_ts := v_date_cairo + v_stadium.closing_time;
            END IF;
        END IF;
        IF v_start_cairo < v_open_ts OR v_end_cairo > v_close_ts THEN
            RETURN jsonb_build_object('success', false, 'code', 'OUTSIDE_OPERATING_HOURS', 'message', 'عذراً، هذا الموعد خارج أوقات عمل الملعب الرسمية (' || v_stadium.opening_time || ' - ' || v_stadium.closing_time || ').');
        END IF;
        IF v_stadium.is_split_shift IS TRUE AND v_stadium.break_start_time IS NOT NULL AND v_stadium.break_end_time IS NOT NULL THEN
            IF v_stadium.break_start_time >= v_stadium.opening_time THEN
                v_break_start_ts := v_open_ts::date + v_stadium.break_start_time;
            ELSE
                v_break_start_ts := (v_open_ts::date + interval '1 day') + v_stadium.break_start_time;
            END IF;
            IF v_stadium.break_end_time >= v_stadium.break_start_time THEN
                v_break_end_ts := v_break_start_ts::date + v_stadium.break_end_time;
            ELSE
                v_break_end_ts := (v_break_start_ts::date + interval '1 day') + v_stadium.break_end_time;
            END IF;
            IF v_start_cairo < v_break_end_ts AND v_end_cairo > v_break_start_ts THEN
                RETURN jsonb_build_object('success', false, 'code', 'OUTSIDE_OPERATING_HOURS', 'message', 'عذراً، هذا الموعد يتعارض مع فترة راحة الملعب (Shift Break).');
            END IF;
        END IF;
    END IF;

    -- 6. Server-Side Price Calculation
    v_hourly_rate := COALESCE(v_stadium.price_per_hour, v_stadium.base_price, 0);
    v_calculated_price := round(v_hourly_rate * v_duration_hours, 2);
    IF p_rent_ball IS TRUE THEN
        BEGIN
            v_ball_price := COALESCE((v_stadium.features->>'ballPrice')::numeric, 0.0);
        EXCEPTION WHEN OTHERS THEN
            v_ball_price := 0.0;
        END;
        v_calculated_price := v_calculated_price + v_ball_price;
    END IF;
    IF v_calculated_price <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'عذراً، تسعيرة هذا الملعب غير محددة بشكل صحيح في النظام. يرجى التواصل مع إدارة الملعب.');
    END IF;
    v_final_total_price := v_calculated_price;
    v_final_needs_deposit := COALESCE(v_stadium.needs_deposit, false);
    v_final_deposit_amount := CASE WHEN v_final_needs_deposit THEN COALESCE(v_stadium.deposit_amount, 0) ELSE 0 END;
    v_final_owner_id := v_stadium.owner_id;

    -- 7. Commission & Gateway Fee
    v_vsp_commission := 0.00; -- Subscription-only: owner keeps 100% of booking value;
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_gateway_fee := round((v_final_total_price * 0.024) + 3.0, 2);
    ELSE
        v_gateway_fee := 0.00;
    END IF;

    -- 8. User state checks
    SELECT is_blocked, COALESCE(no_show_count, 0) INTO v_user_blocked, v_no_show_count
    FROM public.users WHERE id::text = p_user_id;
    IF v_user_blocked IS TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد حالياً. يرجى التواصل مع إدارة التطبيق.');
    END IF;
    IF p_payment_method = 'cash' AND v_no_show_count >= 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'حسابك مقيد عن الحجز النقدي بسبب تكرار عدم الحضور. يرجى السداد إلكترونياً.');
    END IF;

    -- 9. Cash Debt Limit
    IF p_payment_method = 'cash' THEN
        SELECT accumulated_cash_debt, debt_limit, is_debt_blocked INTO v_owner
        FROM public.users WHERE id = v_final_owner_id;
        IF v_owner.is_debt_blocked IS TRUE OR COALESCE(v_owner.accumulated_cash_debt, 0) >= COALESCE(v_owner.debt_limit, 500.0) THEN
            RETURN jsonb_build_object('success', false, 'code', 'DEBT_LIMIT_EXCEEDED', 'message', 'عذراً، تم إيقاف الحجز النقدي لهذا الملعب مؤقتاً لتجاوز حد المديونية المسموح. يرجى الدفع إلكترونياً.');
        END IF;
        SELECT COUNT(*) INTO v_active_cash_count
        FROM public.bookings
        WHERE (user_id::text = p_user_id OR created_by_user_id::text = p_user_id)
          AND payment_method = 'cash' AND is_paid = FALSE
          AND status IN ('pending', 'confirmed') AND end_time > v_now;
        IF v_active_cash_count > 0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'لديك حجز نقدي نشط بالفعل. يرجى إنهاء الحجز السابق أو الدفع إلكترونياً.');
        END IF;
    END IF;

    -- 10. Conflict detection
    SELECT COUNT(*) INTO v_conflict_count
    FROM public.bookings
    WHERE stadium_id::text = p_stadium_id
      AND status != 'cancelled'
      AND NOT (status = 'pending' AND COALESCE(locked_until, created_at + INTERVAL '5 minutes') < v_now)
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );
    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object('success', false, 'code', 'SLOT_LOCKED_OR_TAKEN', 'message', 'عذراً، هذا الموعد محجوز أو قيد الدفع من قِبل لاعب آخر حالياً.');
    END IF;

    -- 11. Status assignment
    IF p_payment_method IN ('paymob', 'card', 'wallet', 'online') THEN
        v_final_status := 'pending';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := v_now + INTERVAL '5 minutes';
    ELSE
        v_final_status := 'confirmed';
        v_final_is_paid := FALSE;
        v_final_deposit_paid := 0.0;
        v_locked_until := NULL;
    END IF;

    -- 12. Insert Booking
    BEGIN
        INSERT INTO public.bookings (
            stadium_id, user_id, created_by_user_id, owner_id,
            start_time, end_time, booking_type, total_price,
            vsp_commission, gateway_fee, platform_fee,
            stadium_name, stadium_image_url, is_private, rent_ball,
            needs_deposit, deposit_amount, deposit_paid,
            payment_method, payment_status, status, is_paid,
            player_team_id, player_team_name, opponent_team_id, opponent_team_name,
            joined_user_ids, locked_until, idempotency_key, created_at, updated_at
        ) VALUES (
            CASE WHEN p_stadium_id ~ '^[0-9a-fA-F-]{36}$' THEN p_stadium_id::uuid ELSE NULL END,
            p_user_id::uuid, p_user_id::uuid, v_final_owner_id,
            p_start_time, p_end_time, p_booking_type, v_final_total_price,
            v_vsp_commission, v_gateway_fee, v_vsp_commission,
            COALESCE(NULLIF(p_stadium_name, ''), v_stadium.name),
            COALESCE(NULLIF(p_stadium_image_url, ''), v_stadium.image_url),
            p_is_private, p_rent_ball,
            v_final_needs_deposit, v_final_deposit_amount, v_final_deposit_paid,
            p_payment_method, 'pending', v_final_status, v_final_is_paid,
            CASE WHEN p_player_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_player_team_id::uuid ELSE NULL END,
            p_player_team_name,
            CASE WHEN p_opponent_team_id ~ '^[0-9a-fA-F-]{36}$' THEN p_opponent_team_id::uuid ELSE NULL END,
            p_opponent_team_name,
            ARRAY[p_user_id::uuid], v_locked_until, p_idempotency_key, v_now, v_now
        )
        RETURNING id INTO v_new_booking_id;
    EXCEPTION
        WHEN unique_violation OR exclusion_violation THEN
            -- Phase 5: If unique_violation on idempotency_key, return the existing booking
            IF p_idempotency_key IS NOT NULL THEN
                SELECT id, status INTO v_existing_booking_id, v_existing_status
                FROM public.bookings
                WHERE idempotency_key = p_idempotency_key AND status != 'cancelled' LIMIT 1;
                IF FOUND THEN
                    RETURN jsonb_build_object(
                        'success', true,
                        'booking_id', v_existing_booking_id,
                        'status', v_existing_status,
                        'idempotent', true,
                        'message', 'تم إرجاع حجز موجود مسبقاً (idempotent response).'
                    );
                END IF;
            END IF;
            RETURN jsonb_build_object(
                'success', false, 'code', 'SLOT_LOCKED_OR_TAKEN',
                'message', 'عذراً، تم حجز هذا الموعد للتو من قِبل لاعب آخر. يرجى اختيار موعد مختلف.'
            );
    END;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_new_booking_id,
        'status', v_final_status,
        'total_price', v_final_total_price,
        'vsp_commission', v_vsp_commission,
        'gateway_fee', v_gateway_fee,
        'deposit_amount', v_final_deposit_amount,
        'needs_deposit', v_final_needs_deposit,
        'locked_until', v_locked_until,
        'idempotent', false
    );
END;
$function$;

-- Subscription-only owner revenue model: legacy debt is no longer used.
update public.users set accumulated_cash_debt=0, is_debt_blocked=false, updated_at=now() where role='owner';
