import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/storage/v1/bucket"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        buckets = json.loads(resp.read().decode("utf-8"))
        print(f"STORAGE BUCKETS ({len(buckets)}):")
        for b in buckets:
            print(f"  📦 {b.get('id')} | public: {b.get('public')} | size_limit: {b.get('file_size_limit')} | allowed_mime: {b.get('allowed_mime_types')}")
except Exception as e:
    print("Bucket error:", e)
