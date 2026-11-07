# Staging: 1v1 cancellation, challenge booking and owner AI caller guards

2026-11-07 | Staging `vtwgqyxglevcsxwdmhop` | Issue #38 | Tracker #77

Migration `secure_1v1_cancel_challenge_and_owner_ai_definer_guards` surgically removes `current_user`-based caller exceptions from three SECURITY DEFINER RPCs:

1. `cancel_1v1_tournament_with_refund_requests(uuid,text)`: authorization now checks caller role using `coalesce(v_role,'')` and JWT service role, avoiding NULL role bypass.
2. `create_challenge_booking_atomic(text,text,timestamptz,timestamptz,text,boolean,text)`: login check now requires auth.uid unless service JWT role.
3. `get_owner_ai_stadium_comparison(uuid,text)`: both authentication and owner/admin authorization guards now check JWT service role rather than SECURITY DEFINER owner current_user.

Negative `SET LOCAL ROLE authenticated` without JWT, within rolled-back transactions, returned respectively `يجب تسجيل الدخول`, `AUTH_REQUIRED`, and `Authentication required`. These are not full real-JWT or cross-account tests. No production or main modifications. Cumulative targeted SECURITY DEFINER caller guard fixes: **16 functions**. Tracker #77 remains open until complete RPC review and positive/cross-account tests.
