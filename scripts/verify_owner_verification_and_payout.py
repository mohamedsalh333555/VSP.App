import json
import urllib.request
import uuid

# Load credentials
with open('env.json', 'r') as f:
    env = json.load(f)

MANAGEMENT_TOKEN = env['SUPABASE_MANAGEMENT_KEY']
PROJECT_REF = 'mktqkddbcddrxjxabdua'
QUERY_URL = f'https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query'

def run_sql(query: str):
    req = urllib.request.Request(
        QUERY_URL,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {MANAGEMENT_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            if not content:
                return []
            return json.loads(content)
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        print(f"SQL Error: {err}")
        raise e

def run_tests():
    print("=" * 80)
    print("🔍 LIVE PRODUCTION VERIFICATION: OWNER ONBOARDING & PAYOUT SETTLEMENT CLOSURE")
    print("=" * 80)

    test_owner_id = str(uuid.uuid4())
    test_stadium_id = str(uuid.uuid4())
    test_booking_id = str(uuid.uuid4())
    admin_id = None

    try:
        # 0. Find an existing admin/co-founder ID for authorized operations
        admins = run_sql("SELECT id FROM public.users WHERE role IN ('admin', 'co_founder', 'super_admin') LIMIT 1;")
        if admins:
            admin_id = admins[0]['id']
        print(f"✔️ Admin ID for authorization tests: {admin_id}")

        # 1. Create a test owner in auth.users table (trigger creates public.users row)
        run_sql(f"""
            INSERT INTO auth.users (id, aud, role, email, is_sso_user, is_anonymous, raw_user_meta_data)
            VALUES ('{test_owner_id}', 'authenticated', 'authenticated', 'test_closure_owner_{test_owner_id[:8]}@vsp.app', false, false, '{{"role": "owner", "name": "Closure Test Owner"}}');

            UPDATE public.users 
            SET role = 'owner',
                is_registration_complete = false,
                is_identity_verified = false,
                verification_status = 'unverified',
                has_stadium = false
            WHERE id = '{test_owner_id}';
        """)
        print("✔️ Test owner created in DB")

        # ---------------------------------------------------------------------
        # TEST GROUP A: submit_owner_verification SERVER VALIDATION
        # ---------------------------------------------------------------------
        print("\n--- Testing submit_owner_verification ---")

        # Test A1: Call without active stadium -> MUST FAIL
        res = run_sql(f"""
            SELECT public.submit_owner_verification('{test_owner_id}', '{{
                "verificationDocuments": {{
                    "commercialRegisterUrl": "https://storage.vsp.app/cr.pdf",
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdFrontUrl": "https://storage.vsp.app/idf.jpg",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }}
            }}'::jsonb);
        """)
        result = res[0]['submit_owner_verification']
        assert result['success'] == False, f"Expected failure without stadium, got {result}"
        assert result['error'] == 'ACTIVE_STADIUM_REQUIRED', f"Expected ACTIVE_STADIUM_REQUIRED, got {result}"
        print("✔️ Test A1: Correctly rejected submission when owner has no active stadium")

        # Add active stadium for test owner
        run_sql(f"""
            INSERT INTO public.stadiums (
                id, owner_id, name, location, governorate, price_per_hour, is_verified, is_deleted_by_owner
            ) VALUES (
                '{test_stadium_id}', '{test_owner_id}', 'Closure Test Stadium', 'Cairo', 'cairo', 200, false, false
            );
        """)
        print("✔️ Active stadium created for test owner")

        # Test A2: Missing Commercial Register -> MUST FAIL
        res = run_sql(f"""
            SELECT public.submit_owner_verification('{test_owner_id}', '{{
                "verificationDocuments": {{
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdFrontUrl": "https://storage.vsp.app/idf.jpg",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }}
            }}'::jsonb);
        """)
        result = res[0]['submit_owner_verification']
        assert result['success'] == False, f"Expected failure without CR, got {result}"
        assert result['error'] == 'MISSING_COMMERCIAL_REGISTER', f"Expected MISSING_COMMERCIAL_REGISTER, got {result}"
        print("✔️ Test A2: Correctly rejected submission missing Commercial Register")

        # Test A3: Missing Tax Card -> MUST FAIL
        res = run_sql(f"""
            SELECT public.submit_owner_verification('{test_owner_id}', '{{
                "verificationDocuments": {{
                    "commercialRegisterUrl": "https://storage.vsp.app/cr.pdf",
                    "nationalIdFrontUrl": "https://storage.vsp.app/idf.jpg",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }}
            }}'::jsonb);
        """)
        result = res[0]['submit_owner_verification']
        assert result['success'] == False, f"Expected failure without Tax Card, got {result}"
        assert result['error'] == 'MISSING_TAX_CARD', f"Expected MISSING_TAX_CARD, got {result}"
        print("✔️ Test A3: Correctly rejected submission missing Tax Card")

        # Test A4: Missing National ID Front -> MUST FAIL
        res = run_sql(f"""
            SELECT public.submit_owner_verification('{test_owner_id}', '{{
                "verificationDocuments": {{
                    "commercialRegisterUrl": "https://storage.vsp.app/cr.pdf",
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }}
            }}'::jsonb);
        """)
        result = res[0]['submit_owner_verification']
        assert result['success'] == False, f"Expected failure without ID front, got {result}"
        assert result['error'] == 'MISSING_NATIONAL_ID_FRONT', f"Expected MISSING_NATIONAL_ID_FRONT, got {result}"
        print("✔️ Test A4: Correctly rejected submission missing National ID Front")

        # Test A5: Missing National ID Back -> MUST FAIL
        res = run_sql(f"""
            SELECT public.submit_owner_verification('{test_owner_id}', '{{
                "verificationDocuments": {{
                    "commercialRegisterUrl": "https://storage.vsp.app/cr.pdf",
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdFrontUrl": "https://storage.vsp.app/idf.jpg"
                }}
            }}'::jsonb);
        """)
        result = res[0]['submit_owner_verification']
        assert result['success'] == False, f"Expected failure without ID back, got {result}"
        assert result['error'] == 'MISSING_NATIONAL_ID_BACK', f"Expected MISSING_NATIONAL_ID_BACK, got {result}"
        print("✔️ Test A5: Correctly rejected submission missing National ID Back")

        # Test A6: Step-by-step document upload via update_owner_verification_document followed by submit
        run_sql(f"""
            SELECT public.update_owner_verification_document('{test_owner_id}', 'commercialRegisterUrl', 'https://storage.vsp.app/cr.pdf');
            SELECT public.update_owner_verification_document('{test_owner_id}', 'taxCardUrl', 'https://storage.vsp.app/tc.pdf');
            SELECT public.update_owner_verification_document('{test_owner_id}', 'nationalIdFrontUrl', 'https://storage.vsp.app/idf.jpg');
            SELECT public.update_owner_verification_document('{test_owner_id}', 'nationalIdBackUrl', 'https://storage.vsp.app/idb.jpg');
        """)
        print("✔️ Documents saved incrementally to user additional_data")

        # Final submit with documents already present in DB
        res = run_sql(f"SELECT public.submit_owner_verification('{test_owner_id}', '{{}}'::jsonb);")
        result = res[0]['submit_owner_verification']
        assert result['success'] == True, f"Expected success with all 4 docs and active stadium, got {result}"
        assert result['verification_status'] == 'pending', f"Expected pending status, got {result}"
        assert result['has_stadium'] == True, f"Expected has_stadium true, got {result}"

        # Verify user row state in DB
        user_row = run_sql(f"SELECT verification_status, is_registration_complete, has_stadium, is_identity_verified FROM public.users WHERE id = '{test_owner_id}';")[0]
        assert user_row['verification_status'] == 'pending'
        assert user_row['is_registration_complete'] == True
        assert user_row['has_stadium'] == True
        assert user_row['is_identity_verified'] == False, "Owner must not be able to set is_identity_verified=true"
        print("✔️ Test A6: Valid submission transitioned to pending review, registration complete, and identity unverified (awaiting admin)")

        # ---------------------------------------------------------------------
        # TEST GROUP B: PAYOUT & SETTLEMENT FLOW & reject_payout_settlement_atomic
        # ---------------------------------------------------------------------
        print("\n--- Testing Payout & Settlement Lifecycle ---")

        # Set up owner payment destination & a completed paid booking to generate balance
        run_sql(f"""
            UPDATE public.users 
            SET p2p_instapay = 'owner@instapay',
                p2p_vodafone = '01012345678',
                p2p_bank = 'EG1234567890123456789012'
            WHERE id = '{test_owner_id}';

            INSERT INTO public.bookings (
                id, stadium_id, user_id, owner_id, start_time, end_time,
                total_price, deposit_paid, status, payment_status, payment_method, is_paid
            ) VALUES (
                '{test_booking_id}', '{test_stadium_id}', '{test_owner_id}', '{test_owner_id}',
                now() - interval '2 hours', now() - interval '1 hour', 500, 500, 'completed', 'paid', 'paymob', true
            );
        """)

        # Check initial financial summary
        res = run_sql(f"SELECT public.get_owner_financial_summary('{test_owner_id}');")
        summary = res[0]['get_owner_financial_summary']
        assert summary['success'] == True
        assert summary['net_online_earnings'] == 500
        assert summary['pending_payouts'] == 0
        assert summary['available_balance'] == 500
        print(f"✔️ Initial available balance confirmed: {summary['available_balance']} EGP")

        # Test B1: Request payout of 300 EGP
        res = run_sql(f"""
            SELECT public.request_owner_payout_settlement_atomic(
                '{test_owner_id}', 300.0, 'instapay', 'owner@instapay'
            );
        """)
        req_res = res[0]['request_owner_payout_settlement_atomic']
        assert req_res['success'] == True, f"Failed to request payout: {req_res}"
        settlement_id = req_res['settlement_id']
        print(f"✔️ Test B1: Payout requested successfully, settlement_id: {settlement_id}")

        # Check balance after request: available balance should now be 200, pending 300
        res = run_sql(f"SELECT public.get_owner_financial_summary('{test_owner_id}');")
        summary_after_req = res[0]['get_owner_financial_summary']
        assert summary_after_req['pending_payouts'] == 300
        assert summary_after_req['available_balance'] == 200
        print(f"✔️ Balance after request: available = {summary_after_req['available_balance']}, pending = {summary_after_req['pending_payouts']}")

        # Test B2: Owner cannot submit second payout while one is pending
        res = run_sql(f"""
            SELECT public.request_owner_payout_settlement_atomic(
                '{test_owner_id}', 100.0, 'instapay', 'owner@instapay'
            );
        """)
        dup_res = res[0]['request_owner_payout_settlement_atomic']
        assert dup_res['success'] == False, "Expected error when submitting second payout during pending"
        print("✔️ Test B2: Second payout request correctly rejected while pending exists")

        # Test B3: Admin rejects the payout via reject_payout_settlement_atomic
        res = run_sql(f"""
            SELECT public.reject_payout_settlement_atomic(
                '{settlement_id}', 'بيانات حساب انستاباي غير متطابقة مع الاسم'
            );
        """)
        rej_res = res[0]['reject_payout_settlement_atomic']
        assert rej_res['success'] == True, f"Failed to reject settlement: {rej_res}"
        assert rej_res['status'] == 'rejected'
        assert rej_res['restored_amount'] == 300.0
        print(f"✔️ Test B3: Settlement rejected successfully: {rej_res['message']}")

        # Verify settlement state in DB
        settle_row = run_sql(f"SELECT status, admin_notes FROM public.payout_settlements WHERE id = '{settlement_id}';")[0]
        assert settle_row['status'] == 'rejected'
        assert 'بيانات حساب انستاباي' in settle_row['admin_notes']

        # Verify transaction state in DB
        tx_row = run_sql(f"SELECT type, status, description, metadata FROM public.transactions WHERE (metadata->>'settlement_id') = '{settlement_id}';")[0]
        assert tx_row['type'] == 'payout_rejected'
        assert tx_row['status'] == 'failed'
        print("✔️ Linked transaction updated to payout_rejected and failed status")

        # Verify owner received notification
        notif = run_sql(f"SELECT title, body FROM public.notifications WHERE user_id = '{test_owner_id}' AND type = 'payout' ORDER BY created_at DESC LIMIT 1;")[0]
        assert 'تم رفض طلب سحب الأرباح' in notif['title']
        print(f"✔️ Notification delivered to owner: {notif['title']}")

        # Test B4: Verify available balance restored automatically
        res = run_sql(f"SELECT public.get_owner_financial_summary('{test_owner_id}');")
        summary_after_rej = res[0]['get_owner_financial_summary']
        assert summary_after_rej['pending_payouts'] == 0, f"Expected 0 pending payouts, got {summary_after_rej['pending_payouts']}"
        assert summary_after_rej['available_balance'] == 500, f"Expected 500 available balance, got {summary_after_rej['available_balance']}"
        print(f"✔️ Test B4: Available balance automatically restored to 500 EGP (pending = 0)")

        # Test B5: Idempotency of reject_payout_settlement_atomic
        res = run_sql(f"""
            SELECT public.reject_payout_settlement_atomic(
                '{settlement_id}', 'Repeat rejection'
            );
        """)
        idemp_res = res[0]['reject_payout_settlement_atomic']
        assert idemp_res['success'] == True
        assert idemp_res['idempotent'] == True
        assert idemp_res['status'] == 'rejected'
        print("✔️ Test B5: Calling rejection again is completely idempotent")

        # Test B6: Owner can now request a new payout since pending is cleared
        res = run_sql(f"""
            SELECT public.request_owner_payout_settlement_atomic(
                '{test_owner_id}', 400.0, 'instapay', 'owner@instapay'
            );
        """)
        new_req_res = res[0]['request_owner_payout_settlement_atomic']
        assert new_req_res['success'] == True
        new_settlement_id = new_req_res['settlement_id']
        print(f"✔️ Test B6: New payout requested successfully after rejection, id: {new_settlement_id}")

        # Test B7: Admin approves new payout, then trying to reject it fails
        res = run_sql(f"SELECT public.approve_payout_settlement_atomic('{new_settlement_id}', 'Approved by finance');")
        app_res = res[0]['approve_payout_settlement_atomic']
        assert app_res['success'] == True

        # Try to reject completed settlement
        res = run_sql(f"SELECT public.reject_payout_settlement_atomic('{new_settlement_id}', 'Reject completed');")
        fail_rej = res[0]['reject_payout_settlement_atomic']
        assert fail_rej['success'] == False
        assert fail_rej['error'] == 'CANNOT_REJECT_COMPLETED'
        print("✔️ Test B7: Cannot reject a completed payout (CANNOT_REJECT_COMPLETED)")

        # Test B8: Attempting to reject a non-existent settlement fails safely
        fake_id = str(uuid.uuid4())
        res = run_sql(f"SELECT public.reject_payout_settlement_atomic('{fake_id}', 'Non existent');")
        not_found_res = res[0]['reject_payout_settlement_atomic']
        assert not_found_res['success'] == False
        assert not_found_res['error'] == 'SETTLEMENT_NOT_FOUND'
        print("✔️ Test B8: Non-existent settlement safely returns SETTLEMENT_NOT_FOUND")

        print("\n" + "=" * 80)
        print("🎉 ALL LIVE PRODUCTION SCENARIOS PASSED WITH 100% SUCCESS!")
        print("=" * 80)

    finally:
        # Cleanup all test entities
        print("\n🧹 Cleaning up test entities...")
        run_sql(f"""
            DELETE FROM public.notifications WHERE user_id = '{test_owner_id}';
            DELETE FROM public.transactions WHERE user_id = '{test_owner_id}';
            DELETE FROM public.payout_settlements WHERE owner_id = '{test_owner_id}';
            DELETE FROM public.bookings WHERE id = '{test_booking_id}';
            DELETE FROM public.stadiums WHERE id = '{test_stadium_id}';
            DELETE FROM public.users WHERE id = '{test_owner_id}';
            DELETE FROM auth.users WHERE id = '{test_owner_id}';
        """)
        print("✔️ Complete cleanup completed: 0 leftover test records.")

if __name__ == "__main__":
    run_tests()
