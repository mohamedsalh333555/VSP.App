import urllib.request
import urllib.error
import json
import sys
import os

def load_env():
    with open("env.json", "r", encoding="utf-8") as f:
        return json.load(f)

def run_sql(token: str, project_ref: str, sql: str) -> dict:
    url = f"https://api.supabase.com/v1/projects/{project_ref}/database/query"
    payload = json.dumps({"query": sql}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return {"status": resp.status, "body": json.loads(resp.read())}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        return {"status": e.code, "error": body}
    except Exception as e:
        return {"status": -1, "error": str(e)}

def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/execute_sql_migration.py <path_to_sql_file>")
        sys.exit(1)

    sql_file = sys.argv[1]
    if not os.path.exists(sql_file):
        print(f"Error: file '{sql_file}' not found.")
        sys.exit(1)

    with open(sql_file, "r", encoding="utf-8") as f:
        sql_content = f.read()

    env = load_env()
    token = env.get("SUPABASE_MANAGEMENT_KEY")
    project_ref = "mktqkddbcddrxjxabdua"

    print("=" * 80)
    print(f"🚀 EXECUTING MIGRATION ON SUPABASE LIVE DATABASE: {project_ref}")
    print(f"📄 Target File: {sql_file}")
    print("=" * 80)

    # 1. Execute Migration
    res = run_sql(token, project_ref, sql_content)
    status = res.get("status", -1)

    if status in (200, 201):
        print("✅ MIGRATION EXECUTED SUCCESSFULLY WITHOUT ERRORS!")
        print("HTTP Status:", status)
    else:
        print(f"❌ MIGRATION FAILED (HTTP {status}):")
        print(res.get("error", res))
        sys.exit(1)

    # 2. Verification Query: Check pg_proc for the updated functions
    verify_sql = """
    SELECT 
        proname, 
        pg_get_function_arguments(oid) as args,
        prosecdef as is_security_definer
    FROM pg_proc 
    WHERE proname IN (
        'confirm_cash_booking_atomic',
        'confirm_tournament_order_atomic',
        'delete_user_permanently',
        'record_match_result_and_advance_atomic',
        'submit_stadium_review_atomic'
    )
    ORDER BY proname;
    """

    print("\n" + "=" * 80)
    print("🔍 RUNNING VERIFICATION QUERY ON PG_PROC TO CONFIRM RPC REGISTRATION:")
    print("=" * 80)

    verify_res = run_sql(token, project_ref, verify_sql)
    if verify_res.get("status") in (200, 201):
        rows = verify_res.get("body", [])
        for r in rows:
            print(f"✔️ Function: {r.get('proname')}")
            print(f"   Args:     {r.get('args')}")
            print(f"   SecDef:   {r.get('is_security_definer')}")
            print("-" * 50)
        print(f"\n🎉 Total verified functions in live DB: {len(rows)}/5")
    else:
        print("Verification query error:", verify_res)

if __name__ == "__main__":
    main()
