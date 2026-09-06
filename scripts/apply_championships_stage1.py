import urllib.request, json

env = json.load(open('env.json'))
token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query):
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("=== APPLYING STAGE 1: CHAMPIONSHIPS SCHEMA & FUNCTIONS ===")

stage1_sql = """
-- 1. Add Prize Pool & Delivery Handover Columns to public.championships
ALTER TABLE public.championships
ADD COLUMN IF NOT EXISTS prize_pool NUMERIC NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS prize_delivered BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS prize_delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS prize_delivered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS prize_delivery_notes TEXT;

-- 2. Update Constraint on public.tournament_orders to allow failed_over_capacity, refunded, refund_failed_manual_review
ALTER TABLE public.tournament_orders
DROP CONSTRAINT IF EXISTS tournament_orders_payment_status_check;

ALTER TABLE public.tournament_orders
ADD CONSTRAINT tournament_orders_payment_status_check
CHECK (payment_status IN ('pending', 'paid', 'failed', 'cancelled', 'failed_over_capacity', 'refunded', 'refund_failed_manual_review'));

-- 3. Atomic Function: mark_championship_prize_delivered_atomic
DROP FUNCTION IF EXISTS public.mark_championship_prize_delivered_atomic(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.mark_championship_prize_delivered_atomic(
    p_championship_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_champ RECORD;
    v_caller_role TEXT;
    v_caller_id UUID := auth.uid();
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Authorization: service_role, admin, co_founder, or championship owner
    IF COALESCE(auth.role(), '') != 'service_role' THEN
        IF v_caller_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'يجب تسجيل الدخول أولاً.');
        END IF;
        SELECT role INTO v_caller_role FROM public.users WHERE id = v_caller_id;
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
        IF (v_champ.owner_id IS DISTINCT FROM v_caller_id) AND (COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح لك بتوثيق تسليم الجائزة. العملية مقتصرة على منظم البطولة أو الإدارة.');
        END IF;
    ELSE
        SELECT * INTO v_champ FROM public.championships WHERE id = p_championship_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'البطولة غير موجودة.');
        END IF;
    END IF;

    -- 2. Status verification
    IF v_champ.status != 'completed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'لا يمكن تسليم الجائزة إلا بعد اكتمال وتتويج بطل البطولة رسمياً.');
    END IF;

    -- 3. Double-handover prevention
    IF COALESCE(v_champ.prize_delivered, false) = true THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'تم توثيق تسليم الجائزة المالية لهذه البطولة مسبقاً ولا يمكن تكرار التسليم.'
        );
    END IF;

    -- 4. Mark prize delivered atomically
    UPDATE public.championships
    SET prize_delivered = true,
        prize_delivered_at = v_now,
        prize_delivered_by = v_caller_id,
        prize_delivery_notes = TRIM(COALESCE(p_notes, '')),
        updated_at = v_now
    WHERE id = p_championship_id;

    -- 5. Audit log in transactions table
    INSERT INTO public.transactions (
        championship_id,
        user_id,
        amount,
        type,
        payment_method,
        status,
        description,
        metadata,
        created_at
    ) VALUES (
        p_championship_id,
        v_champ.champion_user_id,
        COALESCE(v_champ.prize_pool, 0.00),
        'prize_payout',
        'cash',
        'completed',
        'توثيق تسليم الجائزة المالية يداً بيد لكابتن الفريق البطل',
        jsonb_build_object(
            'handover_by', v_caller_id,
            'handover_at', v_now,
            'notes', TRIM(COALESCE(p_notes, '')),
            'champion_team_id', v_champ.champion_team_id,
            'champion_team_name', v_champ.champion_team_name,
            'amount', COALESCE(v_champ.prize_pool, 0.00)
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم توثيق تسليم الجائزة المالية بنجاح.',
        'prize_delivered_at', v_now,
        'amount', COALESCE(v_champ.prize_pool, 0.00)
    );
END;
$$;

-- 4. Atomic Function: record_tournament_refund_status_atomic
DROP FUNCTION IF EXISTS public.record_tournament_refund_status_atomic(TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.record_tournament_refund_status_atomic(
    p_order_reference TEXT,
    p_refund_status TEXT,
    p_paymob_refund_id TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_caller_role TEXT;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    -- 1. Security Check (service_role or admin)
    IF COALESCE(auth.role(), '') != 'service_role' THEN
        SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
        IF COALESCE(v_caller_role, '') NOT IN ('admin', 'co_founder') THEN
            RETURN jsonb_build_object('success', false, 'error', 'غير مصرح: تحديث حالة الاسترداد مقتصر على خادم الويب هوك أو الإدارة.');
        END IF;
    END IF;

    -- 2. Validate refund status input
    IF p_refund_status NOT IN ('refunded', 'refund_failed_manual_review') THEN
        RETURN jsonb_build_object('success', false, 'error', 'حالة الاسترداد غير صالحة.');
    END IF;

    -- 3. Lock and retrieve order
    SELECT * INTO v_order 
    FROM public.tournament_orders 
    WHERE order_reference = p_order_reference 
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'طلب اشتراك البطولة غير موجود.');
    END IF;

    -- 4. Update order status
    UPDATE public.tournament_orders
    SET payment_status = p_refund_status,
        updated_at = v_now
    WHERE id = v_order.id;

    -- 5. Update transaction audit log
    UPDATE public.transactions
    SET status = CASE WHEN p_refund_status = 'refunded' THEN 'completed' ELSE 'failed' END,
        metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
            'paymob_refund_id', p_paymob_refund_id,
            'refund_error', p_error_message,
            'refund_recorded_at', v_now
        )
    WHERE championship_id = v_order.championship_id
      AND type = 'refund'
      AND metadata->>'order_reference' = p_order_reference;

    -- 6. Send notification to captain
    IF p_refund_status = 'refunded' THEN
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'تم استرداد رسوم اشتراك البطولة بنجاح',
            'تمت إعادة مبلغ رسوم الاشتراك (' || v_order.amount || ' ج.م) بنجاح إلى بطاقتك/محفظتك عبر Paymob.',
            'tournament_refund',
            v_now
        );
    ELSE
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
            v_order.captain_user_id,
            'فشل تلقائي في استرداد رسوم البطولة (قيد المراجعة اليدوية)',
            'تعذر الاسترداد التلقائي للرسوم (' || v_order.amount || ' ج.م). تم تحويل العملية لفريق الدعم المالي للمراجعة اليدوية ورد المبلغ لك.',
            'tournament_refund_manual',
            v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'order_reference', p_order_reference,
        'status', p_refund_status
    );
END;
$$;

-- Revoke execute on sensitive RPC from anon/public
REVOKE EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(TEXT, TEXT, TEXT, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.mark_championship_prize_delivered_atomic(UUID, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.mark_championship_prize_delivered_atomic(UUID, TEXT) TO authenticated, service_role;
"""

res = run_sql(stage1_sql)
print("Migration applied successfully. Output:", res)

# Verification
print("\n=== VERIFYING ADDED COLUMNS ===")
cols = run_sql("""
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'championships' 
  AND column_name IN ('prize_pool', 'prize_delivered', 'prize_delivered_at', 'prize_delivered_by', 'prize_delivery_notes');
""")
for c in cols:
    print(f"  Column: {c['column_name']} ({c['data_type']}) default: {c['column_default']}")
assert len(cols) == 5, f"Expected 5 columns, got {len(cols)}"

print("\n=== VERIFYING CONSTRAINT ===")
con = run_sql("""
SELECT conname, pg_get_constraintdef(oid) as def 
FROM pg_constraint 
WHERE conname = 'tournament_orders_payment_status_check';
""")
print(f"  Constraint: {con[0]['conname']} -> {con[0]['def']}")

print("\n=== VERIFYING FUNCTIONS ===")
funcs = run_sql("""
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname IN ('mark_championship_prize_delivered_atomic', 'record_tournament_refund_status_atomic');
""")
for f in funcs:
    print(f"  Function {f['proname']} exists on DB: True")
assert len(funcs) == 2, f"Expected 2 functions, got {len(funcs)}"

print("\n=== CHECKING DUMMY RECORDS COUNT ===")
counts = run_sql("""
SELECT 
  (SELECT count(*) FROM public.tournament_orders WHERE order_reference LIKE 'TEST%') as test_orders,
  (SELECT count(*) FROM public.championships WHERE name LIKE 'TEST%') as test_champs;
""")
print("Counts:", counts)
print("\n>>> STAGE 1 VERIFICATION COMPLETED WITH 100% SUCCESS <<<")
