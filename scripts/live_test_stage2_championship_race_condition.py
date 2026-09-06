import json
import uuid
import sys
from db_client import run_sql

def run_test():
    print("=" * 75)
    print("STAGE 2 LIVE TEST: CHAMPIONSHIPS ATOMIC CONFIRMATION, OVER-CAPACITY RACE CONDITION & REFUND")
    print("=" * 75)

    # 1. Fetch real test users
    users = run_sql("SELECT id, name, email FROM public.users ORDER BY created_at ASC LIMIT 2;")
    if len(users) < 2:
        print("ERROR: Need at least 2 users in public.users")
        sys.exit(1)
    user1 = users[0]
    user2 = users[1]
    print(f"User 1 (Admin/Captain 1): {user1['name']} ({user1['id']})")
    print(f"User 2 (Captain 2):       {user2['name']} ({user2['id']})")

    # 2. Setup Test Championship with capacity = 2, fee = 150
    champ_id = str(uuid.uuid4())
    champ_name = f"بطولة اختبار التزامن - {champ_id[:8]}"
    create_champ_sql = f"""
    INSERT INTO public.championships (
        id, name, type, sport_type, start_date, end_date, entry_fee, grand_prize,
        prize_pool, max_teams, owner_id, governorate, status, joined_teams, paid_teams,
        prize_delivered, created_at, updated_at
    ) VALUES (
        '{champ_id}', '{champ_name}', 'tournament', 'football', now(), now() + interval '7 days',
        150.00, 1000.00, 0.00, 2, '{user1['id']}', 'Cairo', 'open', ARRAY[]::UUID[], ARRAY[]::UUID[],
        false, now(), now()
    ) RETURNING id, name, max_teams, entry_fee, prize_pool, status;
    """
    champ = run_sql(create_champ_sql)[0]
    print(f"\n[CREATED] Championship: {champ['name']}")
    print(f"          Max Teams: {champ['max_teams']} | Entry Fee: {champ['entry_fee']} EGP | Prize Pool: {champ['prize_pool']} EGP")

    # 3. Setup 3 Test Teams
    team_a_id = str(uuid.uuid4())
    team_b_id = str(uuid.uuid4())
    team_c_id = str(uuid.uuid4())
    teams_sql = f"""
    INSERT INTO public.teams (id, name, captain_id, created_at, updated_at)
    VALUES 
        ('{team_a_id}', 'فريق الاختبار أ', '{user1['id']}', now(), now()),
        ('{team_b_id}', 'فريق الاختبار ب', '{user2['id']}', now(), now()),
        ('{team_c_id}', 'فريق الاختبار ج', '{user1['id']}', now(), now())
    RETURNING id, name;
    """
    created_teams = run_sql(teams_sql)
    print(f"\n[CREATED] 3 Test Teams: {[t['name'] for t in created_teams]}")

    # 4. Create 3 Tournament Orders
    order1_ref = f"TOURN_TEST_RACE1_{champ_id[:6]}"
    order2_ref = f"TOURN_TEST_RACE2_{champ_id[:6]}"
    order3_ref = f"TOURN_TEST_RACE3_{champ_id[:6]}"
    order4_ref = f"TOURN_TEST_RACE4_{champ_id[:6]}"

    orders_sql = f"""
    INSERT INTO public.tournament_orders (
        id, championship_id, captain_user_id, team_id, amount, order_reference, payment_status, created_at, updated_at
    ) VALUES 
        (gen_random_uuid(), '{champ_id}', '{user1['id']}', '{team_a_id}', 150.00, '{order1_ref}', 'pending', now(), now()),
        (gen_random_uuid(), '{champ_id}', '{user2['id']}', '{team_b_id}', 150.00, '{order2_ref}', 'pending', now(), now()),
        (gen_random_uuid(), '{champ_id}', '{user1['id']}', '{team_c_id}', 150.00, '{order3_ref}', 'pending', now(), now()),
        (gen_random_uuid(), '{champ_id}', '{user1['id']}', '{team_c_id}', 150.00, '{order4_ref}', 'pending', now(), now())
    RETURNING id, order_reference, payment_status;
    """
    created_orders = run_sql(orders_sql)
    print(f"\n[CREATED] 4 Test Orders in pending status: {[o['order_reference'] for o in created_orders]}")

    # ----------------------------------------------------------------------
    # STEP 1: Confirm Team 1 (Capacity 1/2)
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 1: Confirming Team 1 via confirm_tournament_order_atomic...")
    res1 = run_sql(f"SELECT public.confirm_tournament_order_atomic('{order1_ref}', 'PAYMOB_TX_001') as result;")[0]['result']
    print("Result 1:", json.dumps(res1, ensure_ascii=False))
    assert res1.get('success') == True, "Step 1 failed!"

    # Verify championship prize_pool and joined count
    c_check1 = run_sql(f"SELECT prize_pool, array_length(joined_teams, 1) as joined_len, array_length(paid_teams, 1) as paid_len FROM public.championships WHERE id = '{champ_id}';")[0]
    print(f"State after Team 1: Joined = {c_check1['joined_len']}/2, Prize Pool = {c_check1['prize_pool']} EGP")
    assert float(c_check1['prize_pool']) == 150.0, f"Expected 150.0 prize pool, got {c_check1['prize_pool']}"
    assert c_check1['joined_len'] == 1, "Expected 1 joined team"

    # ----------------------------------------------------------------------
    # STEP 2: Confirm Team 2 (Capacity 2/2 - Full!)
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 2: Confirming Team 2 via confirm_tournament_order_atomic...")
    res2 = run_sql(f"SELECT public.confirm_tournament_order_atomic('{order2_ref}', 'PAYMOB_TX_002') as result;")[0]['result']
    print("Result 2:", json.dumps(res2, ensure_ascii=False))
    assert res2.get('success') == True, "Step 2 failed!"

    c_check2 = run_sql(f"SELECT prize_pool, array_length(joined_teams, 1) as joined_len, array_length(paid_teams, 1) as paid_len FROM public.championships WHERE id = '{champ_id}';")[0]
    print(f"State after Team 2: Joined = {c_check2['joined_len']}/2 (CAPACITY REACHED), Prize Pool = {c_check2['prize_pool']} EGP")
    assert float(c_check2['prize_pool']) == 300.0, f"Expected 300.0 prize pool, got {c_check2['prize_pool']}"
    assert c_check2['joined_len'] == 2, "Expected 2 joined teams"

    # ----------------------------------------------------------------------
    # STEP 3: Confirm Team 3 (RACE CONDITION OVER-CAPACITY DETECTION)
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 3: Confirming Team 3 (Over-capacity attempt)...")
    res3 = run_sql(f"SELECT public.confirm_tournament_order_atomic('{order3_ref}', 'PAYMOB_TX_003') as result;")[0]['result']
    print("Result 3:", json.dumps(res3, ensure_ascii=False))
    
    # Assertions for over-capacity rejection
    assert res3.get('success') == False, "Team 3 should NOT succeed!"
    assert res3.get('needs_refund') == True or res3.get('requires_refund') == True, "needs_refund flag must be true!"
    assert float(res3.get('amount')) == 150.0, "Refund amount must match order amount!"
    assert res3.get('order_reference') == order3_ref, "Order reference must match!"

    # Verify championship state remained untouched
    c_check3 = run_sql(f"SELECT prize_pool, array_length(joined_teams, 1) as joined_len FROM public.championships WHERE id = '{champ_id}';")[0]
    print(f"Championship State: Joined = {c_check3['joined_len']}/2, Prize Pool = {c_check3['prize_pool']} EGP (Untouched!)")
    assert float(c_check3['prize_pool']) == 300.0, "Prize pool must not increase for rejected order!"
    assert c_check3['joined_len'] == 2, "Joined teams must remain 2!"

    # Verify order status marked as failed_over_capacity
    o3 = run_sql(f"SELECT payment_status FROM public.tournament_orders WHERE order_reference = '{order3_ref}';")[0]
    print(f"Order 3 Status in DB: {o3['payment_status']}")
    assert o3['payment_status'] == 'failed_over_capacity', "Order status must be failed_over_capacity"

    # Verify initial transaction audit entry with order_reference in metadata
    t3 = run_sql(f"SELECT type, status, amount, metadata FROM public.transactions WHERE metadata->>'order_reference' = '{order3_ref}';")[0]
    print("Transaction 3 Audit Log:", json.dumps(t3, ensure_ascii=False))
    assert t3['type'] == 'refund', "Transaction type must be refund"
    assert t3['status'] == 'pending', "Initial transaction status must be pending"

    # ----------------------------------------------------------------------
    # STEP 4: Simulate Paymob Refund Success via record_tournament_refund_status_atomic
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 4: Simulating Successful Paymob Refund...")
    ref_res = run_sql(f"""
    SELECT public.record_tournament_refund_status_atomic(
        '{order3_ref}', 
        true, 
        'PAYMOB_REFUND_ID_778899', 
        NULL
    ) as result;
    """)[0]['result']
    print("Refund Result:", json.dumps(ref_res, ensure_ascii=False))
    assert ref_res.get('success') == True, "Refund recording failed!"
    assert ref_res.get('status') == 'refunded', "Status must be refunded"

    # Verify order status updated to refunded
    o3_after = run_sql(f"SELECT payment_status FROM public.tournament_orders WHERE order_reference = '{order3_ref}';")[0]
    print(f"Order 3 Status after refund: {o3_after['payment_status']}")
    assert o3_after['payment_status'] == 'refunded', "Order status must be refunded"

    # Verify transaction updated to completed with paymob_refund_id in metadata
    t3_after = run_sql(f"SELECT type, status, metadata FROM public.transactions WHERE metadata->>'order_reference' = '{order3_ref}';")[0]
    print("Transaction 3 Status after refund:", json.dumps(t3_after, ensure_ascii=False))
    assert t3_after['status'] == 'completed', "Transaction status must be completed"
    assert t3_after['metadata']['paymob_refund_id'] == 'PAYMOB_REFUND_ID_778899', "Paymob refund ID missing in metadata!"

    # ----------------------------------------------------------------------
    # STEP 5: Simulate Paymob Refund Failure (Manual Review Alert Path)
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 5: Simulating Failed Paymob Refund on Order 4 (Manual Review Path)...")
    res4 = run_sql(f"SELECT public.confirm_tournament_order_atomic('{order4_ref}', 'PAYMOB_TX_004') as result;")[0]['result']
    assert res4.get('success') == False and res4.get('needs_refund') == True

    fail_res = run_sql(f"""
    SELECT public.record_tournament_refund_status_atomic(
        '{order4_ref}', 
        false, 
        NULL, 
        'Gateway Error: Insufficient merchant account balance'
    ) as result;
    """)[0]['result']
    print("Failed Refund Result:", json.dumps(fail_res, ensure_ascii=False))
    assert fail_res.get('success') == True
    assert fail_res.get('status') == 'refund_failed_manual_review'

    o4_after = run_sql(f"SELECT payment_status FROM public.tournament_orders WHERE order_reference = '{order4_ref}';")[0]
    print(f"Order 4 Status after failed refund: {o4_after['payment_status']}")
    assert o4_after['payment_status'] == 'refund_failed_manual_review'

    t4_after = run_sql(f"SELECT type, status, metadata FROM public.transactions WHERE metadata->>'order_reference' = '{order4_ref}';")[0]
    print("Transaction 4 Status after failed refund:", json.dumps(t4_after, ensure_ascii=False))
    assert t4_after['status'] == 'failed', "Transaction status must be failed"
    assert 'Insufficient merchant account balance' in t4_after['metadata']['refund_error']

    # Check that high-priority admin alert notification was created
    admin_notifs = run_sql(f"SELECT title, body, type FROM public.notifications WHERE body LIKE '%{order4_ref}%';")
    print(f"Admin / Captain Notifications for Order 4: {len(admin_notifs)} records found")
    for n in admin_notifs:
        print(f"   [{n['type']}] {n['title']}: {n['body']}")
    assert len(admin_notifs) >= 1, "Expected notification for Order 4"

    # ----------------------------------------------------------------------
    # STEP 6: CLEAN TEARDOWN & PROOF OF ZERO LEFTOVER DATA
    # ----------------------------------------------------------------------
    print("\n" + "-" * 60)
    print("STEP 6: CLEAN TEARDOWN...")
    run_sql(f"DELETE FROM public.notifications WHERE body LIKE '%{order3_ref}%' OR body LIKE '%{order4_ref}%' OR body LIKE '%{champ_name}%';")
    run_sql(f"DELETE FROM public.transactions WHERE championship_id = '{champ_id}';")
    run_sql(f"DELETE FROM public.tournament_orders WHERE championship_id = '{champ_id}';")
    run_sql(f"DELETE FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}', '{team_c_id}');")
    run_sql(f"DELETE FROM public.championships WHERE id = '{champ_id}';")
    print("Deleted all test rows.")

    # Verification queries
    count_champ = run_sql(f"SELECT count(*) as cnt FROM public.championships WHERE id = '{champ_id}';")[0]['cnt']
    count_teams = run_sql(f"SELECT count(*) as cnt FROM public.teams WHERE id IN ('{team_a_id}', '{team_b_id}', '{team_c_id}');")[0]['cnt']
    count_orders = run_sql(f"SELECT count(*) as cnt FROM public.tournament_orders WHERE championship_id = '{champ_id}';")[0]['cnt']
    count_txs = run_sql(f"SELECT count(*) as cnt FROM public.transactions WHERE championship_id = '{champ_id}';")[0]['cnt']
    count_notifs = run_sql(f"SELECT count(*) as cnt FROM public.notifications WHERE body LIKE '%{order3_ref}%' OR body LIKE '%{order4_ref}%';")[0]['cnt']

    print("\nCLEANUP VERIFICATION (Must all be 0):")
    print(f"  Championships remaining: {count_champ}")
    print(f"  Teams remaining:         {count_teams}")
    print(f"  Orders remaining:        {count_orders}")
    print(f"  Transactions remaining:  {count_txs}")
    print(f"  Notifications remaining: {count_notifs}")

    total_leftovers = int(count_champ) + int(count_teams) + int(count_orders) + int(count_txs) + int(count_notifs)
    assert total_leftovers == 0, f"Cleanup incomplete! {total_leftovers} rows remaining."
    print("\nSUCCESS: 100% CLEAN DATABASE (count(*) = 0 across all tables).")
    print("=" * 75)

if __name__ == "__main__":
    run_test()
