import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/users?email=eq.mohamedsalh333555@gmail.com"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    users = json.loads(resp.read().decode("utf-8"))
    print(json.dumps(users, indent=2))
