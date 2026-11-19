-- Allow the authorised cancellation workflow through the booking mutation guard
-- without relaxing direct client updates.

CREATE OR REPLACE FUNCTION public.vsp_guard_direct_booking_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_role text;
BEGIN
  IF coalesce(auth.role(), '') = 'service_role'
     OR current_user IN ('postgres', 'service_role')
     OR current_setting('vsp.system_override', true) = 'true'
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
$function$;

-- Preserve the authoritative implementation, but place the trusted transaction
-- marker before it mutates the protected booking row.
ALTER FUNCTION public.cancel_booking_with_refund_atomic(uuid, text)
  RENAME TO cancel_booking_with_refund_atomic_impl;

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic_impl(uuid, text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic_impl(uuid, text)
TO service_role;

CREATE FUNCTION public.cancel_booking_with_refund_atomic(
  p_booking_id uuid,
  p_reason text DEFAULT 'cancelled_by_user'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM set_config('vsp.system_override', 'true', true);
  RETURN public.cancel_booking_with_refund_atomic_impl(p_booking_id, p_reason);
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text)
TO authenticated, service_role;

