-- Replaces current STAGING sync_payment_reconcile_state body, preserving
-- refund precedence and the existing booking payment matrix. No data rewrite.
-- Canonicalizes Arabic wallet/cash/card methods and closes a confirmed-unpaid
-- digital booking bypass, including method-only updates.
CREATE OR REPLACE FUNCTION public.sync_payment_reconcile_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- 1. Canonical payment source classification, Arabic and English.
  -- A wallet named "فودافون كاش" is NOT cash handed to the stadium.
  -- Treat client-provided payment_source as untrusted; rederive from method.
  IF lower(btrim(coalesce(NEW.payment_method,''))) IN
       ('vodafone_cash','vodafone cash','فودافون كاش')
     OR lower(coalesce(NEW.payment_method,'')) LIKE '%vodafone%'
     OR coalesce(NEW.payment_method,'') LIKE '%فودافون%' THEN
    NEW.payment_source:='vodafone_cash';
  ELSIF lower(btrim(coalesce(NEW.payment_method,''))) IN ('instapay','انستاباي') THEN
    NEW.payment_source:='instapay';
  ELSIF lower(btrim(coalesce(NEW.payment_method,''))) IN
       ('bank_transfer','bank transfer','تحويل بنكي') THEN
    NEW.payment_source:='bank_transfer';
  ELSIF lower(btrim(coalesce(NEW.payment_method,''))) IN
       ('paymob','card','online','wallet','visa','mastercard','meeza',
        'فيزا','ميزا','بطاقة','بطاقة ائتمان','محفظة') THEN
    NEW.payment_source:='paymob';
  ELSIF lower(btrim(coalesce(NEW.payment_method,''))) IN
       ('cash','كاش','نقدي','cash_on_arrival','cash on arrival',
        'كاش عند الملعب','دفع نقدي')
     OR (nullif(btrim(coalesce(NEW.payment_method,'')),'') IS NULL
         AND upper(coalesce(NEW.payment_transaction_id,'')) LIKE 'MANUAL%') THEN
    NEW.payment_source:='cash';
  ELSE
    NEW.payment_source:='unknown';
  END IF;

  -- 2. Reconcile payment state hierarchy (strictly preserving refund states)
  IF NEW.payment_status = 'refunded' THEN
    NEW.payment_reconcile_state := 'refunded';
  ELSIF NEW.payment_status = 'refund_failed' THEN
    NEW.payment_reconcile_state := 'refund_failed';
  ELSIF NEW.payment_status = 'refund_pending' THEN
    NEW.payment_reconcile_state := 'refund_pending';
  ELSIF NEW.payment_reconcile_state IN ('refunded', 'refund_failed', 'refund_pending') THEN
    -- Preserve explicit reconcile refund state
    NULL;
  ELSIF NEW.is_paid = TRUE OR NEW.payment_status IN ('paid', 'fully_paid') OR NEW.payment_reconcile_state = 'fully_paid' THEN
    NEW.payment_reconcile_state := 'fully_paid';
  ELSIF (coalesce(NEW.deposit_paid, 0) > 0 AND NEW.deposit_paid < NEW.total_price)
     OR NEW.payment_status = 'partially_paid'
     OR NEW.payment_reconcile_state = 'partially_paid' THEN
    NEW.payment_reconcile_state := 'partially_paid';
  ELSE
    NEW.payment_reconcile_state := 'unpaid';
  END IF;

  -- 3. Payment Matrix Enforcement (enforced on INSERT or when status/payment changes)
  IF current_setting('vsp.bypass_state_machine', true) IS DISTINCT FROM 'true' THEN
    IF TG_OP = 'INSERT' OR (OLD.status IS DISTINCT FROM NEW.status
       OR OLD.payment_reconcile_state IS DISTINCT FROM NEW.payment_reconcile_state
       OR OLD.payment_method IS DISTINCT FROM NEW.payment_method
       OR OLD.payment_source IS DISTINCT FROM NEW.payment_source
       OR OLD.payment_status IS DISTINCT FROM NEW.payment_status) THEN
      IF NEW.status = 'pending' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "pending" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'confirmed' THEN
        -- Cash bookings can be confirmed while unpaid (awaiting pitch payment)
        -- Online bookings (paymob, card, wallet, online) CANNOT be confirmed while unpaid
        IF NEW.payment_reconcile_state = 'unpaid' THEN
          IF NEW.payment_source IN ('paymob','vodafone_cash','instapay','bank_transfer') THEN
            RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: Online booking with payment method "%" cannot be confirmed while unpaid', NEW.payment_method
              USING ERRCODE = 'P0005', DETAIL = 'ONLINE_BOOKING_CANNOT_BE_CONFIRMED_UNPAID';
          END IF;
        ELSIF NEW.payment_reconcile_state NOT IN ('partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "confirmed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'completed' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'partially_paid', 'fully_paid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "completed" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'cancelled' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid', 'refund_pending', 'refunded', 'refund_failed') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "cancelled" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      ELSIF NEW.status = 'expired' THEN
        IF NEW.payment_reconcile_state NOT IN ('unpaid') THEN
          RAISE EXCEPTION 'ILLEGAL_MATRIX_COMBINATION: status "expired" cannot have payment state "%"', NEW.payment_reconcile_state
            USING ERRCODE = 'P0005', DETAIL = 'BOOKING_PAYMENT_MATRIX_VIOLATION';
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
