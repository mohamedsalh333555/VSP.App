import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/users?email=eq.dfasddas322@gmail.com"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    users = json.loads(resp.read().decode("utf-8"))
    if users:
        uid = users[0]["id"]
        print(f"Purging ghost user dfasddas322: {uid}")
        del_url = env["SUPABASE_URL"] + "/rest/v1/rpc/delete_user_permanently"
        payload = json.dumps({"p_user_id": uid}).encode("utf-8")
        del_req = urllib.request.Request(del_url, data=payload, headers={
            "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
            "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
            "Content-Type": "application/json",
        })
        with urllib.request.urlopen(del_req) as del_resp:
            print("Purged:", del_resp.read().decode("utf-8"))
