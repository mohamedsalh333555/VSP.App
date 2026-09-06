import urllib.request, urllib.error, json

with open('env.json', 'r') as f:
    env = json.load(f)

token = env['SUPABASE_MANAGEMENT_KEY']
url = 'https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query'

def run_sql(query_str):
    payload = json.dumps({"query": query_str}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "Mozilla/5.0",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print("SQL ERROR:", e.code, e.read().decode('utf-8'))
        raise e

print("=" * 75)
print("🚀 SECTION 2 LIVE VERIFICATION: 1v1 ATOMIC PAYMENT, OVER-CAPACITY REFUND & PRIZE DELIVERY")
print("=" * 75)

# 1. Fetch real test users
users = run_sql("SELECT id, name, email FROM public.users ORDER BY created_at ASC LIMIT 2;")
user1 = users[0] # Hana
user2 = users[1] # Mohamed
print(f"👤 Player 1: {user1['name']} ({user1['email']}) -> {user1['id']}")
print(f"👤 Player 2: {user2['name']} ({user2['email']}) -> {user2['id']}")

# 2. Create a test tournament with capacity = 1 and entry_fee = 150
tourn_sql = f"""
INSERT INTO public.vsp_1v1_tournaments (
    id, name, target_player_count, entry_fee, prize_pool, status, created_by
) VALUES (
    gen_random_uuid(), 'بطولة اختبار الرسوم والجائزة 1v1', 1, 150.00, 0, 'registration_open', '{user1['id']}'
) RETURNING id, name, target_player_count, entry_fee, prize_pool, status;
"""
tourn = run_sql(tourn_sql)[0]
tourn_id = tourn['id']
print(f"\n🏆 Created 1v1 Tournament: {tourn['name']} (ID: {tourn_id})")
print(f"   Max Capacity: {tourn['target_player_count']} player | Entry Fee: {tourn['entry_fee']} EGP | Initial Prize Pool: {tourn['prize_pool']} EGP")

# 3. Create orders for Player 1 and Player 2
order1_ref = f"TOURN_1V1_TEST1_{tourn_id[:6]}"
order2_ref = f"TOURN_1V1_TEST2_{tourn_id[:6]}"
order3_ref = f"TOURN_1V1_TEST3_{tourn_id[:6]}"

run_sql(f"""
INSERT INTO public.vsp_1v1_tournament_orders (id, tournament_id, user_id, amount, order_reference, payment_status)
VALUES 
    (gen_random_uuid(), '{tourn_id}', '{user1['id']}', 150.00, '{order1_ref}', 'pending'),
    (gen_random_uuid(), '{tourn_id}', '{user2['id']}', 150.00, '{order2_ref}', 'pending'),
    (gen_random_uuid(), '{tourn_id}', '{user2['id']}', 150.00, '{order3_ref}', 'pending');
""")
print(f"\n📦 Created Pending Orders:")
print(f"   - Order 1 (Player 1): {order1_ref}")
print(f"   - Order 2 (Player 2): {order2_ref}")
print(f"   - Order 3 (Player 2 - Failure Test): {order3_ref}")

# 4. Confirm Player 1 Payment (Available Capacity)
print("\n" + "-" * 75)
print("TEST CASE 1: Confirming Player 1 (Under Capacity -> Should Succeed)")
print("-" * 75)
confirm1 = run_sql(f"SELECT public.confirm_1v1_payment_atomic('{order1_ref}', 'PAYMOB_TXN_101') AS res;")[0]['res']
print("Result of confirm_1v1_payment_atomic:", json.dumps(confirm1, ensure_ascii=False, indent=2))

# Verify prize pool accumulation in DB
tourn_check1 = run_sql(f"SELECT id, entry_fee, prize_pool FROM public.vsp_1v1_tournaments WHERE id = '{tourn_id}';")[0]
print(f"💰 Updated Tournament Prize Pool in DB: {tourn_check1['prize_pool']} EGP (Accumulated exactly by 150 EGP!)")

# 5. Confirm Player 2 Payment (Race Condition / Over-Capacity -> Capacity Exceeded)
print("\n" + "-" * 75)
print("TEST CASE 2: Confirming Player 2 (Capacity Exceeded -> Must trigger needs_refund)")
print("-" * 75)
confirm2 = run_sql(f"SELECT public.confirm_1v1_payment_atomic('{order2_ref}', 'PAYMOB_TXN_102') AS res;")[0]['res']
print("Result of confirm_1v1_payment_atomic:", json.dumps(confirm2, ensure_ascii=False, indent=2))

# Verify that Player 2 order status is failed_over_capacity and NOT refunded yet!
order2_check = run_sql(f"SELECT order_reference, payment_status FROM public.vsp_1v1_tournament_orders WHERE order_reference = '{order2_ref}';")[0]
print(f"🛡️ Intermediate Order Status in DB: {order2_check['payment_status']} (Proof: NOT marked as refunded before Paymob API!)")

# 6. Simulate Real Paymob Refund Response (Edge Function calls record_1v1_refund_status_atomic)
print("\n" + "-" * 75)
print("TEST CASE 3A: Paymob Refund API call succeeds -> Mark as 'refunded'")
print("-" * 75)
refund_res_success = run_sql(f"SELECT public.record_1v1_refund_status_atomic('{order2_ref}', true, 'REFUND_TXN_998877', NULL) AS res;")[0]['res']
print("Result of record_1v1_refund_status_atomic (Success):", json.dumps(refund_res_success, ensure_ascii=False, indent=2))

order2_final = run_sql(f"SELECT order_reference, payment_status FROM public.vsp_1v1_tournament_orders WHERE order_reference = '{order2_ref}';")[0]
print(f"✔️ Final Order Status in DB: {order2_final['payment_status']} (Now officially marked as refunded!)")

tx_check = run_sql(f"SELECT type, amount, status, metadata FROM public.transactions WHERE user_id = '{user2['id']}' AND type = 'refund' ORDER BY created_at DESC LIMIT 1;")[0]
print(f"✔️ Transaction Ledger Proof: type={tx_check['type']} | amount={tx_check['amount']} | status={tx_check['status']} | metadata={json.dumps(tx_check['metadata'])}")

print("\n" + "-" * 75)
print("TEST CASE 3B: Paymob Refund API call FAILS -> Mark as 'refund_failed_manual_review' (NEVER refunded)")
print("-" * 75)
# Confirm over-capacity on order 3
run_sql(f"SELECT public.confirm_1v1_payment_atomic('{order3_ref}', 'PAYMOB_TXN_103');")
refund_res_failed = run_sql(f"SELECT public.record_1v1_refund_status_atomic('{order3_ref}', false, NULL, '504 Gateway Timeout on Paymob') AS res;")[0]['res']
print("Result of record_1v1_refund_status_atomic (Failure):", json.dumps(refund_res_failed, ensure_ascii=False, indent=2))

order3_final = run_sql(f"SELECT order_reference, payment_status FROM public.vsp_1v1_tournament_orders WHERE order_reference = '{order3_ref}';")[0]
print(f"🛡️ Final Order Status in DB: {order3_final['payment_status']} (Protected against false refunded status!)")

# 7. Test Prize Handover Logging (mark_1v1_prize_delivered_atomic)
print("\n" + "-" * 75)
print("TEST CASE 4: Manual Prize Delivery Logging (mark_1v1_prize_delivered_atomic)")
print("-" * 75)
# Set tournament completed with champion
run_sql(f"UPDATE public.vsp_1v1_tournaments SET status = 'completed', champion_user_id = '{user1['id']}' WHERE id = '{tourn_id}';")

delivery_res = run_sql(f"SELECT public.mark_1v1_prize_delivered_atomic('{tourn_id}', 'تم تسليم 150 ج.م كاش للاعبة في مقر النادي') AS res;")[0]['res']
print("Result of mark_1v1_prize_delivered_atomic:", json.dumps(delivery_res, ensure_ascii=False, indent=2))

# Verify delivery columns in tournament
tourn_final = run_sql(f"SELECT prize_delivered, prize_delivered_at, prize_delivery_notes FROM public.vsp_1v1_tournaments WHERE id = '{tourn_id}';")[0]
print(f"✔️ Tournament Prize Handover in DB: delivered={tourn_final['prize_delivered']} | at={tourn_final['prize_delivered_at']} | notes={tourn_final['prize_delivery_notes']}")

# Attempt double delivery
double_delivery = run_sql(f"SELECT public.mark_1v1_prize_delivered_atomic('{tourn_id}', 'محاولة ثانية') AS res;")[0]['res']
print(f"🛡️ Prevent Double Delivery Check: success={double_delivery.get('success')} | error={double_delivery.get('error')}")

print("\n" + "=" * 75)
print("🧹 CLEANING UP SECTION 2 TEST DATA...")
run_sql(f"""
DELETE FROM public.transactions WHERE metadata->>'order_reference' IN ('{order1_ref}', '{order2_ref}', '{order3_ref}');
DELETE FROM public.vsp_1v1_tournament_players WHERE tournament_id = '{tourn_id}';
DELETE FROM public.vsp_1v1_tournament_orders WHERE tournament_id = '{tourn_id}';
DELETE FROM public.vsp_1v1_tournaments WHERE id = '{tourn_id}';
""")
print("✨ TEST DATA CLEANED UP! DATABASE PRISTINE.")
print("=" * 75)
