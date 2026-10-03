REVOKE EXECUTE ON FUNCTION public._generate_unique_challenge_code() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public._generate_unique_challenge_code() FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.sync_payment_reconcile_state() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_payment_reconcile_state() FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.trg_sync_challenge_booking_status() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.trg_sync_challenge_booking_status() FROM anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.generate_team_league_fixtures(uuid) FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking_with_refund_atomic(uuid, text, uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.claim_booking_gateway_refund_atomic(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_booking_gateway_refund_atomic(uuid, text) TO service_role;