-- Migration: 20261012000000_grant_authenticated_matchmaking_and_cash_rpcs.sql
-- Grants EXECUTE to authenticated users on required public match & cash confirmation RPCs
-- These RPCs are invoked by the Flutter application and already enforce auth.uid() & role checks internally.

GRANT EXECUTE ON FUNCTION public.request_join_public_match(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_public_match_atomic(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_host_spots_atomic(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid, uuid, numeric, numeric) TO authenticated;
