-- 1. Create admin_update_1v1_tournament_status RPC
CREATE OR REPLACE FUNCTION public.admin_update_1v1_tournament_status(
  p_tournament_id UUID,
  p_new_status TEXT,
  p_admin_id UUID DEFAULT auth.uid()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_role TEXT;
  v_current_status TEXT;
  v_allowed_transitions JSONB := '{
    "draft": ["registration_open"],
    "registration_open": ["in_progress", "draft"],
    "in_progress": ["completed"],
    "completed": ["published"],
    "published": ["archived"]
  }';
BEGIN
  -- Verify caller role if not service_role / postgres
  IF (COALESCE(auth.role(), '') != 'service_role' AND current_user != 'postgres') THEN
    SELECT role INTO v_caller_role FROM public.users WHERE id = COALESCE(p_admin_id, auth.uid());
    IF (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder', 'super_admin')) THEN
      RAISE EXCEPTION 'غير مصرح: هذه العملية مخصصة لمديري النظام فقط.';
    END IF;
  END IF;

  -- Lock the row to prevent race conditions
  SELECT status INTO v_current_status
  FROM public.vsp_1v1_tournaments
  WHERE id = p_tournament_id
  FOR UPDATE;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'البطولة غير موجودة.';
  END IF;

  -- Idempotency check
  IF v_current_status = p_new_status THEN
    RETURN jsonb_build_object(
      'success', true,
      'old_status', v_current_status,
      'new_status', p_new_status,
      'message', 'البطولة بالفعل في هذه الحالة.'
    );
  END IF;

  -- Validate status transition
  IF NOT (v_allowed_transitions->v_current_status) @> to_jsonb(p_new_status) THEN
    RAISE EXCEPTION 'تحويل غير مسموح لحالة البطولة: من % إلى %', v_current_status, p_new_status;
  END IF;

  UPDATE public.vsp_1v1_tournaments
  SET status = p_new_status,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_tournament_id;

  RETURN jsonb_build_object(
    'success', true,
    'old_status', v_current_status,
    'new_status', p_new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_1v1_tournament_status(UUID, TEXT, UUID) TO authenticated, service_role;

-- 2. Add refund retry and order expiration columns
ALTER TABLE public.vsp_1v1_tournament_orders
ADD COLUMN IF NOT EXISTS refund_retry_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS refund_last_attempt_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS refund_next_retry_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Backfill expires_at for existing pending orders (30 mins from creation)
UPDATE public.vsp_1v1_tournament_orders
SET expires_at = created_at + INTERVAL '30 minutes'
WHERE expires_at IS NULL;

-- Set default for new rows
ALTER TABLE public.vsp_1v1_tournament_orders 
ALTER COLUMN expires_at SET DEFAULT (timezone('utc'::text, now()) + INTERVAL '30 minutes');

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_pending_refund
ON public.vsp_1v1_tournament_orders(refund_next_retry_at)
WHERE payment_status = 'refund_failed_manual_review'
  AND refund_retry_count < 3;

CREATE INDEX IF NOT EXISTS idx_orders_pending_expires
ON public.vsp_1v1_tournament_orders(expires_at)
WHERE payment_status = 'pending';
