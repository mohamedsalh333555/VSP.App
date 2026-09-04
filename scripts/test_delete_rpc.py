import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/rpc/delete_user_permanently"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
    "Content-Type": "application/json",
}
payload = json.dumps({"p_user_id": "bf032a2b-ade2-4c20-be44-118205e4e8ca"}).encode("utf-8")
req = urllib.request.Request(url, data=payload, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        print("RPC Result:", resp.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    print("HTTP Error:", e.code, e.read().decode("utf-8"))
except Exception as e:
    print("Error:", e)
