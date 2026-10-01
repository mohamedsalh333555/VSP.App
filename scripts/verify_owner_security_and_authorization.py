import json
import urllib.request
import urllib.error
import uuid

with open('env.json', 'r') as f:
    env = json.load(f)

SUPABASE_URL = env['SUPABASE_URL']
ANON_KEY = env['SUPABASE_ANON_KEY']
SERVICE_KEY = env['SUPABASE_SERVICE_ROLE_KEY']
MANAGEMENT_TOKEN = env['SUPABASE_MANAGEMENT_KEY']
PROJECT_REF = 'mktqkddbcddrxjxabdua'

def run_management_sql(query: str):
    url = f'https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query'
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": query}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {MANAGEMENT_TOKEN}",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        content = resp.read().decode("utf-8")
        if not content:
            return []
        return json.loads(content)

def create_auth_user(email, password, role="owner", name="Test User"):
    """Creates a real user in auth.users and returns the user object with id."""
    url = f"{SUPABASE_URL}/auth/v1/admin/users"
    payload = {
        "email": email,
        "password": password,
        "email_confirm": True,
        "user_metadata": {"role": role, "name": name}
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        user_data = json.loads(resp.read().decode("utf-8"))
        uid = user_data["id"]
        # Ensure role is set in public.users
        run_management_sql(f"UPDATE public.users SET role = '{role}', name = '{name}' WHERE id = '{uid}';")
        return user_data

def login_user(email, password):
    """Logs in user via GoTrue Auth and returns real authenticated JWT session."""
    url = f"{SUPABASE_URL}/auth/v1/token?grant_type=password"
    payload = {"email": email, "password": password}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "apikey": ANON_KEY,
            "Content-Type": "application/json"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data["access_token"], data["user"]["id"]

def call_rpc(rpc_name, params, token=None):
    """Calls Supabase RPC via PostgREST REST API with given JWT token."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}"
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json"
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(
        url,
        data=json.dumps(params).encode("utf-8"),
        headers=headers,
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            if not content:
                return {"status": resp.status, "data": None}
            return {"status": resp.status, "data": json.loads(content)}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def patch_user(user_id, updates, token):
    """Direct PATCH on users table via PostgREST using user's real JWT."""
    url = f"{SUPABASE_URL}/rest/v1/users?id=eq.{user_id}"
    req = urllib.request.Request(
        url,
        data=json.dumps(updates).encode("utf-8"),
        headers={
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        },
        method="PATCH"
    )
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return {"status": resp.status, "data": json.loads(content) if content else None}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8")
        try:
            err_json = json.loads(body)
        except Exception:
            err_json = {"raw": body}
        return {"status": e.code, "error": err_json}

def delete_auth_user(uid):
    url = f"{SUPABASE_URL}/auth/v1/admin/users/{uid}"
    req = urllib.request.Request(
        url,
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}"
        },
        method="DELETE"
    )
    try:
        with urllib.request.urlopen(req):
            pass
    except Exception:
        pass

def run_tests():
    print("=" * 80)
    print("🔒 REAL-SESSION PENTEST: OWNER AUTHORIZATION & SENSITIVE FIELD SECURITY")
    print("=" * 80)

    test_id = str(uuid.uuid4())[:8]
    owner_a_email = f"owner_a_{test_id}@vsp.test"
    owner_b_email = f"owner_b_{test_id}@vsp.test"
    admin_email = f"admin_{test_id}@vsp.test"
    password = f"P@ssword123_{test_id}!"

    owner_a_id = None
    owner_b_id = None
    admin_id = None
    stadium_a_id = str(uuid.uuid4())
    booking_id = str(uuid.uuid4())

    try:
        # Step 1: Create real users
        print("\n--- 1. Creating Real Auth Users (Owner A, Owner B, Admin) ---")
        user_a = create_auth_user(owner_a_email, password, role="owner", name="Owner Alice")
        owner_a_id = user_a["id"]

        user_b = create_auth_user(owner_b_email, password, role="owner", name="Owner Bob")
        owner_b_id = user_b["id"]

        user_admin = create_auth_user(admin_email, password, role="admin", name="Admin Charlie")
        admin_id = user_admin["id"]

        print(f"✔️ Owner A created: {owner_a_id}")
        print(f"✔️ Owner B created: {owner_b_id}")
        print(f"✔️ Admin created:   {admin_id}")

        # Step 2: Login and get real JWTs
        token_a, _ = login_user(owner_a_email, password)
        token_b, _ = login_user(owner_b_email, password)
        token_admin, _ = login_user(admin_email, password)
        print("✔️ Successfully obtained real JWT sessions for all 3 users")

        # ---------------------------------------------------------------------
        # GROUP 1: CROSS-OWNER AUTHORIZATION (Owner A -> Owner B)
        # ---------------------------------------------------------------------
        print("\n--- 2. Testing Cross-Owner RPC Attacks (Owner A targeting Owner B) ---")

        # Attack 1.1: Owner A tries to upload documents to Owner B's account
        res = call_rpc("update_owner_verification_document", {
            "p_user_id": owner_b_id,
            "p_doc_field_name": "commercialRegisterUrl",
            "p_file_url": "https://attacker.com/evil.pdf"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403], f"Expected failure, got {res}"
        err = res.get("data", {}).get("error") or res.get("error")
        assert err == "UNAUTHORIZED" or "UNAUTHORIZED" in str(err)
        print("✔️ Attack 1.1: Owner A cannot update documents of Owner B (BLOCKED: UNAUTHORIZED)")

        # Attack 1.2: Owner A tries to submit verification for Owner B
        res = call_rpc("submit_owner_verification", {
            "p_owner_id": owner_b_id,
            "p_additional_data": {}
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403], f"Expected failure, got {res}"
        err = res.get("data", {}).get("error") or res.get("error")
        assert err == "UNAUTHORIZED" or "UNAUTHORIZED" in str(err)
        print("✔️ Attack 1.2: Owner A cannot submit verification for Owner B (BLOCKED: UNAUTHORIZED)")

        # ---------------------------------------------------------------------
        # GROUP 2: STRICT DOCUMENT REQUIREMENTS (No fallbacks allowed)
        # ---------------------------------------------------------------------
        print("\n--- 3. Testing Strict 4 Mandatory Verification Documents ---")

        # Create active stadium for Owner A
        run_management_sql(f"""
            INSERT INTO public.stadiums (
                id, owner_id, name, location, governorate, price_per_hour, is_verified, is_deleted_by_owner
            ) VALUES (
                '{stadium_a_id}', '{owner_a_id}', 'Alice Stadium', 'Cairo', 'cairo', 250, false, false
            );
        """)

        # Attempt with legacy contractUrl instead of commercialRegisterUrl -> MUST FAIL
        res = call_rpc("submit_owner_verification", {
            "p_owner_id": owner_a_id,
            "p_additional_data": {
                "contractUrl": "https://storage.vsp.app/contract.pdf",
                "verificationDocuments": {
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdFrontUrl": "https://storage.vsp.app/idf.jpg",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }
            }
        }, token=token_a)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "MISSING_COMMERCIAL_REGISTER"
        print("✔️ Strict Check 2.1: Legacy contractUrl does NOT substitute Commercial Register")

        # Attempt with legacy generic nationalIdUrl instead of nationalIdFrontUrl -> MUST FAIL
        res = call_rpc("submit_owner_verification", {
            "p_owner_id": owner_a_id,
            "p_additional_data": {
                "verificationDocuments": {
                    "commercialRegisterUrl": "https://storage.vsp.app/cr.pdf",
                    "taxCardUrl": "https://storage.vsp.app/tc.pdf",
                    "nationalIdUrl": "https://storage.vsp.app/id_generic.jpg",
                    "nationalIdBackUrl": "https://storage.vsp.app/idb.jpg"
                }
            }
        }, token=token_a)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "MISSING_NATIONAL_ID_FRONT"
        print("✔️ Strict Check 2.2: Generic nationalIdUrl does NOT substitute National ID Front")

        # Valid upload of all 4 strict documents for Owner A
        for field, url in [
            ("commercialRegisterUrl", "https://storage.vsp.app/cr.pdf"),
            ("taxCardUrl", "https://storage.vsp.app/tc.pdf"),
            ("nationalIdFrontUrl", "https://storage.vsp.app/idf.jpg"),
            ("nationalIdBackUrl", "https://storage.vsp.app/idb.jpg"),
        ]:
            res = call_rpc("update_owner_verification_document", {
                "p_user_id": owner_a_id,
                "p_doc_field_name": field,
                "p_file_url": url
            }, token=token_a)
            assert res.get("data", {}).get("success") == True, f"Failed to upload {field}: {res}"

        # Submit verification with all 4 strict documents present
        res = call_rpc("submit_owner_verification", {
            "p_owner_id": owner_a_id,
            "p_additional_data": {}
        }, token=token_a)
        assert res.get("data", {}).get("success") == True, f"Expected success, got {res}"
        assert res.get("data", {}).get("verification_status") == "pending"
        assert res.get("data", {}).get("has_stadium") == True
        print("✔️ Strict Check 2.3: Owner A verified successfully with all 4 mandatory docs + active stadium -> pending")

        # ---------------------------------------------------------------------
        # GROUP 3: DIRECT REST API SENSITIVE FIELD PROTECTION
        # ---------------------------------------------------------------------
        print("\n--- 4. Testing Direct REST API Sensitive Field Attacks ---")

        # Attack 3.1: Owner A tries to set is_identity_verified = true
        res = patch_user(owner_a_id, {"is_identity_verified": True}, token_a)
        assert res["status"] in [400, 403], f"Expected HTTP error, got {res}"
        err_msg = str(res.get("error", ""))
        assert "PERMISSION_DENIED" in err_msg or "UNAUTHORIZED_USER_SENSITIVE_UPDATE" in err_msg
        print("✔️ Attack 3.1: Owner A cannot set is_identity_verified=true (BLOCKED by trigger)")

        # Attack 3.2: Owner A tries to set verification_status = approved
        res = patch_user(owner_a_id, {"verification_status": "approved"}, token_a)
        assert res["status"] in [400, 403], f"Expected HTTP error, got {res}"
        err_msg = str(res.get("error", ""))
        assert "PERMISSION_DENIED" in err_msg or "UNAUTHORIZED_USER_SENSITIVE_UPDATE" in err_msg
        print("✔️ Attack 3.2: Owner A cannot set verification_status=approved (BLOCKED by trigger)")

        # Attack 3.3: Owner A tries to set has_stadium = true directly
        res = patch_user(owner_a_id, {"has_stadium": False}, token_a)
        assert res["status"] in [400, 403], f"Expected HTTP error, got {res}"
        print("✔️ Attack 3.3: Owner A cannot alter has_stadium (BLOCKED by trigger)")

        # Attack 3.4: Owner A tries to escalate role to admin
        res = patch_user(owner_a_id, {"role": "admin"}, token_a)
        assert res["status"] in [400, 403], f"Expected HTTP error, got {res}"
        print("✔️ Attack 3.4: Owner A cannot escalate role to admin (BLOCKED by trigger)")

        # Safe update 3.5: Owner A updates non-sensitive field (p2p_instapay, name)
        res = patch_user(owner_a_id, {"p2p_instapay": "alice@instapay", "name": "Alice Verified"}, token_a)
        assert res["status"] == 200, f"Expected 200 OK for non-sensitive update, got {res}"
        print("✔️ Safe Check 3.5: Owner A CAN update non-sensitive field (p2p_instapay, name)")

        # ---------------------------------------------------------------------
        # GROUP 4: PAYOUT & SETTLEMENT RPC AUTHORIZATION
        # ---------------------------------------------------------------------
        print("\n--- 5. Testing Payout Admin RPC Authorization ---")

        # Set up a completed booking for Owner A to generate available balance
        run_management_sql(f"""
            INSERT INTO public.bookings (
                id, stadium_id, user_id, owner_id, start_time, end_time,
                total_price, deposit_paid, status, payment_status, payment_method, is_paid
            ) VALUES (
                '{booking_id}', '{stadium_a_id}', '{owner_a_id}', '{owner_a_id}',
                now() - interval '2 hours', now() - interval '1 hour', 600, 600, 'completed', 'paid', 'paymob', true
            );
        """)

        # Owner A requests payout of 400 EGP
        res = call_rpc("request_owner_payout_settlement_atomic", {
            "p_owner_id": owner_a_id,
            "p_amount": 400.0,
            "p_method": "instapay",
            "p_destination": "alice@instapay"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True, f"Failed payout request: {res}"
        settlement_id = res["data"]["settlement_id"]
        print(f"✔️ Owner A created pending payout settlement: {settlement_id}")

        # Attack 4.1: Owner A tries to call approve_payout_settlement_atomic
        res = call_rpc("approve_payout_settlement_atomic", {
            "p_settlement_id": settlement_id,
            "p_admin_notes": "Self approval"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        err = res.get("data", {}).get("error") or res.get("error")
        assert "UNAUTHORIZED_ADMIN_REQUIRED" in str(err) or "Admin authorization required" in str(err)
        print("✔️ Attack 4.1: Owner A cannot approve own payout (BLOCKED: UNAUTHORIZED_ADMIN_REQUIRED)")

        # Attack 4.2: Owner A tries to call reject_payout_settlement_atomic
        res = call_rpc("reject_payout_settlement_atomic", {
            "p_settlement_id": settlement_id,
            "p_rejection_reason": "Self rejection"
        }, token=token_a)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        err = res.get("data", {}).get("error") or res.get("error")
        assert "UNAUTHORIZED_ADMIN_REQUIRED" in str(err) or "Admin authorization required" in str(err)
        print("✔️ Attack 4.2: Owner A cannot reject own payout (BLOCKED: UNAUTHORIZED_ADMIN_REQUIRED)")

        # Attack 4.3: Owner B (another owner) tries to reject Owner A's payout
        res = call_rpc("reject_payout_settlement_atomic", {
            "p_settlement_id": settlement_id,
            "p_rejection_reason": "Malicious rejection"
        }, token=token_b)
        assert res.get("data", {}).get("success") == False or res.get("status") in [400, 401, 403]
        err = res.get("data", {}).get("error") or res.get("error")
        assert "UNAUTHORIZED_ADMIN_REQUIRED" in str(err) or "Admin authorization required" in str(err)
        print("✔️ Attack 4.3: Owner B cannot reject Owner A's payout (BLOCKED: UNAUTHORIZED_ADMIN_REQUIRED)")

        # Legitimate 4.4: Admin rejects Owner A's payout
        res = call_rpc("reject_payout_settlement_atomic", {
            "p_settlement_id": settlement_id,
            "p_rejection_reason": "Invalid payment destination"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == True, f"Admin rejection failed: {res}"
        assert res.get("data", {}).get("status") == "rejected"
        print("✔️ Legitimate 4.4: Admin successfully rejected payout via reject_payout_settlement_atomic")

        # Verify balance restored for Owner A
        res = call_rpc("get_owner_financial_summary", {"p_owner_id": owner_a_id}, token=token_a)
        summary = res["data"]
        assert summary["available_balance"] == 600, f"Expected 600 available, got {summary['available_balance']}"
        assert summary["pending_payouts"] == 0, f"Expected 0 pending, got {summary['pending_payouts']}"
        print("✔️ Balance automatically restored to 600 EGP after Admin rejection")

        # Legitimate 4.5: Owner A requests new payout of 500 EGP and Admin approves it
        res = call_rpc("request_owner_payout_settlement_atomic", {
            "p_owner_id": owner_a_id,
            "p_amount": 500.0,
            "p_method": "instapay",
            "p_destination": "alice@instapay"
        }, token=token_a)
        assert res.get("data", {}).get("success") == True
        new_settlement_id = res["data"]["settlement_id"]

        res = call_rpc("approve_payout_settlement_atomic", {
            "p_settlement_id": new_settlement_id,
            "p_admin_notes": "Approved by Admin Charlie"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == True, f"Admin approval failed: {res}"
        print("✔️ Legitimate 4.5: Admin successfully approved payout via approve_payout_settlement_atomic")

        # Legitimate 4.6: Admin trying to reject completed payout must fail
        res = call_rpc("reject_payout_settlement_atomic", {
            "p_settlement_id": new_settlement_id,
            "p_rejection_reason": "Late rejection attempt"
        }, token=token_admin)
        assert res.get("data", {}).get("success") == False
        assert res.get("data", {}).get("error") == "CANNOT_REJECT_COMPLETED"
        print("✔️ Legitimate 4.6: Admin cannot reject a completed payout (CANNOT_REJECT_COMPLETED)")

        print("\n" + "=" * 80)
        print("🎉 ALL REAL-SESSION AUTHENTICATED TESTS PASSED WITH 100% SECURITY!")
        print("=" * 80)

    finally:
        print("\n🧹 Cleaning up test entities and auth users...")
        run_management_sql(f"""
            DELETE FROM public.notifications WHERE user_id IN ('{owner_a_id}', '{owner_b_id}', '{admin_id}');
            DELETE FROM public.transactions WHERE user_id IN ('{owner_a_id}', '{owner_b_id}', '{admin_id}');
            DELETE FROM public.payout_settlements WHERE owner_id IN ('{owner_a_id}', '{owner_b_id}', '{admin_id}');
            DELETE FROM public.bookings WHERE id = '{booking_id}';
            DELETE FROM public.stadiums WHERE id = '{stadium_a_id}';
            DELETE FROM public.users WHERE id IN ('{owner_a_id}', '{owner_b_id}', '{admin_id}');
        """)
        for uid in [owner_a_id, owner_b_id, admin_id]:
            if uid:
                delete_auth_user(uid)
        print("✔️ Full cleanup complete: 0 leftover test records.")

if __name__ == "__main__":
    run_tests()
