import urllib.request
import json

with open("env.json", "r") as f:
    env = json.load(f)

token = env["SUPABASE_MANAGEMENT_KEY"]
url = "https://api.supabase.com/v1/projects/mktqkddbcddrxjxabdua/database/query"
sql = "SELECT proname, prosrc FROM pg_proc WHERE proname IN ('join_championship_atomic', 'crown_tournament_champion_atomic');"

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
    print("LIVE PG_PROC SOURCE FOR TOURNAMENT FUNCTIONS:")
    print("=" * 70)
    for row in data:
        print(f"✔️ Function: {row['proname']}")
        print("-" * 50)
        lines = row["prosrc"].split("\n")
        for l in lines[:30]:
            print(l)
        print("=" * 70)
