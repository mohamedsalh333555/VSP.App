# Staging owner booking and subscription caller guards

2026-11-07 | staging `vtwgqyxglevcsxwdmhop` | tracker #77 | security issue #38

Migration: `secure_owner_booking_cash_and_subscription_definer_guards`.

Fixed four SECURITY DEFINER functions that previously allowed their owner `current_user` to bypass checks intended for the actual caller:

- `confirm_cash_booking_atomic(uuid,uuid,numeric,numeric)` — caller must own booking or have admin role, unless JWT service role.
- `owner_cancel_manual_booking_atomic(uuid,uuid,boolean)` — same owner/admin check.
- `owner_record_no_show_atomic(uuid,uuid,text)` — same owner/admin check.
- `admin_set_owner_subscription_atomic(uuid,text,integer)` — admin/co-founder check unless JWT service role.

**Verification**: catalog shows no `current_user` remaining in any of these definitions, including the 3-argument cash wrapper. Negative role tests used `BEGIN; SET LOCAL ROLE authenticated; ... ROLLBACK;` with no JWT. For the three booking operations, a real staging booking with its correct owner ID was used, and all returned `{success:false}` with authorization-denied messages. Subscription modification raised `Unauthorized: Only admins can alter owner subscriptions` before any modification. No persistent test changes.

**Limits**: real owner/admin JWT positive tests, cross-account JWT negative tests, and full financial reconciliation remain outstanding. Do not close item #77. This brings the targeted guard fixes to 13 SECURITY DEFINER functions in recent staging batches. Production and main unchanged.
