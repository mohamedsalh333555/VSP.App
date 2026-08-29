import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = "UPDATE public.users SET role = 'admin' WHERE id = 'b3fffb87-5709-49a4-9f05-e22111144f1e';"

payload = json.dumps({"query": sql}).encode("utf-8")
req = urllib.request.Request(
    url,
    data=payload,
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "Mozilla/5.0",
    },
    method="POST",
)

try:
    with urllib.request.urlopen(req) as resp:
        print("UPDATE RESPONSE:", resp.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("HTTP ERROR (EXPECTED):", e.read().decode('utf-8'))
