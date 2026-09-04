import urllib.request, urllib.error, json

with open("env.json", "r") as f:
    env = json.load(f)

anon_key = env["SUPABASE_ANON_KEY"]
service_key = env["SUPABASE_SERVICE_ROLE_KEY"]
url_base = env["SUPABASE_URL"] + "/rest/v1"

# Get all table names using service key
req = urllib.request.Request(url_base + "/", headers={"apikey": service_key, "Authorization": f"Bearer {service_key}"})
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode("utf-8"))
    tables = sorted(spec.get("definitions", {}).keys())

print("=" * 80)
print(f"🔒 RLS SECURITY AUDIT: TESTING ANONYMOUS ACCESS TO ALL {len(tables)} TABLES")
print("=" * 80)

leaks = []
protected = []
errors = []

for table in tables:
    url = f"{url_base}/{table}?limit=1"
    req = urllib.request.Request(url, headers={
        "apikey": anon_key,
        "Authorization": f"Bearer {anon_key}",
    })
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, list) and len(data) > 0:
                print(f"  ⚠️  LEAK/PUBLIC READ: '{table}' allows anonymous reading! (1+ rows returned)")
                leaks.append((table, "READ_OPEN", f"{len(data)} rows returned"))
            else:
                print(f"  ℹ️  OPEN BUT EMPTY: '{table}' allows query but returned 0 rows (RLS might filter or table empty)")
                leaks.append((table, "EMPTY_OR_FILTERED", "0 rows"))
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            print(f"  🛡️  SECURE (HTTP {e.code}): '{table}' RLS strictly blocked anonymous read")
            protected.append(table)
        else:
            print(f"  ❓  HTTP {e.code}: '{table}' -> {e.read().decode('utf-8')[:60]}")
            errors.append((table, e.code))
    except Exception as e:
        errors.append((table, str(e)))

print("\n" + "=" * 80)
print(f"SUMMARY: {len(protected)} strictly blocked | {len(leaks)} queryable anonymously")
print("=" * 80)
