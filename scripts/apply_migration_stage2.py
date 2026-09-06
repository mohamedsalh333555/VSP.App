import json
import sys
from db_client import run_sql

with open('supabase/migrations/20260906_harden_tournament_atomic_refund_and_prize_pool.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

print("Applying Stage 2 migration...")
res = run_sql(sql)
print("Migration applied successfully! Result:", res)

# Verify functions on live DB
check_sql = """
SELECT proname, pronargs, proargnames 
FROM pg_proc 
WHERE proname IN ('confirm_tournament_order_atomic', 'record_tournament_refund_status_atomic')
ORDER BY proname;
"""
verify_res = run_sql(check_sql)
print("Functions verified on live DB:")
print(json.dumps(verify_res, indent=2, ensure_ascii=False))
