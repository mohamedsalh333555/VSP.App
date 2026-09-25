-- Prevent direct client-side mutation of financial records.
-- Financial writes must go through SECURITY DEFINER atomic RPCs / service-role webhooks.
revoke insert, update, delete, truncate, trigger, references on public.transactions from authenticated;
revoke insert, update, delete, truncate, trigger, references on public.payout_settlements from authenticated;
