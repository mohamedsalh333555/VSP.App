-- Notify the real two captains of a *confirmed* online challenge only
-- after the server records a Paymob ledger transaction and matching signed
-- successful callback. Pending/failed/cancelled matches never appear live.
-- Cash challenge notices already use notify_cash_booking_parties.
CREATE SCHEMA IF NOT EXISTS vsp_notifications_private;
REVOKE ALL ON SCHEMA vsp_notifications_private FROM PUBLIC,anon,authenticated;

CREATE UNIQUE INDEX IF NOT EXISTS vsp_verified_challenge_once_per_captain
 ON public.notifications(
   user_id,booking_id,((metadata->>'event')))
 WHERE metadata->>'source'='booking'
   AND metadata->>'event'='verified_online_challenge_confirmed';

CREATE OR REPLACE FUNCTION vsp_notifications_private.notify_verified_online_challenge()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
  v_tx record;
  v_home_captain uuid;
  v_away_captain uuid;
  v_home text;
  v_away text;
  v_stadium text;
  v_caption text;
  v_captain uuid;
BEGIN
  IF old.status<>'pending' OR new.status<>'confirmed'
     OR new.booking_type<>'challenge'
     OR new.challenge_status<>'confirmed'
     OR lower(coalesce(new.payment_method,'')) NOT IN ('card','wallet')
     OR new.webhook_verified IS DISTINCT FROM true
     OR new.paymob_txn_id IS NULL OR new.paymob_order_id IS NULL
     OR new.payment_status NOT IN ('paid','fully_paid','partially_paid')
     OR new.payment_reconcile_state NOT IN ('fully_paid','partially_paid')
     OR new.user_id IS NULL
  THEN RETURN new; END IF;

  SELECT t.id,t.gross_amount INTO v_tx
  FROM public.transactions t
  WHERE t.booking_id=new.id AND t.user_id=new.user_id
    AND t.paymob_transaction_id=new.paymob_txn_id
    AND t.type IN ('payment','deposit') AND t.status='completed'
    AND lower(coalesce(t.payment_method,'')) IN ('card','wallet')
    AND t.amount>0 AND t.gross_amount>0
    AND t.metadata->>'paymob_order_id'=new.paymob_order_id
  ORDER BY t.created_at DESC LIMIT 1;
  IF v_tx.id IS NULL THEN RETURN new; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM public.webhook_logs w
    WHERE w.provider='paymob' AND w.event_type='transaction_response'
      AND w.status='success' AND w.signature_verified=true
      AND w.booking_id=new.id
      AND w.txn_id=new.paymob_txn_id
      AND w.order_id=new.paymob_order_id
      AND w.payload->>'success'='true'
      AND coalesce(w.payload->>'pending','false')='false'
      AND (CASE WHEN coalesce(w.payload->>'amount_cents','') ~ '^[0-9]{1,12}$'
        THEN (w.payload->>'amount_cents')::numeric ELSE null END)
        =round(v_tx.gross_amount*100)
  ) THEN RETURN new; END IF;

  SELECT h.captain_id,a.captain_id,h.name,a.name,s.name
  INTO v_home_captain,v_away_captain,v_home,v_away,v_stadium
  FROM public.teams h
  JOIN public.teams a ON a.id=new.opponent_team_id
  JOIN public.stadiums s ON s.id=new.stadium_id
  WHERE h.id=new.player_team_id;
  IF v_home_captain IS NULL OR v_away_captain IS NULL
     OR v_home_captain=v_away_captain
     OR v_home_captain IS DISTINCT FROM new.user_id
  THEN RETURN new; END IF;

  v_caption:='تم تأكيد مباراة تحدي بين '||
    left(coalesce(nullif(btrim(v_home),''),'فريق'),80)||' و'||
    left(coalesce(nullif(btrim(v_away),''),'فريق'),80)||
    ' في '||left(coalesce(nullif(btrim(v_stadium),''),'الملعب'),80)||'.';
  FOR v_captain IN
    SELECT distinct target FROM (
      VALUES(v_home_captain),(v_away_captain)
    ) r(target)
  LOOP
    INSERT INTO public.notifications(
      user_id,title,body,message,type,is_read,booking_id,created_at,metadata
    ) VALUES (
      v_captain,'تم تأكيد مباراة تحدي',v_caption,v_caption,
      'booking_confirmed',false,new.id,now(),
      jsonb_build_object(
        'source','booking','event','verified_online_challenge_confirmed',
        'booking_id',new.id,'payment_transaction_id',v_tx.id
      )
    ) ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN new;
END $$;
REVOKE ALL ON FUNCTION vsp_notifications_private.notify_verified_online_challenge()
  FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS trg_verified_online_challenge_notice ON public.bookings;
CREATE TRIGGER trg_verified_online_challenge_notice
AFTER UPDATE OF status ON public.bookings FOR EACH ROW
EXECUTE FUNCTION vsp_notifications_private.notify_verified_online_challenge();
