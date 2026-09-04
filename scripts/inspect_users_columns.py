import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

# Query column names of users table via REST
url = env["SUPABASE_URL"] + "/rest/v1/users?limit=1"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode("utf-8"))
    if data:
        print("COLUMNS IN public.users:")
        for col in sorted(data[0].keys()):
            val = data[0][col]
            print(f"  - {col}: type={type(val).__name__} (example: {repr(val)[:40]})")
