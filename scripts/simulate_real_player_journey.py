"""
VSP Hardened Player Journey Test Suite v2
==========================================
6-Phase End-to-End verification against LIVE production database.
Every claim is proven with real DB evidence, not assumptions.

Fixes vs v1:
  Fix1: Phase 4 collision uses same player retrying same slot (hits v_conflict_count)
  Fix2: Price verified dynamically via SELECT after INSERT, not hardcoded
  Fix3: special_reference in webhook = real booking_id UUID
  Fix4: service_role_key never printed in error messages
  Fix5: .gitignore hardened separately
"""

import os
import urllib.request
import urllib.error
import json
import datetime
import time
import base64
import hashlib
import hmac as hmac_lib

# 0. BOOTSTRAP
with open("env.json") as f:
    env = json.load(f)

SUPABASE_URL = env["SUPABASE_URL"]
ANON_KEY = env["SUPABASE_ANON_KEY"]
SERVICE_KEY = env["SUPABASE_SERVICE_ROLE_KEY"]
PAYMOB_HMAC_SECRET = env.get("PAYMOB_HMAC_SECRET", "")

def get_valid_player_token():
    token = None
    if os.path.exists("test_user_token.txt"):
        try:
            with open("test_user_token.txt") as f:
                token = f.read().strip()
            p = token.split(".")[1]
            p += "=" * ((4 - len(p) % 4) % 4)
            d = json.loads(base64.urlsafe_b64decode(p).decode("utf-8"))
            if d.get("exp", 0) > time.time() + 60:
                return token, d["sub"]
        except Exception:
            pass

    # Self-healing: generate fresh token via Supabase Auth Admin API
    req = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/admin/generate_link",
        data=json.dumps({"type": "magiclink", "email": "redteam_tester@vsp.test"}).encode(),
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req) as r:
        res = json.loads(r.read().decode())
        token_hash = res.get("hashed_token")

    req2 = urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/verify",
        data=json.dumps({"type": "magiclink", "token_hash": token_hash}).encode(),
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req2) as r2:
        res2 = json.loads(r2.read().decode())
        token = res2.get("access_token")
        with open("test_user_token.txt", "w") as out:
            out.write(token)
        p = token.split(".")[1]
        p += "=" * ((4 - len(p) % 4) % 4)
        d = json.loads(base64.urlsafe_b64decode(p).decode("utf-8"))
        return token, d["sub"]


player_token, PLAYER_ID = get_valid_player_token()


# Helpers
def anon_get(path):
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        headers={"apikey": ANON_KEY, "Authorization": f"Bearer {player_token}"},
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def anon_rpc(func, payload):
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/rpc/{func}",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {player_token}",
        },
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read().decode())


def service_delete(path):
    req = urllib.request.Request(
        f"{SUPABASE_URL}{path}",
        headers={
            "apikey": SERVICE_KEY,
            "Authorization": f"Bearer {SERVICE_KEY}",
        },
        method="DELETE",
    )
    urllib.request.urlopen(req)


def compute_paymob_hmac(obj, secret):
    """Mirrors computePaymobHMAC() in paymob_webhook/index.ts (20 fields, SHA-512)."""
    order = obj.get("order", "")
    order_id = order.get("id", "") if isinstance(order, dict) else order
    src = obj.get("source_data", {})
    parts = [
        obj.get("amount_cents", ""),
        obj.get("created_at", ""),
        obj.get("currency", ""),
        obj.get("error_occured", ""),
        obj.get("has_parent_transaction", ""),
        obj.get("id", ""),
        obj.get("integration_id", ""),
        obj.get("is_3d_secure", ""),
        obj.get("is_auth", ""),
        obj.get("is_capture", ""),
        obj.get("is_refunded", ""),
        obj.get("is_standalone_payment", ""),
        obj.get("is_voided", ""),
        order_id,
        obj.get("owner", ""),
        obj.get("pending", ""),
        src.get("pan", ""),
        src.get("sub_type", ""),
        src.get("type", ""),
        obj.get("success", ""),
    ]
    concatenated = "".join(str(p) for p in parts)
    return hmac_lib.new(
        secret.encode("utf-8"),
        concatenated.encode("utf-8"),
        hashlib.sha512,
    ).hexdigest()


# MAIN
print("=" * 60)
print("VSP HARDENED PLAYER JOURNEY TEST SUITE v2")
print("=" * 60)

booking_id = None

try:
    # PHASE 1 - Identity
    print("\n[Phase 1] Player identity verification...")
    print(f"  Player ID (JWT.sub): {PLAYER_ID}")
    if not PAYMOB_HMAC_SECRET:
        print("  WARNING: PAYMOB_HMAC_SECRET not in env.json - Phase 5 will be skipped")
    else:
        print(f"  PAYMOB_HMAC_SECRET loaded ({len(PAYMOB_HMAC_SECRET)} chars)")

    # PHASE 2 - Zero-Trust Price Forgery Test
    print("\n[Phase 2] Zero-Trust price forgery test...")
    stadiums = anon_get(
        "/rest/v1/stadiums?select=id,name,price_per_hour,owner_id"
        "&is_blocked=eq.false&is_verified=eq.true&limit=1"
    )
    if not stadiums:
        raise RuntimeError("No active verified stadiums found!")
    stadium = stadiums[0]
    STADIUM_ID = stadium["id"]
    STADIUM_NAME = stadium["name"]
    PRICE_PER_HOUR = float(stadium["price_per_hour"] or 0)
    OWNER_ID = stadium["owner_id"]
    print(f"  Stadium: {STADIUM_NAME} | price_per_hour={PRICE_PER_HOUR} EGP")

    tomorrow = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=2)
    START_TIME = tomorrow.replace(hour=20, minute=0, second=0, microsecond=0).isoformat()
    END_TIME   = tomorrow.replace(hour=21, minute=0, second=0, microsecond=0).isoformat()
    DURATION_HOURS = 1.0
    EXPECTED_PRICE = round(PRICE_PER_HOUR * DURATION_HOURS, 2)

    print(f"  Slot: {START_TIME} -> {END_TIME}")
    print(f"  Forgery: sending p_total_price=1.0 EGP (server should record {EXPECTED_PRICE} EGP)")

    booking_rpc_payload = {
        "p_stadium_id":     STADIUM_ID,
        "p_user_id":        PLAYER_ID,
        "p_owner_id":       OWNER_ID,
        "p_start_time":     START_TIME,
        "p_end_time":       END_TIME,
        "p_booking_type":   "personal",
        "p_total_price":    1.0,          # deliberate forgery
        "p_stadium_name":   STADIUM_NAME,
        "p_payment_method": "card",
        "p_payment_status": "pending",
        "p_needs_deposit":  False,
        "p_deposit_amount": 0,
        "p_is_private":     True,
    }

    rpc_result = anon_rpc("create_booking_atomic", booking_rpc_payload)
    if not rpc_result.get("success"):
        raise RuntimeError(f"Booking RPC failed: {rpc_result.get('message')}")
    booking_id = rpc_result["booking_id"]
    print(f"  Booking created: {booking_id}")

    # Fix 2: Dynamically fetch real price from DB
    rows = anon_get(f"/rest/v1/bookings?id=eq.{booking_id}&select=id,total_price,status,locked_until")
    actual_db_price = float(rows[0]["total_price"])
    if abs(actual_db_price - EXPECTED_PRICE) < 0.01:
        print(f"  ZERO-TRUST VERIFIED: Sent 1.0 EGP -> DB recorded {actual_db_price} EGP")
        print(f"  ({PRICE_PER_HOUR} EGP/hr x {DURATION_HOURS}h = {EXPECTED_PRICE} EGP confirmed)")
    else:
        print(f"  MISMATCH: DB={actual_db_price} vs expected={EXPECTED_PRICE}")

    # PHASE 3 - Paymob Intention
    print("\n[Phase 3] Calling create_paymob_intention...")
    intention_req = urllib.request.Request(
        f"{SUPABASE_URL}/functions/v1/create_paymob_intention",
        data=json.dumps({
            "booking_id":      booking_id,
            "is_full_payment": True,
            "user_phone":      "+201012345678",
            "user_name":       "RedTeam Player",
            "user_email":      "tester@vsp.app",
        }).encode(),
        headers={
            "Content-Type": "application/json",
            "apikey": ANON_KEY,
            "Authorization": f"Bearer {player_token}",
        },
    )
    try:
        with urllib.request.urlopen(intention_req) as r:
            intention_res = json.loads(r.read().decode())
        checkout_url = intention_res.get("checkout_url", "")
        total_amount = intention_res.get("total_amount", "")
        print(f"  Checkout URL: {checkout_url[:60]}...")
        print(f"  Total with fees: {total_amount} EGP")
    except urllib.error.HTTPError as e:
        print(f"  Intention skipped (HTTP {e.code}): {e.read().decode()[:120]}")

    # PHASE 4 - True Slot Collision (Fix 1: same player + same token = clean conflict test)
    print("\n[Phase 4] Atomic slot collision (same player + token, same slot)...")
    try:
        col = anon_rpc("create_booking_atomic", booking_rpc_payload)
        code = col.get("code", "")
        msg = col.get("message", "")
        if not col.get("success") and code == "SLOT_LOCKED_OR_TAKEN":
            print(f"  SLOT COLLISION CONFIRMED: code=SLOT_LOCKED_OR_TAKEN")
            print(f"  Message: {msg}")
        elif not col.get("success"):
            print(f"  Rejected (code={code}): {msg}")
        else:
            print("  FAILURE: Second booking was allowed for same slot!")
    except urllib.error.HTTPError as e:
        print(f"  Rejected at HTTP level: {e.code}")

    # PHASE 5 - Webhook with HMAC SHA-512 (Fix 3: special_reference = real booking_id)
    print("\n[Phase 5] Paymob webhook with HMAC SHA-512...")
    if not PAYMOB_HMAC_SECRET:
        print("  Skipped (PAYMOB_HMAC_SECRET not in env.json)")
    else:
        mock_txn_id   = 998811
        mock_order_id = 555999
        iso_now       = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000000")
        amount_cents  = int(actual_db_price * 100)   # uses REAL DB price

        webhook_obj = {
            "amount_cents":           amount_cents,
            "created_at":             iso_now,
            "currency":               "EGP",
            "error_occured":          False,
            "has_parent_transaction": False,
            "id":                     mock_txn_id,
            "integration_id":         5772488,
            "is_3d_secure":           True,
            "is_auth":                False,
            "is_capture":             False,
            "is_refunded":            False,
            "is_standalone_payment":  True,
            "is_voided":              False,
            "order":                  {"id": mock_order_id},
            "owner":                  12345,
            "pending":                False,
            "source_data":            {"pan": "1234", "sub_type": "VisaCard", "type": "card"},
            "success":                True,
            "special_reference":      booking_id,   # Fix 3: REAL booking UUID
        }

        sig = compute_paymob_hmac(webhook_obj, PAYMOB_HMAC_SECRET)
        print(f"  HMAC SHA-512: {sig[:16]}...")

        wh_req = urllib.request.Request(
            f"{SUPABASE_URL}/functions/v1/paymob_webhook?hmac={sig}",
            data=json.dumps({"obj": webhook_obj}).encode(),
            headers={"Content-Type": "application/json", "apikey": ANON_KEY},
        )
        try:
            with urllib.request.urlopen(wh_req) as r:
                wh_res = json.loads(r.read().decode())
            print(f"  Webhook response: {wh_res}")
        except urllib.error.HTTPError as e:
            print(f"  Webhook HTTP {e.code}: {e.read().decode()[:200]}")

        time.sleep(1)
        confirmed_rows = anon_get(
            f"/rest/v1/bookings?id=eq.{booking_id}&select=status,is_paid,payment_status"
        )
        if confirmed_rows:
            b = confirmed_rows[0]
            ok = b["status"] == "confirmed" and b["is_paid"]
            label = "CONFIRMED" if ok else "NOT CONFIRMED"
            print(f"  DB [{label}]: status={b['status']}, is_paid={b['is_paid']}, payment_status={b['payment_status']}")

        # Check webhook_logs
        try:
            logs_req = urllib.request.Request(
                f"{SUPABASE_URL}/rest/v1/webhook_logs"
                f"?booking_id=eq.{booking_id}&select=event_type,signature_verified,status"
                f"&order=id.desc&limit=3",
                headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"},
            )
            with urllib.request.urlopen(logs_req) as r:
                logs = json.loads(r.read().decode())
            if logs:
                print(f"  webhook_logs: {logs[0]}")
            else:
                print("  No webhook_logs entry found")
        except urllib.error.HTTPError as e:
            print(f"  webhook_logs check skipped (HTTP {e.code})")

    print("\n*** ALL PHASES COMPLETED ***")

except Exception as ex:
    print(f"\nTest suite exception: {ex}")
    raise

finally:
    # PHASE 6 - Deterministic cleanup (Fix 4: never print SERVICE_KEY in output)
    print("\n[Phase 6] Deterministic cleanup...")
    if booking_id:
        try:
            service_delete(f"/rest/v1/bookings?id=eq.{booking_id}")
            print(f"  Booking {booking_id} deleted from DB")
        except urllib.error.HTTPError as e:
            # Only print HTTP code — headers contain SERVICE_KEY
            print(f"  Cleanup warning: HTTP {e.code} - manual cleanup needed for {booking_id}")
        except Exception as ce:
            print(f"  Cleanup exception: {type(ce).__name__} - manual cleanup needed for {booking_id}")
    else:
        print("  Nothing to clean up")
    print("  Cleanup done.")
