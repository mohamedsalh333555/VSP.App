-- An in-app payment receipt is a consequence of a server-recorded Paymob
-- transaction linked to a valid, HMAC-verified successful webhook event.
-- It is never produced from client-controlled is_paid/payment_status alone.
-- No payment commission, payment amount, or booking status is changed.
create unique index if not exists verified_paymob_booking_notice_once_per_user_tx
on public.notifications (user_id,((metadata->>'payment_transaction_id')))
where metadata->>'source'='booking'
  and metadata->>'event'='paymob_payment_confirmed'
  and metadata ? 'payment_transaction_id';

create or replace function vsp_notifications_private.notify_verified_paymob_payment()
returns trigger
language plpgsql security definer set search_path='' as $$
declare
  v_tx record;
  v_owner_id uuid;
  v_stadium_name text;
  v_body text;
  v_receipt_kind text;
  v_receiver uuid;
begin
  -- This is the *server-confirmed* ledger update, never the browser result,
  -- an unverified HMAC callback, or a cash booking.
  if new.webhook_verified is distinct from true
      or nullif(btrim(coalesce(new.paymob_txn_id,'')),'') is null
      or old.paymob_txn_id is not distinct from new.paymob_txn_id
      or new.status not in ('confirmed','completed')
      or new.payment_reconcile_state not in ('fully_paid','partially_paid')
      or new.payment_status not in ('paid','fully_paid','partially_paid')
      or new.user_id is null
      or new.paymob_order_id is null then
    return new;
  end if;

  select t.id,t.user_id,t.booking_id,t.amount,t.gross_amount,t.type
  into v_tx
  from public.transactions t
  where t.booking_id=new.id and t.user_id=new.user_id
    and t.paymob_transaction_id=new.paymob_txn_id
    and t.type in ('payment','deposit') and t.status='completed'
    and lower(coalesce(t.payment_method,'')) in ('card','wallet')
    and t.amount>0 and t.gross_amount>0
    and t.metadata->>'paymob_order_id'=new.paymob_order_id
  order by t.created_at desc limit 1;
  if v_tx.id is null then return new;end if;

  -- A forged or replayed transaction/log from a different booking, order,
  -- or gross amount is not payment evidence. Require a successful provider
  -- callback whose signature was verified BEFORE financial accounting.
  if not exists (
    select 1 from public.webhook_logs w
    where w.provider='paymob'
      and w.event_type='transaction_response'
      and w.signature_verified=true and w.status='success'
      and w.booking_id=new.id and w.txn_id=new.paymob_txn_id
      and w.order_id=new.paymob_order_id
      and w.payload->>'success'='true'
      and coalesce(w.payload->>'pending','false')='false'
      and (case
           when coalesce(w.payload->>'amount_cents','') ~ '^[0-9]{1,12}$'
           then (w.payload->>'amount_cents')::numeric
           else null end)=round(v_tx.gross_amount*100)
  ) then return new;end if;

  select s.owner_id,s.name into v_owner_id,v_stadium_name
  from public.stadiums s where s.id=new.stadium_id;
  if v_owner_id is null then return new;end if;
  v_stadium_name:=coalesce(nullif(btrim(v_stadium_name),''),'الملعب');
  v_receipt_kind:=case when new.payment_reconcile_state='fully_paid'
    then 'complete' else 'partial' end;
  v_body:='تم توثيق دفعة إلكترونية بقيمة '||
    to_char(v_tx.amount,'FM999999990.00')||
    ' جنيه للحجز في '||v_stadium_name||'.';

  -- Avoid a duplicate event when the booker is also the venue owner.
  for v_receiver in
    select distinct recipient from (
      values (new.user_id),(v_owner_id)
    ) recipients(recipient) where recipient is not null
  loop
    begin
      insert into public.notifications(
        user_id,title,body,message,type,is_read,created_at,
        booking_id,metadata
      ) values (
        v_receiver,'تم توثيق دفعة إلكترونية للحجز',
        v_body,v_body,'payment_received',false,now(),new.id,
        jsonb_build_object(
          'source','booking','event','paymob_payment_confirmed',
          'booking_id',new.id,'payment_transaction_id',v_tx.id,
          'receipt_kind',v_receipt_kind,
          'recipient_role',case when v_receiver=v_owner_id
            then 'venue_owner' else 'booker' end
        )
      ) on conflict do nothing;
    exception when others then
      -- Notification service failure must never roll back a verified
      -- financial transaction. A separate delivery-retry task stays open.
      raise warning 'VERIFIED_PAYMENT_RECEIPT_ENQUEUE_FAILED: %',sqlstate;
    end;
  end loop;
  return new;
end $$;
revoke all on function vsp_notifications_private.notify_verified_paymob_payment()
 from public,anon,authenticated;
drop trigger if exists trg_booking_verified_paymob_notice on public.bookings;
create trigger trg_booking_verified_paymob_notice
after update of paymob_txn_id,webhook_verified,payment_status
on public.bookings
for each row execute function
  vsp_notifications_private.notify_verified_paymob_payment();
