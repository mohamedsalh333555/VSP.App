import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"
sql = "SELECT prosrc FROM pg_proc WHERE proname = 'join_championship_atomic';"

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

with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read())
    lines = data[0]["prosrc"].split("\n")
    print("JOIN_CHAMPIONSHIP_ATOMIC PAYMENT LOGIC IN LIVE DB:")
    print("-" * 60)
    for l in lines[30:70]:
        print(l)
