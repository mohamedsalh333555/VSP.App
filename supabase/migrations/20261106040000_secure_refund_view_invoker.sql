-- Ensure refund reporting honors the querying user's underlying bookings RLS.
ALTER VIEW public.v_bookings_with_refund SET (security_invoker = true);
