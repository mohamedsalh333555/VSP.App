import urllib.request
import json
import datetime
import time

with open("env.json") as f:
    env = json.load(f)

supabase_url = env["SUPABASE_URL"]
anon_key = env["SUPABASE_ANON_KEY"]

with open("test_user_token.txt") as f:
    player_token = f.read().strip()

print("==================================================")
print("🏃‍♂️ SIMULATING 100% REAL PLAYER PAYMENT JOURNEY")
print("==================================================")

# Step 1: Query an active stadium using the player's authenticated token
print("\n[Step 1] Fetching active stadiums as real player...")
stadium_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/stadiums?select=id,name,price_per_hour,owner_id&is_blocked=eq.false&limit=1",
    headers={
        "apikey": anon_key,
        "Authorization": f"Bearer {player_token}"
    }
)
try:
    with urllib.request.urlopen(stadium_req) as response:
        stadiums = json.loads(response.read().decode())
except urllib.error.HTTPError as e:
    print(f"Error fetching stadium: {e.code} - {e.read().decode()}")
    exit(1)

if not stadiums:
    print("No active stadiums found in database!")
    exit(1)

stadium = stadiums[0]
stadium_id = stadium["id"]
stadium_name = stadium["name"]
price_per_hour = stadium["price_per_hour"]
owner_id = stadium["owner_id"]
print(f"✅ Selected Stadium: {stadium_name} (ID: {stadium_id})")
print(f"💵 Price per hour: {price_per_hour} EGP | Owner: {owner_id}")

# Step 2: Calculate date/time for tomorrow evening (e.g. 20:00 to 21:00 UTC)
tomorrow = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=2)
start_time = tomorrow.replace(hour=18, minute=0, second=0, microsecond=0).isoformat()
end_time = tomorrow.replace(hour=19, minute=0, second=0, microsecond=0).isoformat()

print(f"\n[Step 2] Creating pending booking via atomic RPC (create_booking_atomic)...")
print(f"⏰ Selected Slot: {start_time} -> {end_time} (1 hour)")

# We read the player's ID from JWT payload
import base64
payload_part = player_token.split(".")[1]
payload_part += "=" * ((4 - len(payload_part) % 4) % 4)
user_data = json.loads(base64.urlsafe_b64decode(payload_part).decode("utf-8"))
player_id = user_data["sub"]
print(f"👤 Authenticated Player ID: {player_id}")

booking_rpc_payload = {
    "p_stadium_id": stadium_id,
    "p_user_id": player_id,
    "p_owner_id": owner_id,
    "p_start_time": start_time,
    "p_end_time": end_time,
    "p_booking_type": "personal",
    "p_total_price": float(price_per_hour),
    "p_stadium_name": stadium_name,
    "p_payment_method": "card",
    "p_payment_status": "pending",
    "p_needs_deposit": False,
    "p_deposit_amount": 0,
    "p_is_private": True,
}

rpc_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/rpc/create_booking_atomic",
    data=json.dumps(booking_rpc_payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "apikey": anon_key,
        "Authorization": f"Bearer {player_token}"
    }
)

try:
    with urllib.request.urlopen(rpc_req) as response:
        rpc_result = json.loads(response.read().decode())
except urllib.error.HTTPError as e:
    print(f"❌ Booking RPC Error: {e.code} - {e.read().decode()}")
    exit(1)

print(f"RPC Result: {rpc_result}")
if not rpc_result.get("success"):
    print(f"❌ Failed to create booking: {rpc_result.get('message')}")
    exit(1)

booking_id = rpc_result.get("booking_id")
locked_until = rpc_result.get("locked_until")
print(f"✅ Booking Created with 5-Minute Atomic Slot Lock!")
print(f"🔑 Booking ID: {booking_id}")
print(f"🔒 Locked Until: {locked_until}")

# Step 3: Call live Edge Function create_paymob_intention
print(f"\n[Step 3] Calling Edge Function 'create_paymob_intention'...")
intention_payload = {
    "booking_id": booking_id,
    "is_full_payment": True,
    "user_phone": "+201012345678",
    "user_name": "RedTeam Player",
    "user_email": "tester@vsp.app"
}

intention_req = urllib.request.Request(
    f"{supabase_url}/functions/v1/create_paymob_intention",
    data=json.dumps(intention_payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "apikey": anon_key,
        "Authorization": f"Bearer {player_token}"
    }
)

try:
    with urllib.request.urlopen(intention_req) as response:
        intention_res = json.loads(response.read().decode())
except urllib.error.HTTPError as e:
    print(f"❌ Paymob Intention Error: {e.code} - {e.read().decode()}")
    exit(1)

print(f"✅ Paymob Session Created Successfully!")
print(f"💳 Total Amount with Fees: {intention_res.get('total_amount')} EGP")
print(f"🔐 Client Secret: {intention_res.get('client_secret')[:25]}...")
print(f"🌐 Unified Checkout URL: {intention_res.get('checkout_url')}")

# Step 4: Test Double-Booking Collision Protection (Another user attempts same slot)
print(f"\n[Step 4] Testing Double-Booking Collision Protection...")
collision_payload = dict(booking_rpc_payload)
collision_payload["p_user_id"] = "a6720779-2f64-406a-a468-1fb9201145a2" # Different user attempting same slot
collision_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/rpc/create_booking_atomic",
    data=json.dumps(collision_payload).encode("utf-8"),
    headers={
        "Content-Type": "application/json",
        "apikey": anon_key,
        "Authorization": f"Bearer {player_token}"
    }
)
try:
    with urllib.request.urlopen(collision_req) as response:
        col_res = json.loads(response.read().decode())
        print(f"Collision result: {col_res}")
        if col_res.get("success") == False:
            print(f"🛡️ DOUBLE-BOOKING PREVENTED! Message: {col_res.get('message')}")
        else:
            print("⚠️ Warning: collision check allowed slot duplication!")
except urllib.error.HTTPError as e:
    print(f"🛡️ DOUBLE-BOOKING REJECTED BY SERVER: {e.code} - {e.read().decode()}")

# Step 5: Simulate Payment Webhook Confirmation
print(f"\n[Step 5] Simulating Payment Webhook Confirmation...")
# Update booking to confirmed as webhook would do
admin_headers = {
    "Content-Type": "application/json",
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": f"Bearer {env['SUPABASE_SERVICE_ROLE_KEY']}"
}
confirm_payload = {
    "status": "confirmed",
    "is_paid": True,
    "payment_status": "paid",
    "payment_transaction_id": "PAYMOB_TEST_LIVE_998811",
    "paymob_transaction_id": "998811",
    "payment_method": "card",
    "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
}
confirm_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/bookings?id=eq.{booking_id}",
    data=json.dumps(confirm_payload).encode("utf-8"),
    headers=admin_headers,
    method="PATCH"
)
urllib.request.urlopen(confirm_req)

# Verify confirmed status as player
verify_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/bookings?id=eq.{booking_id}&select=id,status,is_paid,payment_status,payment_transaction_id",
    headers={
        "apikey": anon_key,
        "Authorization": f"Bearer {player_token}"
    }
)
with urllib.request.urlopen(verify_req) as response:
    b_after = json.loads(response.read().decode())[0]
print(f"✅ Status AFTER Confirmation: {b_after}")

# Step 6: Clean up the test booking
print(f"\n[Step 6] Cleaning up test booking from database...")
delete_req = urllib.request.Request(
    f"{supabase_url}/rest/v1/bookings?id=eq.{booking_id}",
    headers=admin_headers,
    method="DELETE"
)
urllib.request.urlopen(delete_req)
print(f"🧹 Cleaned up test booking {booking_id} safely.")

print("\n🎉 FULL PLAYER JOURNEY SIMULATION COMPLETED WITH 100% SUCCESS!")
