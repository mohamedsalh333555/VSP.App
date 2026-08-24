-- Migration: 20260824_financial_audit_logs.sql
-- Description: Immutable Financial Audit Log Table for 100% Financial Transparency

CREATE TABLE IF NOT EXISTS public.financial_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
    user_id UUID,
    owner_id UUID,
    amount NUMERIC NOT NULL,
    fee NUMERIC NOT NULL,
    action_type TEXT NOT NULL, -- 'booking_payment', 'deposit_payment', 'refund', 'payout', 'cancellation'
    payment_method TEXT NOT NULL,
    transaction_ref TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast financial querying & reconciliation
CREATE INDEX IF NOT EXISTS idx_financial_logs_booking ON public.financial_audit_logs(booking_id);
CREATE INDEX IF NOT EXISTS idx_financial_logs_owner ON public.financial_audit_logs(owner_id, created_at);
CREATE INDEX IF NOT EXISTS idx_financial_logs_user ON public.financial_audit_logs(user_id, created_at);

-- Financial RLS: Admins have full read access, Owners read their own records, Players read their transactions
ALTER TABLE public.financial_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS financial_logs_admin_all ON public.financial_audit_logs;
CREATE POLICY financial_logs_admin_all ON public.financial_audit_logs
FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = auth.uid() AND role IN ('admin', 'co_founder')
    )
);

DROP POLICY IF EXISTS financial_logs_owner_select ON public.financial_audit_logs;
CREATE POLICY financial_logs_owner_select ON public.financial_audit_logs
FOR SELECT TO authenticated
USING (owner_id = auth.uid());

DROP POLICY IF EXISTS financial_logs_user_select ON public.financial_audit_logs;
CREATE POLICY financial_logs_user_select ON public.financial_audit_logs
FOR SELECT TO authenticated
USING (user_id = auth.uid());
