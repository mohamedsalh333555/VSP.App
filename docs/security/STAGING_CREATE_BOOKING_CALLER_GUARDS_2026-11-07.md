# Staging: create_booking_atomic caller guards

2026-11-07 | staging `vtwgqyxglevcsxwdmhop` | #77 / security issue #38

Applied migration `secure_create_booking_atomic_caller_guards` to the SECURITY DEFINER `public.create_booking_atomic` RPC (23 parameters). Replaced **two** `current_user NOT IN ('postgres','service_role')` caller bypasses with `coalesce(auth.role(),'') <> 'service_role'`: (1) mandatory login and (2) booking on behalf of another user.

Verification: in a transaction with `SET LOCAL ROLE authenticated` and no JWT, calling the RPC with synthetic identifiers returned `{success:false,message:'يجب تسجيل الدخول أولاً.'}`. Transaction rolled back. This is a negative guard test, **not** real authenticated-user E2E or proof of complete booking correctness.

Total targeted SECURITY DEFINER guard fixes: **17 functions**. Production unchanged; #77 open pending real JWT positive/cross-account tests, remaining RPC review and Flutter/Android CI.
