-- Admin payout RPCs are protected by an in-function admin/co-founder role check.
-- The admin web panel uses the normal authenticated Supabase session, never a service_role key.
grant execute on function public.admin_record_payout_settlement_atomic(uuid, numeric, text, text) to authenticated;
grant execute on function public.approve_payout_settlement_atomic(uuid, text) to authenticated;
