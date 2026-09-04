import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode("utf-8"))
    b_props = spec.get("definitions", {}).get("bookings", {}).get("properties", {})
    print(f"Bookings Table Columns ({len(b_props)}):")
    for col, details in sorted(b_props.items()):
        print(f"  - {col}: {details.get('type')} (format: {details.get('format', 'none')})")
