revoke execute on function public.admin_record_payout_settlement_atomic(uuid,numeric,text,text) from anon, authenticated;
revoke execute on function public.approve_payout_settlement_atomic(uuid,text) from anon, authenticated;
grant execute on function public.admin_record_payout_settlement_atomic(uuid,numeric,text,text) to service_role;
grant execute on function public.approve_payout_settlement_atomic(uuid,text) to service_role;
