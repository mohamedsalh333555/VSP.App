import urllib.request
import json
import sys
import os

def apply_migration(file_path):
    print(f"Applying migration: {file_path}")
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        sys.exit(1)

    with open(file_path, "r", encoding="utf-8") as f:
        sql = f.read()

    with open("env.json", "r") as f:
        env = json.load(f)

    token = env["SUPABASE_MANAGEMENT_KEY"]
    project_ref = "mktqkddbcddrxjxabdua"
    url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"

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
            data = resp.read().decode("utf-8")
            print(f"Migration applied successfully! Response: {data[:100]}")
            return True
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        print(f"HTTP Error {e.code}: {error_body}")
        sys.exit(1)
    except Exception as e:
        print(f"Error applying migration: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        apply_migration(sys.argv[1])
    else:
        print("Usage: python apply_migration_runner.py <migration_file>")
