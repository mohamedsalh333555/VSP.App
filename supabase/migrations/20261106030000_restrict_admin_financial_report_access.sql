-- Restrict sensitive financial reporting views to privileged server-side roles.
-- Verified on staging: anon and authenticated no longer have SELECT.
REVOKE SELECT ON public.admin_pending_refunds FROM anon, authenticated;
REVOKE SELECT ON public.admin_stadium_settlements FROM anon, authenticated;
REVOKE SELECT ON public.v_financial_reconciliation FROM anon, authenticated;
