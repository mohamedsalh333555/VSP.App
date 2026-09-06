-- ==============================================================================
-- Migration: 20260906_add_1v1_paid_prize_pool_schema.sql
-- Section 1: 1v1 Paid Tournament Schema & Prize Pool Accumulation
-- ==============================================================================

-- 1️⃣ Enhance vsp_1v1_tournaments with entry fee, prize pool, and manual delivery logs
ALTER TABLE public.vsp_1v1_tournaments
ADD COLUMN IF NOT EXISTS entry_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS prize_pool NUMERIC(10,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS prize_delivered BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS prize_delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS prize_delivered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS prize_delivery_notes TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- 2️⃣ Enhance vsp_1v1_tournament_players with payment tracking
ALTER TABLE public.vsp_1v1_tournament_players
ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid',
ADD COLUMN IF NOT EXISTS payment_order_id UUID,
ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10,2) DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'vsp_1v1_players_payment_status_check'
    ) THEN
        ALTER TABLE public.vsp_1v1_tournament_players
        ADD CONSTRAINT vsp_1v1_players_payment_status_check 
        CHECK (payment_status IN ('unpaid', 'paid', 'refunded'));
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 3️⃣ Create vsp_1v1_tournament_orders table (modeled after tournament_orders)
CREATE TABLE IF NOT EXISTS public.vsp_1v1_tournament_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID NOT NULL REFERENCES public.vsp_1v1_tournaments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    order_reference TEXT NOT NULL UNIQUE,
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded', 'failed_over_capacity', 'refund_failed_manual_review')),
    paymob_transaction_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indexes for high-speed lookups
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_orders_user ON public.vsp_1v1_tournament_orders (user_id);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_orders_tournament ON public.vsp_1v1_tournament_orders (tournament_id);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_orders_status ON public.vsp_1v1_tournament_orders (payment_status);
CREATE INDEX IF NOT EXISTS idx_vsp_1v1_orders_ref ON public.vsp_1v1_tournament_orders (order_reference);

-- Enable RLS
ALTER TABLE public.vsp_1v1_tournament_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users and admins can view 1v1 orders" ON public.vsp_1v1_tournament_orders;
CREATE POLICY "Users and admins can view 1v1 orders"
ON public.vsp_1v1_tournament_orders
AS PERMISSIVE FOR SELECT
TO authenticated, service_role
USING (
    (auth.uid() = user_id) OR
    (COALESCE(auth.role(), '') = 'service_role') OR
    (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')))
);

DROP POLICY IF EXISTS "Service role and atomic functions manage 1v1 orders" ON public.vsp_1v1_tournament_orders;
CREATE POLICY "Service role and atomic functions manage 1v1 orders"
ON public.vsp_1v1_tournament_orders
AS PERMISSIVE FOR ALL
TO authenticated, service_role
USING (
    (COALESCE(auth.role(), '') = 'service_role') OR
    (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')))
)
WITH CHECK (
    (COALESCE(auth.role(), '') = 'service_role') OR
    (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'co_founder')))
);
