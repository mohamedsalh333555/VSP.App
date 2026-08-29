import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"

sql = "SELECT id, name, captain_id, points, wins, championships_won FROM public.teams;"

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
    print("TEAMS IN LIVE DATABASE:")
    print("=" * 70)
    for t in data:
        print(f"🛡️ Name: {t.get('name')} | Captain: {t.get('captain_id')} | Points: {t.get('points')} | Trophies: {t.get('championships_won')}")
    print(f"Total teams: {len(data)}")
