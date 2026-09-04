import json

with open('supabase/functions_audit_phase1_report.json', 'r', encoding='utf-8') as f:
    funcs = json.load(f)

targets = [
    'admin_approve_owner_atomic',
    'admin_record_payout_settlement_atomic',
    'admin_resolve_dispute_atomic',
    'admin_upgrade_owner_subscription_atomic',
    'approve_payout_settlement_atomic',
    'request_owner_payout_settlement_atomic',
    'cancel_booking_with_refund_atomic',
    'confirm_cash_booking_atomic',
    'create_booking_atomic',
    'delete_user_permanently',
    'owner_lock_slot_atomic',
    'prevent_unauthorized_role_change',
    'set_user_role_on_signup'
]

for fn in funcs:
    if fn['name'] in targets:
        print('='*70)
        print(f"FUNCTION: {fn['name']}({fn['args']})")
        print('='*70)
        lines = fn['definition'].split('\n')
        for i, line in enumerate(lines[:50]):
            print(f"{i+1:3d}: {line}")
        if len(lines) > 50:
            print(f"... ({len(lines)-50} more lines)")
        print()
