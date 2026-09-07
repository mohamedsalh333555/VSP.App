"""
Verification script for VSP Architecture & Logic Hardening (Phases 1, 2, 3)
Tests:
1. get_owner_financial_summary & Zero-Trust Payout Balance Guard
2. Booking duration boundaries in create_booking_atomic
3. Immutable Audit Trail (system_audit_logs) triggering on changes
4. Stadium price automatic synchronization (price_per_hour <-> base_price)
"""

import json
import sys
from db_client import run_sql

def run_tests():
    print("==================================================")
    print("🚀 RUNNING ARCHITECTURAL HARDENING VERIFICATION")
    print("==================================================")

    # ----------------------------------------------------
    # TEST 1: Owner Payout Zero-Trust Guard
    # ----------------------------------------------------
    print("\n[TEST 1] Testing Owner Zero-Trust Payout Guard...")
    # Find an existing owner
    owners = run_sql("SELECT id, name FROM public.users WHERE role IN ('stadium_owner', 'owner') LIMIT 1;")
    if not owners:
        # Fallback to any user
        owners = run_sql("SELECT id, name FROM public.users LIMIT 1;")
    
    owner_id = owners[0]['id']
    owner_name = owners[0].get('name', 'Owner')
    print(f"  Testing with user: {owner_name} ({owner_id})")

    # Call get_owner_financial_summary as postgres superuser
    summary_sql = f"SELECT public.get_owner_financial_summary('{owner_id}'::uuid) as summary;"
    summary_res = run_sql(summary_sql)
    summary = summary_res[0]['summary']
    print(f"  Financial Summary Result: {json.dumps(summary, ensure_ascii=False)}")
    assert summary['success'] is True, "Financial summary failed!"

    # Attempt to request payout exceeding available balance (e.g. 5,000,000 EGP)
    payout_test_sql = f"""
    SELECT public.request_owner_payout_settlement_atomic(
        '{owner_id}'::uuid,
        5000000.0,
        'instapay',
        'test@instapay'
    ) as result;
    """
    payout_res = run_sql(payout_test_sql)
    payout_result = payout_res[0]['result']
    print(f"  Excessive Payout Result: {json.dumps(payout_result, ensure_ascii=False)}")
    assert payout_result['success'] is False, "Excessive payout was incorrectly allowed!"
    assert "يتجاوز رصيدك" in payout_result['error'], "Error message did not mention exceeding balance!"
    print("  ✅ PASS: Excessive payout request strictly blocked by server.")

    # ----------------------------------------------------
    # TEST 2: Duration boundary check in create_booking_atomic
    # ----------------------------------------------------
    print("\n[TEST 2] Testing create_booking_atomic duration constraints...")
    # Attempt booking with duration = 5 minutes (< 30 min)
    duration_test_sql = f"""
    SELECT public.create_booking_atomic(
        '00000000-0000-0000-0000-000000000001',
        '{owner_id}',
        '{owner_id}',
        NOW() + INTERVAL '1 day',
        NOW() + INTERVAL '1 day' + INTERVAL '5 minutes',
        'personal',
        100.0
    ) as result;
    """
    dur_res = run_sql(duration_test_sql)
    dur_result = dur_res[0]['result']
    print(f"  Short Duration Result: {json.dumps(dur_result, ensure_ascii=False)}")
    assert dur_result['success'] is False, "5-minute booking was incorrectly allowed!"
    assert "30 دقيقة" in dur_result['message'], "Error message did not enforce 30-minute minimum!"
    print("  ✅ PASS: Unrealistic short booking duration strictly rejected.")

    # ----------------------------------------------------
    # TEST 3 & 4: Stadium Price Sync & Audit Trail Triggers
    # ----------------------------------------------------
    print("\n[TEST 3 & 4] Testing Stadium Price Sync & Audit Trail Trigger...")
    # Find or create a test stadium
    stadiums = run_sql("SELECT id, name, price_per_hour, base_price FROM public.stadiums LIMIT 1;")
    if stadiums:
        stadium_id = stadiums[0]['id']
        orig_price = stadiums[0]['price_per_hour']
        test_price = 375.0 if orig_price != 375.0 else 425.0
        print(f"  Updating stadium {stadium_id} price_per_hour to {test_price}...")

        # Update price_per_hour
        run_sql(f"UPDATE public.stadiums SET price_per_hour = {test_price} WHERE id = '{stadium_id}';")

        # Verify price sync
        updated = run_sql(f"SELECT price_per_hour, base_price FROM public.stadiums WHERE id = '{stadium_id}';")[0]
        print(f"  Verified prices: price_per_hour = {updated['price_per_hour']}, base_price = {updated['base_price']}")
        assert float(updated['price_per_hour']) == float(updated['base_price']) == test_price, "Price sync failed!"
        print("  ✅ PASS: Stadium price_per_hour and base_price automatically synchronized.")

        # Verify Audit Log
        audit_records = run_sql(f"""
            SELECT table_name, action, changed_fields, new_data->>'price_per_hour' as new_pph 
            FROM public.system_audit_logs 
            WHERE table_name = 'stadiums' AND record_id = '{stadium_id}' 
            ORDER BY created_at DESC LIMIT 1;
        """)
        print(f"  Audit Log Record: {json.dumps(audit_records, ensure_ascii=False)}")
        assert len(audit_records) > 0, "No audit log was generated for stadium update!"
        assert "price_per_hour" in audit_records[0]['changed_fields'], "changed_fields missing price_per_hour!"
        print("  ✅ PASS: Audit trail automatically captured table update with changed fields.")

        # Restore original price
        run_sql(f"UPDATE public.stadiums SET price_per_hour = {orig_price} WHERE id = '{stadium_id}';")
        print("  Original stadium price restored.")

    print("\n==================================================")
    print("🏆 ALL ARCHITECTURAL HARDENING TESTS PASSED 100%!")
    print("==================================================")

if __name__ == "__main__":
    run_tests()
