import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/users?select=id,name,email,role,is_registration_complete&limit=10"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        users = json.loads(resp.read().decode("utf-8"))
        print(f"Successfully fetched {len(users)} users using service role key!")
        for u in users:
            print(f" - {u.get('name')}: {u.get('email')} | role={u.get('role')} | complete={u.get('is_registration_complete')}")
except Exception as e:
    print("Error:", e)
