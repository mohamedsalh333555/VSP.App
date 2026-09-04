import urllib.request, urllib.error, json

with open("env.json", "r") as f:
    env = json.load(f)

service_key = env["SUPABASE_SERVICE_ROLE_KEY"]
url_base = env["SUPABASE_URL"] + "/rest/v1"

req = urllib.request.Request(url_base + "/", headers={"apikey": service_key, "Authorization": f"Bearer {service_key}"})
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode("utf-8"))
    tables = sorted(spec.get("definitions", {}).keys())

print(f"{'TABLE NAME':<35} | {'COUNT':<10}")
print("-" * 50)

total_rows = 0
for table in tables:
    url = f"{url_base}/{table}?select=count"
    req = urllib.request.Request(url, headers={
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
        "Range-Unit": "items",
        "Range": "0-0",
        "Prefer": "count=exact"
    })
    try:
        with urllib.request.urlopen(req) as resp:
            content_range = resp.headers.get("Content-Range", "")
            count = content_range.split("/")[-1] if "/" in content_range else "0"
            print(f"{table:<35} | {count:<10}")
            if count.isdigit():
                total_rows += int(count)
    except Exception as e:
        print(f"{table:<35} | ERROR: {str(e)[:20]}")

print("-" * 50)
print(f"TOTAL ROWS ACROSS ALL TABLES: {total_rows}")
