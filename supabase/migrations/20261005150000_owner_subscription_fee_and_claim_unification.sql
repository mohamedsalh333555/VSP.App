-- Unify paid web subscription accounting and app claim behavior.
create index if not exists idx_owner_sub_orders_web_status_created
  on public.owner_subscription_orders(payment_source,status,created_at desc);

create index if not exists idx_owner_sub_orders_claim_contact
  on public.owner_subscription_orders(lower(checkout_email),checkout_phone)
  where status='paid' and owner_id is null;

create or replace function public.claim_paid_web_subscription_for_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user public.users%rowtype;
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz := now();
  v_expires timestamptz;
begin
  if p_user_id is null then return jsonb_build_object('success',false,'error','NO_USER_ID'); end if;

  select * into v_user from public.users where id=p_user_id for update;
  if not found then return jsonb_build_object('success',false,'error','USER_NOT_FOUND'); end if;

  select * into v_order
  from public.owner_subscription_orders
  where status='paid'
    and owner_id is null
    and lower(trim(checkout_email))=lower(trim(v_user.email))
    and nullif(trim(checkout_phone),'') is not null
    and nullif(trim(v_user.phone),'') is not null
    and regexp_replace(checkout_phone,'[^0-9+]','','g')=regexp_replace(v_user.phone,'[^0-9+]','','g')
    and (claim_expires_at is null or claim_expires_at>v_now)
  order by paid_at desc
  limit 1
  for update skip locked;

  if not found then return jsonb_build_object('success',false,'error','NO_MATCHING_PAID_WEB_SUBSCRIPTION'); end if;

  v_expires:=greatest(v_now,coalesce(v_user.subscription_expires_at,v_now))
    + make_interval(days=>coalesce(v_order.duration_days,case when v_order.billing_period='annual' then 365 else 30 end));

  update public.owner_subscription_orders set owner_id=p_user_id where id=v_order.id and owner_id is null;
  if not found then return jsonb_build_object('success',false,'error','SUBSCRIPTION_ALREADY_CLAIMED'); end if;

  update public.users
  set role='owner',subscription_plan=v_order.plan_code,subscription_expires_at=v_expires,trial_ends_at=null,updated_at=v_now
  where id=p_user_id;

  insert into public.notifications(user_id,title,body,type,is_read,metadata,created_at)
  values(
    p_user_id,
    'تم تفعيل اشتراك Pro',
    format('تم ربط اشتراك Pro المدفوع من الموقع بحسابك بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo','DD FMMonth YYYY')),
    'subscription_activated',
    false,
    jsonb_build_object('order_id',v_order.id,'payment_source',v_order.payment_source,'plan_code',v_order.plan_code,'gross_amount',v_order.gross_amount),
    v_now
  );

  return jsonb_build_object('success',true,'order_id',v_order.id,'plan_code',v_order.plan_code,'subscription_expires_at',v_expires);
end;
$$;

create or replace function public.confirm_owner_subscription_payment(
  p_order_id uuid,
  p_paymob_transaction_id text,
  p_gross_amount numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_order public.owner_subscription_orders%rowtype;
  v_now timestamptz:=now();
  v_expires timestamptz;
  v_claim jsonb;
  v_expected_gross numeric;
begin
  select * into v_order from public.owner_subscription_orders where id=p_order_id for update;
  if not found then return jsonb_build_object('success',false,'error','ORDER_NOT_FOUND'); end if;
  if v_order.status='paid' then return jsonb_build_object('success',true,'already_paid',true,'order_id',p_order_id); end if;
  if v_order.status<>'pending' then return jsonb_build_object('success',false,'error','ORDER_NOT_PENDING'); end if;

  v_expected_gross:=coalesce(v_order.gross_amount,v_order.amount);
  if abs(coalesce(v_expected_gross,0)-coalesce(p_gross_amount,0))>0.01 then
    return jsonb_build_object('success',false,'error','AMOUNT_MISMATCH');
  end if;

  update public.owner_subscription_orders
  set status='paid',paymob_transaction_id=p_paymob_transaction_id,paid_at=v_now
  where id=p_order_id;

  if v_order.owner_id is not null then
    v_expires:=greatest(v_now,coalesce((select subscription_expires_at from public.users where id=v_order.owner_id),v_now))
      + make_interval(days=>coalesce(v_order.duration_days,case when v_order.billing_period='annual' then 365 else 30 end));

    update public.users
    set role='owner',subscription_plan=v_order.plan_code,subscription_expires_at=v_expires,trial_ends_at=null,updated_at=v_now
    where id=v_order.owner_id;

    insert into public.notifications(user_id,title,body,type,is_read,metadata,created_at)
    values(
      v_order.owner_id,
      'تم تفعيل اشتراك Pro',
      format('تم تأكيد دفع اشتراك Pro بنجاح. تاريخ الانتهاء: %s.', to_char(v_expires at time zone 'Africa/Cairo','DD FMMonth YYYY')),
      'subscription_activated',
      false,
      jsonb_build_object('order_id',v_order.id,'payment_source',v_order.payment_source,'plan_code',v_order.plan_code,'gross_amount',v_order.gross_amount,'paymob_transaction_id',p_paymob_transaction_id),
      v_now
    );
  else
    select public.claim_paid_web_subscription_for_user(u.id) into v_claim
    from public.users u
    where lower(trim(u.email))=lower(trim(v_order.checkout_email))
      and nullif(trim(u.phone),'') is not null
      and nullif(trim(v_order.checkout_phone),'') is not null
      and regexp_replace(u.phone,'[^0-9+]','','g')=regexp_replace(v_order.checkout_phone,'[^0-9+]','','g')
    order by u.created_at desc
    limit 1;
  end if;

  return jsonb_build_object(
    'success',true,'already_paid',false,'order_id',p_order_id,
    'owner_id',(select owner_id from public.owner_subscription_orders where id=p_order_id),
    'status','paid','paid_at',v_now,'claimed',coalesce(v_claim->>'success','false')='true'
  );
end;
$$;
