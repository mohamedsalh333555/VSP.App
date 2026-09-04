import json

with open('supabase/functions_audit_phase1_report.json', 'r', encoding='utf-8') as f:
    funcs = json.load(f)

print(f"Total analyzed: {len(funcs)}")

# Categorize and find any functions lacking auth.uid() or role check
missing_checks = []
protected = []

for fn in funcs:
    name = fn['name']
    defn = fn['definition']
    category = fn['category']
    secdef = fn['secdef']
    
    # Is it a trigger function?
    is_trigger = 'RETURNS trigger' in defn
    
    has_auth_uid = 'auth.uid()' in defn or 'auth.uid ()' in defn
    has_role_check = any(term in defn for term in ["role = 'admin'", "role = 'owner'", "role = 'co_founder'", "auth.jwt()", "'admin'::text", "admin_role", "is_admin", "v_caller_role"])
    
    status = "PROTECTED" if (has_auth_uid or has_role_check or is_trigger) else "UNCHECKED"
    
    info = {
        'name': name,
        'args': fn['args'],
        'category': category,
        'secdef': secdef,
        'is_trigger': is_trigger,
        'has_auth_uid': has_auth_uid,
        'has_role_check': has_role_check,
        'status': status
    }
    
    if status == "UNCHECKED":
        missing_checks.append(info)
    else:
        protected.append(info)

print(f"Functions with internal auth/role/trigger protection: {len(protected)}")
print(f"Functions without explicit auth checks: {len(missing_checks)}")

print("\n--- FUNCTIONS WITHOUT EXPLICIT AUTH CHECKS ---")
for m in missing_checks:
    print(f" - [{m['category'][:4]}] {m['name']}({m['args']}) | SecDef: {m['secdef']}")
