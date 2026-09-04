import urllib.request, json

with open("env.json", "r") as f:
    env = json.load(f)

url = env["SUPABASE_URL"] + "/rest/v1/"
headers = {
    "apikey": env["SUPABASE_SERVICE_ROLE_KEY"],
    "Authorization": "Bearer " + env["SUPABASE_SERVICE_ROLE_KEY"],
}
req = urllib.request.Request(url, headers=headers)
try:
    with urllib.request.urlopen(req) as resp:
        spec = json.loads(resp.read().decode("utf-8"))
        definitions = spec.get("definitions", {})
        paths = spec.get("paths", {})
        print(f"OpenAPI Spec loaded successfully!")
        print(f"Total Database Tables/Views: {len(definitions)}")
        
        tables = sorted(definitions.keys())
        print("\n=== ALL DATABASE TABLES & VIEWS ===")
        for t in tables:
            props = definitions[t].get("properties", {})
            print(f"  📁 {t} ({len(props)} columns)")

        print("\n=== ALL RPC FUNCTIONS EXPOSED ===")
        rpc_paths = sorted([p.replace("/rpc/", "") for p in paths.keys() if p.startswith("/rpc/")])
        print(f"Total RPCs: {len(rpc_paths)}")
        for rpc in rpc_paths:
            print(f"  ⚡ {rpc}")

except Exception as e:
    print("Error:", e)
