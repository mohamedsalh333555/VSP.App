-- Restore the legacy three-argument cancellation wrapper expected by the app.
-- A later migration accidentally replaced the wrapper with (uuid,text,uuid),
-- made two-argument PostgREST calls ambiguous, and wrote the unsupported
-- payment_status value `cancelled` for unpaid cash bookings.

DROP FUNCTION IF EXISTS public.cancel_booking_with_refund_atomic(uuid, text, uuid);

CREATE OR REPLACE FUNCTION public.cancel_booking_with_refund_atomic(
  p_booking_id uuid,
  p_user_id uuid,
  p_reason text DEFAULT 'إلغاء حجز من المستخدم'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Authorization and caller identity are enforced by the authoritative RPC.
  -- p_user_id is retained only for backward-compatible client parameter names.
  RETURN public.cancel_booking_with_refund_atomic(p_booking_id, p_reason);
END;
$function$;

REVOKE ALL ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, uuid, text)
FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, uuid, text)
TO authenticated, service_role;
