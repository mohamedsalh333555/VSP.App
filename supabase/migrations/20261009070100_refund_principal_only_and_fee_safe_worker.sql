-- Refund principal-only policy: fees (percentage or fixed) are not refundable.
-- Canonical principals: vsp_1v1_tournament_orders.amount, tournament_orders.base_amount,
-- team_league_payments.amount. Booking refunds are capped at claim_booking_gateway_refund_atomic.refund_amount.
CREATE OR REPLACE FUNCTION public.leave_1v1_tournament_atomic(p_tournament_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
 v_caller uuid:=auth.uid(); v_t record; v_player record; v_order record;
 v_now timestamptz:=timezone('utc',now()); v_refund_amount numeric; v_manual boolean:=false;
begin
 if v_caller is null then return jsonb_build_object('success',false,'error','يجب تسجيل الدخول أولاً.'); end if;
 select * into v_t from public.vsp_1v1_tournaments where id=p_tournament_id for update;
 if not found then return jsonb_build_object('success',false,'error','البطولة غير موجودة.'); end if;
 if v_t.status<>'registration_open' then return jsonb_build_object('success',false,'error','لا يمكن إلغاء التسجيل بعد إغلاق باب التسجيل أو بدء البطولة.'); end if;
 select * into v_player from public.vsp_1v1_tournament_players where tournament_id=p_tournament_id and user_id=v_caller for update;
 if not found then return jsonb_build_object('success',false,'error','أنت غير مسجل في هذه البطولة.'); end if;
 if coalesce(v_player.payment_status,'')<>'paid' then
   delete from public.vsp_1v1_tournament_players where id=v_player.id;
   return jsonb_build_object('success',true,'status','cancelled_unpaid','message','تم إلغاء التسجيل غير المدفوع.');
 end if;
 select * into v_order from public.vsp_1v1_tournament_orders where id=v_player.payment_order_id and tournament_id=p_tournament_id and user_id=v_caller for update;
 if not found then
   select * into v_order from public.vsp_1v1_tournament_orders where tournament_id=p_tournament_id and user_id=v_caller and payment_status='paid' order by created_at desc limit 1 for update;
 end if;
 if not found then
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_player.id;
   return jsonb_build_object('success',false,'manual_review',true,'error','تعذر العثور على سجل الدفع؛ تم وضع التسجيل للمراجعة اليدوية.');
 end if;
 if v_order.payment_status<>'paid' then return jsonb_build_object('success',true,'already_processing',true,'status',v_order.payment_status); end if;
 if v_order.gross_amount is null or v_order.gross_amount<=0
    or v_order.amount is null or v_order.amount<=0
    or nullif(trim(v_order.paymob_transaction_id),'') is null then
   v_manual:=true; v_refund_amount:=v_order.amount;
   update public.vsp_1v1_tournament_orders set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_failed_manual_review',updated_at=v_now where id=v_player.id;
   insert into public.vsp_1v1_cancellation_refund_queue(tournament_id,order_id,user_id,paymob_transaction_id,amount,status,failure_reason,created_at,updated_at)
   values(p_tournament_id,v_order.id,v_caller,v_order.paymob_transaction_id,v_refund_amount,'failed_manual_review','Missing historical gross_amount; player requested cancellation and manual refund.',v_now,v_now);
   insert into public.transactions(user_id,amount,type,status,payment_method,reference_number,paymob_transaction_id,metadata,description,created_at,updated_at)
   values(v_caller,v_refund_amount,'refund_request','manual_review','paymob','REFUND_'||v_order.order_reference,v_order.paymob_transaction_id,
    jsonb_build_object('order_reference',v_order.order_reference,'paymob_transaction_id',v_order.paymob_transaction_id,'tournament_id',p_tournament_id,'tournament_name',v_t.name,'principal_amount',v_order.amount,'gross_amount',null,'player_requested',true,'requires_manual_review',true),
    'طلب استرداد رسوم بطولة 1v1 بناءً على إلغاء اللاعب - مراجعة يدوية',v_now,v_now);
 else
   v_refund_amount:=round(v_order.amount,2);
   update public.vsp_1v1_tournament_orders set payment_status='refund_requested',updated_at=v_now where id=v_order.id;
   update public.vsp_1v1_tournament_players set payment_status='refund_requested',updated_at=v_now where id=v_player.id;
   insert into public.vsp_1v1_cancellation_refund_queue(tournament_id,order_id,user_id,paymob_transaction_id,amount,status,failure_reason,created_at,updated_at)
   values(p_tournament_id,v_order.id,v_caller,v_order.paymob_transaction_id,v_refund_amount,'pending','Player requested tournament cancellation and refund.',v_now,v_now);
   insert into public.transactions(user_id,amount,type,status,payment_method,reference_number,paymob_transaction_id,metadata,description,created_at,updated_at)
   values(v_caller,v_refund_amount,'refund_request','pending','paymob','REFUND_'||v_order.order_reference,v_order.paymob_transaction_id,
    jsonb_build_object('order_reference',v_order.order_reference,'paymob_transaction_id',v_order.paymob_transaction_id,'tournament_id',p_tournament_id,'tournament_name',v_t.name,'principal_amount',v_order.amount,'refund_amount',v_refund_amount,'original_gross_amount',v_order.gross_amount,'non_refundable_fee_amount',round(greatest(v_order.gross_amount-v_refund_amount,0),2),'player_requested',true),
    'طلب استرداد رسوم بطولة 1v1 بناءً على إلغاء اللاعب',v_now,v_now);
   -- Remove the refunded principal from the prize pool once, under the tournament/order locks.
   update public.vsp_1v1_tournaments
   set prize_pool = greatest(coalesce(prize_pool,0) - v_refund_amount,0), updated_at = v_now
   where id = p_tournament_id;
 end if;
 insert into public.notifications(user_id,title,body,type,created_at) values(v_caller,'تم تسجيل طلب إلغاء واسترداد رسوم البطولة 💳','تم إلغاء تسجيلك من '||coalesce(v_t.name,'بطولة 1v1')||' و'||case when v_manual then 'وضع طلب الاسترداد للمراجعة اليدوية.' else 'إنشاء طلب استرداد رسمي وسيتم تحديثك عند اكتماله.' end,'tournament_refund',v_now);
 return jsonb_build_object('success',true,'status',case when v_manual then 'refund_failed_manual_review' else 'refund_requested' end,'refund_amount',v_refund_amount,'manual_review',v_manual,'message',case when v_manual then 'تم إلغاء التسجيل ووضع الاسترداد للمراجعة اليدوية.' else 'تم إلغاء التسجيل وإنشاء طلب الاسترداد.' end);
end; $function$;


CREATE OR REPLACE FUNCTION public.cancel_1v1_tournament_with_refund_requests(p_tournament_id uuid, p_reason text DEFAULT 'إلغاء البطولة'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_role TEXT;
  v_t RECORD;
  v_rec RECORD;
  v_count INT := 0;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_refund_amt NUMERIC;
  v_is_manual_review BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول'); 
  END IF;

  SELECT role INTO v_role FROM public.users WHERE id = v_uid;
  IF v_role NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') AND current_user NOT IN ('postgres', 'service_role') THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: صلاحية الإلغاء للأدمن فقط');
  END IF;

  SELECT * INTO v_t FROM public.vsp_1v1_tournaments WHERE id = p_tournament_id FOR UPDATE;
  IF NOT FOUND THEN 
    RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة'); 
  END IF;
  
  IF v_t.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكن إلغاء بطولة منتهية أو ملغاة بالفعل');
  END IF;

  -- Process refund queue items for all paid players strictly using historical gross_amount
  FOR v_rec IN 
    SELECT * FROM public.vsp_1v1_tournament_orders
    WHERE tournament_id = p_tournament_id AND payment_status = 'paid'
  LOOP
    v_count := v_count + 1;
    
    -- 🛡️ Gate 8 Rule: Automated refund strictly uses gross_amount. If NULL/<=0 -> manual review, NO fallback to base amount
    IF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0
       OR v_rec.amount IS NULL OR v_rec.amount <= 0
       OR nullif(trim(v_rec.paymob_transaction_id),'') IS NULL THEN
      v_is_manual_review := TRUE;
      v_refund_amt := v_rec.amount; -- Keep base amount recorded for manual review reference

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_failed_manual_review',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        failure_reason,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'failed_manual_review',
        'Missing historical gross_amount; manual refund review required',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'manual_review',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'principal_amount', v_rec.amount,
          'gross_amount', null,
          'requires_manual_review', true,
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 يتطلب مراجعة يدوية لغياب المبلغ التاريخي الإجمالي',
        v_now, v_now
      );

    ELSE
      v_is_manual_review := FALSE;
      v_refund_amt := round(v_rec.amount,2);

      UPDATE public.vsp_1v1_tournament_orders
      SET payment_status = 'refund_requested',
          updated_at = v_now
      WHERE id = v_rec.id;

      INSERT INTO public.vsp_1v1_cancellation_refund_queue (
        tournament_id,
        order_id,
        user_id,
        paymob_transaction_id,
        amount,
        status,
        created_at,
        updated_at
      ) VALUES (
        p_tournament_id,
        v_rec.id,
        v_rec.user_id,
        v_rec.paymob_transaction_id,
        v_refund_amt,
        'pending',
        v_now,
        v_now
      );

      INSERT INTO public.transactions (
        user_id, amount, type, status, 
        payment_method, reference_number, paymob_transaction_id,
        metadata, description, created_at, updated_at
      ) VALUES (
        v_rec.user_id, v_refund_amt, 'refund_request', 'pending',
        'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
        jsonb_build_object(
          'order_reference', v_rec.order_reference,
          'paymob_transaction_id', v_rec.paymob_transaction_id,
          'tournament_id', p_tournament_id,
          'tournament_name', v_t.name,
          'refund_amount', v_refund_amt,
          'principal_amount', v_rec.amount,
          'original_gross_amount', v_rec.gross_amount,
          'non_refundable_fee_amount', round(greatest(v_rec.gross_amount-v_refund_amt,0),2),
          'reason', coalesce(p_reason, 'إلغاء البطولة')
        ),
        'طلب استرداد رسوم بطولة 1v1 عبر باي موب لإلغاء الدورة بقرار الإدارة',
        v_now, v_now
      );
    END IF;

    INSERT INTO public.notifications (
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء البطولة وطلب استرداد الرسوم 💳',
      'تم إلغاء ' || coalesce(v_t.name, 'بطولة 1v1') || ' لظروف تنظيمية، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amt || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.',
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.vsp_1v1_tournaments
  SET status = 'cancelled',
      prize_pool = 0,
      updated_at = v_now
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء البطولة ومعالجة طلبات استرداد الرسوم بنجاح',
    'refunded_count', v_count
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_championship_atomic(p_championship_id uuid, p_reason text DEFAULT 'Cancelled by owner'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_champ RECORD;
  v_order RECORD;
  v_refunds_count INT := 0;
BEGIN
  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = p_championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'error', 'championship_not_found'); END IF;

  IF v_champ.owner_id != auth.uid() AND NOT public.is_admin_or_cofounder(auth.uid()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized_not_owner');
  END IF;

  IF v_champ.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'terminal_status_cannot_cancel');
  END IF;

  -- 1. Lock and update status to cancelled
  UPDATE public.championships
  SET status = 'cancelled',
      prize_pool = 0,
      registration_locked_at = coalesce(registration_locked_at, now()),
      updated_at = now()
  WHERE id = p_championship_id;

  -- 2. Mark active registrations as cancelled/refund_pending
  UPDATE public.championship_registrations
  SET registration_status = 'cancelled',
      payment_status = CASE WHEN payment_status = 'paid' THEN 'refund_pending' ELSE payment_status END,
      updated_at = now()
  WHERE championship_id = p_championship_id;

  -- 3. Cancel all pending orders so no webhook can confirm them later
  UPDATE public.tournament_orders
  SET payment_status = 'cancelled',
      updated_at = now()
  WHERE championship_id = p_championship_id
    AND payment_status = 'pending';

  -- 4. Queue refunds for paid orders (gross_amount > 0 only)
  FOR v_order IN 
    SELECT o.id, o.registration_id, o.base_amount, o.gross_amount, o.currency, o.paymob_transaction_id
    FROM public.tournament_orders o
    WHERE o.championship_id = p_championship_id
      AND o.payment_status = 'paid'
      AND coalesce(o.gross_amount, 0) > 0
  LOOP
    UPDATE public.tournament_orders
    SET payment_status = CASE
          WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
          THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        updated_at = now()
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE
          WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
          THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        updated_at = now()
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, failure_reason
    )
    VALUES (
      p_championship_id, v_order.id, v_order.registration_id, v_order.paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
           THEN 'pending' ELSE 'failed_manual_review' END,
      CASE WHEN coalesce(v_order.base_amount,0) > 0 AND nullif(trim(v_order.paymob_transaction_id),'') IS NOT NULL
           THEN NULL ELSE 'Missing historical principal amount or Paymob transaction ID; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    v_refunds_count := v_refunds_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'cancelled',
    'effective_phase', 'cancelled',
    'queued_refunds_count', v_refunds_count
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.cancel_team_league(p_championship_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE 
  v_uid UUID := auth.uid(); 
  v_owner UUID; 
  v_paid_count INT; 
  v_status TEXT;
  v_name TEXT;
  v_rec RECORD;
  v_now TIMESTAMPTZ := timezone('utc', now());
  v_queue_status TEXT;
  v_payment_status TEXT;
  v_tx_status TEXT;
  v_refund_amount NUMERIC;
  v_failure_reason TEXT;
  v_notif_body TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'يجب تسجيل الدخول'; END IF;
  
  SELECT owner_id, status, name, cardinality(coalesce(paid_teams, '{}'::text[]))
    INTO v_owner, v_status, v_name, v_paid_count
  FROM public.championships
  WHERE id = p_championship_id AND template_type = 'team_league'
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'الدوري غير موجود'; END IF;
  IF v_owner <> v_uid THEN RAISE EXCEPTION 'فقط منشئ الدوري يستطيع إلغاءه'; END IF;
  IF v_status <> 'open' THEN RAISE EXCEPTION 'لا يمكن إلغاء الدوري بعد بدء المنافسات'; END IF;

  FOR v_rec IN 
    SELECT * FROM public.team_league_payments 
    WHERE championship_id = p_championship_id AND payment_status = 'paid'
  LOOP
    -- Determine refund eligibility and exact historical gross
    IF v_rec.paymob_transaction_id IS NULL OR trim(v_rec.paymob_transaction_id) = '' THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing paymob_transaction_id; manual review required';
      v_refund_amount := round(coalesce(v_rec.amount,0),2);
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSIF v_rec.gross_amount IS NULL OR v_rec.gross_amount <= 0
       OR v_rec.amount IS NULL OR v_rec.amount <= 0 THEN
      v_queue_status := 'failed_manual_review';
      v_payment_status := 'refund_failed_manual_review';
      v_tx_status := 'manual_review';
      v_failure_reason := 'Missing valid historical gross_amount; manual review required';
      v_refund_amount := v_rec.amount;
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وجارٍ مراجعة طلب استرداد الرسوم يدوياً من قِبل إدارة التطبيق.';
    ELSE
      v_queue_status := 'pending';
      v_payment_status := 'refund_requested';
      v_tx_status := 'pending';
      v_failure_reason := NULL;
      v_refund_amount := round(v_rec.amount,2);
      v_notif_body := 'تم إلغاء ' || coalesce(v_name, 'الدوري') || ' لعدم اكتمال الفرق، وتم رفع طلب استرداد رسمي لمبلغ (' || v_refund_amount || ' ج.م) عبر باي موب لإعادتها إلى وسيلة الدفع الخاصة بك.';
    END IF;

    UPDATE public.team_league_payments
    SET payment_status = v_payment_status,
        updated_at = v_now
    WHERE id = v_rec.id;

    INSERT INTO public.team_league_cancellation_refund_queue (
      championship_id,
      payment_id,
      user_id,
      paymob_transaction_id,
      amount,
      status,
      failure_reason,
      created_at,
      updated_at
    ) VALUES (
      p_championship_id,
      v_rec.id,
      v_rec.user_id,
      v_rec.paymob_transaction_id,
      v_refund_amount,
      v_queue_status,
      v_failure_reason,
      v_now,
      v_now
    );

    INSERT INTO public.transactions(
      user_id, championship_id, amount, type, status, 
      payment_method, reference_number, paymob_transaction_id,
      metadata, description, created_at, updated_at
    ) VALUES (
      v_rec.user_id, p_championship_id, v_refund_amount, 'refund_request', v_tx_status,
      'paymob', 'REFUND_' || v_rec.order_reference, v_rec.paymob_transaction_id,
      jsonb_build_object(
        'order_reference', v_rec.order_reference,
        'paymob_transaction_id', v_rec.paymob_transaction_id,
        'reason', 'league_cancelled_before_completion',
        'league_name', v_name,
        'refund_principal', v_refund_amount,
        'original_gross_amount', v_rec.gross_amount,
        'non_refundable_fee_amount', round(greatest(coalesce(v_rec.gross_amount,v_rec.amount)-v_refund_amount,0),2),
        'requires_manual_review', (v_queue_status = 'failed_manual_review')
      ),
      CASE 
        WHEN v_queue_status = 'failed_manual_review' THEN 'طلب استرداد رسوم دوري الفرق (يتطلب مراجعة يدوية)'
        ELSE 'طلب استرداد رسوم دوري الفرق عبر باي موب لإلغاء الدوري لعدم اكتمال الفرق'
      END,
      v_now, v_now
    );

    INSERT INTO public.notifications(
      user_id, title, body, type, created_at
    ) VALUES (
      v_rec.user_id,
      'إلغاء الدوري وطلب استرداد الرسوم 💳',
      v_notif_body,
      'tournament_refund',
      v_now
    );
  END LOOP;

  UPDATE public.championships
  SET status = 'cancelled',
      updated_at = v_now
  WHERE id = p_championship_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'تم إلغاء الدوري وتسجيل طلبات استرداد الرسوم بنجاح',
    'refund_requests_count', v_paid_count
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.confirm_tournament_order_atomic(p_order_reference text, p_paymob_transaction_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_is_service_role boolean := (COALESCE(auth.jwt() ->> 'role', auth.role(), '') = 'service_role');
  v_caller_id       uuid := auth.uid();
  v_caller_role     text;
  v_order           RECORD;
  v_champ           RECORD;
  v_joined_count    INT;
  v_roster_id       UUID;
BEGIN
  -- Strict Authorization: Only service_role (e.g. paymob webhook) OR Admin/Co-founder
  -- Classic Security Definer Fix: NEVER use current_user which resolves to 'postgres'
  IF NOT v_is_service_role THEN
    IF v_caller_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'تسجيل الدخول مطلوب.');
    END IF;

    SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
    IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'cofounder', 'super_admin') THEN
      RETURN jsonb_build_object(
        'success', false, 
        'error', 'UNAUTHORIZED_ADMIN_OR_SERVICE_ROLE_ONLY', 
        'message', 'غير مصرح: تأكيد سداد البطولات مقتصر على السيرفر أو إدارة التطبيق فقط.'
      );
    END IF;
  END IF;

  -- Transaction ID is strictly mandatory
  IF p_paymob_transaction_id IS NULL OR trim(p_paymob_transaction_id) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PAYMOB_TRANSACTION_ID_REQUIRED');
  END IF;

  SELECT * INTO v_order 
  FROM public.tournament_orders 
  WHERE order_reference = p_order_reference 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'tournament_order_not_found');
  END IF;

  -- 1. Idempotent Success
  IF v_order.payment_status = 'paid' THEN
    RETURN jsonb_build_object('success', true, 'already_confirmed', true, 'order_id', v_order.id);
  END IF;

  -- 2. Strict Source Guard: ONLY 'pending' can be confirmed!
  IF v_order.payment_status <> 'pending' THEN
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'invalid_order_status_for_confirmation', 
      'current_status', v_order.payment_status
    );
  END IF;

  SELECT * INTO v_champ 
  FROM public.championships 
  WHERE id = v_order.championship_id 
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'championship_not_found');
  END IF;

  -- If championship was cancelled while payment was pending in gateway
  IF v_champ.status = 'cancelled' THEN
    UPDATE public.tournament_orders
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        registration_status = 'cancelled',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at, failure_reason
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'pending' ELSE 'failed_manual_review' END,
      timezone('utc', now()), timezone('utc', now()),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN NULL ELSE 'Missing historical base_amount; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_cancelled_payment_refunded',
      'needs_refund', true,
      'amount', coalesce(nullif(v_order.base_amount,0),v_order.gross_amount),
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Capacity & Open Status Check
  SELECT count(*)::INT INTO v_joined_count
  FROM public.championship_registrations
  WHERE championship_id = v_order.championship_id AND registration_status = 'confirmed';

  IF v_champ.status != 'open' OR v_joined_count >= v_champ.max_teams THEN
    UPDATE public.tournament_orders
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'failed_over_capacity' ELSE 'refund_failed_manual_review' END,
        paymob_transaction_id = p_paymob_transaction_id,
        updated_at = timezone('utc', now())
    WHERE id = v_order.id;

    UPDATE public.championship_registrations
    SET payment_status = CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'refund_pending' ELSE 'refund_failed_manual_review' END,
        registration_status = 'rejected',
        notes = 'over_capacity',
        updated_at = timezone('utc', now())
    WHERE id = v_order.registration_id;

    INSERT INTO public.cancellation_refund_queue (
      championship_id, order_id, registration_id, paymob_transaction_id,
      amount, currency, status, created_at, updated_at, failure_reason
    )
    VALUES (
      v_order.championship_id, v_order.id, v_order.registration_id, p_paymob_transaction_id,
      coalesce(nullif(v_order.base_amount,0), v_order.gross_amount), coalesce(v_order.currency, 'EGP'),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN 'pending' ELSE 'failed_manual_review' END,
      timezone('utc', now()), timezone('utc', now()),
      CASE WHEN coalesce(v_order.base_amount,0) > 0 THEN NULL ELSE 'Missing historical base_amount; manual review required' END
    )
    ON CONFLICT (order_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'championship_full_or_closed_refund_queued',
      'needs_refund', true,
      'amount', coalesce(nullif(v_order.base_amount,0),v_order.gross_amount),
      'paymob_transaction_id', p_paymob_transaction_id
    );
  END IF;

  -- Transition to Paid
  UPDATE public.tournament_orders
  SET payment_status = 'paid',
      paymob_transaction_id = p_paymob_transaction_id,
      updated_at = timezone('utc', now())
  WHERE id = v_order.id;

  UPDATE public.championship_registrations
  SET registration_status = 'confirmed',
      payment_status = 'paid',
      gross_amount = v_order.gross_amount,
      updated_at = timezone('utc', now())
  WHERE id = v_order.registration_id;

  INSERT INTO public.championship_rosters (
    registration_id, championship_id, team_id, guest_names, created_at
  )
  VALUES (
    v_order.registration_id, v_order.championship_id, v_order.team_id,
    to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[])), timezone('utc', now())
  )
  ON CONFLICT (registration_id) DO UPDATE SET
    guest_names = to_jsonb(coalesce(v_order.guest_names, ARRAY[]::TEXT[]))
  RETURNING id INTO v_roster_id;

  DELETE FROM public.championship_roster_players WHERE roster_id = v_roster_id;
  IF v_order.player_ids IS NOT NULL AND array_length(v_order.player_ids, 1) > 0 THEN
    INSERT INTO public.championship_roster_players (roster_id, player_id)
    SELECT v_roster_id, unnest(v_order.player_ids);
  END IF;

  UPDATE public.championships
  SET joined_teams = array_append(coalesce(joined_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      paid_teams = array_append(coalesce(paid_teams, ARRAY[]::TEXT[]), v_order.team_id::TEXT),
      prize_pool = coalesce(prize_pool, 0) + coalesce(v_order.base_amount, v_order.amount),
      updated_at = timezone('utc', now())
  WHERE id = v_order.championship_id
    AND NOT (v_order.team_id::TEXT = ANY(coalesce(joined_teams, ARRAY[]::TEXT[])));

  INSERT INTO public.transactions (
    championship_id, user_id, amount, type, payment_method, status, description, metadata, created_at, updated_at
  )
  VALUES (
    v_order.championship_id, v_order.captain_user_id, v_order.gross_amount, 'digital', 'paymob', 'completed',
    'رسوم اشتراك في بطولة: ' || v_champ.name,
    jsonb_build_object(
      'order_id', v_order.id,
      'order_reference', v_order.order_reference,
      'paymob_transaction_id', p_paymob_transaction_id,
      'base_amount', v_order.base_amount,
      'platform_fee_amount', v_order.platform_fee_amount,
      'gateway_fee_amount', v_order.gateway_fee_amount,
      'gross_amount', v_order.gross_amount
    ),
    timezone('utc', now()), timezone('utc', now())
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order.id,
    'payment_status', 'paid',
    'registration_status', 'confirmed',
    'joined_count', v_joined_count + 1
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.record_1v1_refund_status_atomic(p_order_reference text, p_refund_success boolean, p_paymob_refund_id text DEFAULT NULL::text, p_error_message text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_order record; v_now timestamptz:=timezone('utc',now()); v_amount numeric; v_admin_id uuid;
begin
 if current_user not in ('postgres','service_role') and coalesce(auth.role(),'')<>'service_role' then return jsonb_build_object('success',false,'error','غير مصرح.'); end if;
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
end; $function$;


-- One-time repair of old pending requests that recorded gross charge rather than refundable principal.
-- Only untouched pending rows are corrected; processing/completed/manual-review rows are never rewritten.
WITH affected AS (
  SELECT q.tournament_id, o.amount AS principal_amount
  FROM public.vsp_1v1_cancellation_refund_queue q
  JOIN public.vsp_1v1_tournament_orders o ON o.id=q.order_id
  WHERE q.status='pending' AND q.retry_count=0
    AND coalesce(o.amount,0)>0 AND coalesce(o.gross_amount,0)>o.amount
    AND abs(q.amount-o.gross_amount)<=0.01
)
UPDATE public.vsp_1v1_tournaments t
SET prize_pool = greatest(coalesce(t.prize_pool,0)-a.principal_total,0),
    updated_at = timezone('utc',now())
FROM (SELECT tournament_id,sum(principal_amount) AS principal_total FROM affected GROUP BY tournament_id) a
WHERE t.id=a.tournament_id;

UPDATE public.transactions tr
SET amount=o.amount,
    metadata=(coalesce(tr.metadata,'{}'::jsonb)-'gross_amount') ||
      jsonb_build_object('refund_amount',o.amount,'principal_amount',o.amount,
        'original_gross_amount',o.gross_amount,
        'non_refundable_fee_amount',round(greatest(o.gross_amount-o.amount,0),2)),
    updated_at=timezone('utc',now())
FROM public.vsp_1v1_cancellation_refund_queue q
JOIN public.vsp_1v1_tournament_orders o ON o.id=q.order_id
WHERE tr.type='refund_request' AND tr.status='pending'
  AND tr.user_id=o.user_id AND tr.paymob_transaction_id=q.paymob_transaction_id
  AND tr.metadata->>'order_reference'=o.order_reference
  AND q.status='pending' AND q.retry_count=0
  AND coalesce(o.amount,0)>0 AND coalesce(o.gross_amount,0)>o.amount
  AND abs(q.amount-o.gross_amount)<=0.01;

UPDATE public.transactions tr
SET amount=o.base_amount,
    metadata=(coalesce(tr.metadata,'{}'::jsonb)-'gross_amount') ||
      jsonb_build_object('refund_amount',o.base_amount,'principal_amount',o.base_amount,
        'original_gross_amount',o.gross_amount,
        'non_refundable_fee_amount',round(greatest(o.gross_amount-o.base_amount,0),2)),
    updated_at=timezone('utc',now())
FROM public.cancellation_refund_queue q
JOIN public.tournament_orders o ON o.id=q.order_id
WHERE tr.type='refund_request' AND tr.status='pending'
  AND tr.paymob_transaction_id=q.paymob_transaction_id
  AND q.status='pending' AND q.retry_count=0
  AND coalesce(o.base_amount,0)>0 AND coalesce(o.gross_amount,0)>o.base_amount
  AND abs(q.amount-o.gross_amount)<=0.01;

UPDATE public.transactions tr
SET amount=p.amount,
    metadata=(coalesce(tr.metadata,'{}'::jsonb)-'gross_amount') ||
      jsonb_build_object('refund_amount',p.amount,'principal_amount',p.amount,
        'original_gross_amount',p.gross_amount,
        'non_refundable_fee_amount',round(greatest(p.gross_amount-p.amount,0),2)),
    updated_at=timezone('utc',now())
FROM public.team_league_cancellation_refund_queue q
JOIN public.team_league_payments p ON p.id=q.payment_id
WHERE tr.type='refund_request' AND tr.status='pending'
  AND tr.paymob_transaction_id=q.paymob_transaction_id
  AND q.status='pending' AND q.retry_count=0
  AND coalesce(p.amount,0)>0 AND coalesce(p.gross_amount,0)>p.amount
  AND abs(q.amount-p.gross_amount)<=0.01;

UPDATE public.vsp_1v1_cancellation_refund_queue q
SET amount=o.amount, updated_at=timezone('utc',now())
FROM public.vsp_1v1_tournament_orders o
WHERE o.id=q.order_id AND q.status='pending' AND q.retry_count=0
  AND coalesce(o.amount,0)>0 AND coalesce(o.gross_amount,0)>o.amount
  AND abs(q.amount-o.gross_amount)<=0.01;

UPDATE public.cancellation_refund_queue q
SET amount=o.base_amount, updated_at=timezone('utc',now())
FROM public.tournament_orders o
WHERE o.id=q.order_id AND q.status='pending' AND q.retry_count=0
  AND coalesce(o.base_amount,0)>0 AND coalesce(o.gross_amount,0)>o.base_amount
  AND abs(q.amount-o.gross_amount)<=0.01;

UPDATE public.team_league_cancellation_refund_queue q
SET amount=p.amount, updated_at=timezone('utc',now())
FROM public.team_league_payments p
WHERE p.id=q.payment_id AND q.status='pending' AND q.retry_count=0
  AND coalesce(p.amount,0)>0 AND coalesce(p.gross_amount,0)>p.amount
  AND abs(q.amount-p.gross_amount)<=0.01;

