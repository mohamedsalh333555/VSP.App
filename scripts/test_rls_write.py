import urllib.request, urllib.error, json

with open("env.json", "r") as f:
    env = json.load(f)

anon_key = env["SUPABASE_ANON_KEY"]
url_base = env["SUPABASE_URL"] + "/rest/v1"

test_targets = [
    ("users", {"id": "00000000-0000-0000-0000-000000000001", "email": "hacked@test.com", "role": "admin"}),
    ("financial_audit_logs", {"action": "HACK", "amount": 1000000}),
    ("payout_settlements", {"owner_id": "00000000-0000-0000-0000-000000000001", "amount": 99999}),
    ("webhook_logs", {"event": "FAKE_PAYMENT", "status": "success"}),
    ("admin_pending_refunds", {"amount": 5000}),
]

print("🔒 TESTING ANONYMOUS WRITE ATTACKS (RLS WRITE SECURITY):")
for table, payload in test_targets:
    url = f"{url_base}/{table}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            print(f"  🚨 CRITICAL VULNERABILITY! Anonymous INSERT succeeded on '{table}'! (HTTP {resp.status})")
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            print(f"  ✅ SECURE: Anonymous INSERT blocked on '{table}' (HTTP {e.code})")
        else:
            print(f"  ⚠️  HTTP {e.code} on '{table}': {e.read().decode('utf-8')[:60]}")
    except Exception as e:
        print(f"  Error on '{table}': {e}")
