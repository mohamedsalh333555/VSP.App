import urllib.request
import json
import os

def run_query(sql):
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
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

print("Auditing all functions executable by 'anon'...")

functions = run_query("""
    SELECT 
        p.proname,
        p.oid,
        pg_get_function_identity_arguments(p.oid) as args,
        p.prosecdef as is_security_definer,
        pg_get_functiondef(p.oid) as definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND has_function_privilege('anon', p.oid, 'EXECUTE')
    ORDER BY p.proname;
""")

print(f"Retrieved {len(functions)} functions.")

# Categorize
critical_financial_admin = [
    'admin_approve_owner_atomic',
    'admin_record_payout_settlement_atomic',
    'admin_resolve_dispute_atomic',
    'admin_upgrade_owner_subscription_atomic',
    'approve_payout_settlement_atomic',
    'request_owner_payout_settlement_atomic',
    'delete_user_permanently',
    'set_user_role_on_signup',
    'prevent_unauthorized_role_change',
    'create_owner_on_behalf',
    'admin_register_owner_on_behalf'
]

high_booking_payment = [
    'create_booking_atomic',
    'cancel_booking_with_refund_atomic',
    'confirm_cash_booking_atomic',
    'owner_lock_slot_atomic',
    'create_tournament_order_atomic',
    'paymob_refund_booking_atomic',
    'process_booking_payment_and_unlock_atomic'
]

results = []

for fn in functions:
    name = fn['proname']
    args = fn['args']
    secdef = fn['is_security_definer']
    defn = fn['definition']
    
    # Checks
    has_auth_uid = 'auth.uid()' in defn or 'auth.uid ()' in defn
    has_role_check = any(term in defn for term in ["role = 'admin'", "role = 'owner'", "role = 'co_founder'", "auth.jwt()", "'admin'::text", "admin_role", "is_admin"])
    has_null_check = 'auth.uid() is null' in defn.lower()
    
    # Priority
    if name in critical_financial_admin or any(name.startswith(p) for p in ['admin_', 'payout_', 'approve_payout', 'delete_user']):
        category = "CRITICAL (Financial / Admin / Role)"
    elif name in high_booking_payment or any(term in name for term in ['booking', 'tournament_order', 'refund', 'payment']):
        category = "HIGH (Booking / Payment)"
    else:
        category = "MEDIUM (Game / Match / Chat / Utility)"
        
    results.append({
        'name': name,
        'args': args,
        'secdef': secdef,
        'category': category,
        'has_auth_uid': has_auth_uid,
        'has_role_check': has_role_check,
        'has_null_check': has_null_check,
        'definition': defn
    })

# Save report
with open("supabase/functions_audit_phase1_report.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2)

print("\n=== AUDIT RESULTS SUMMARY ===")
cat_counts = {}
for r in results:
    cat_counts[r['category']] = cat_counts.get(r['category'], 0) + 1

for cat, count in cat_counts.items():
    print(f"{cat}: {count} functions")

print("\nAnalyzing Critical & High priority functions:")
for r in results:
    if "CRITICAL" in r['category'] or "HIGH" in r['category']:
        status = []
        if r['has_auth_uid']: status.append("auth.uid()")
        if r['has_role_check']: status.append("role_check")
        if r['has_null_check']: status.append("null_raise")
        status_str = ", ".join(status) if status else "NO AUTH CHECKS FOUND!"
        print(f"[{r['category'][:4]}] {r['name']}({r['args']}): {status_str}")
