# Staging: 1v1 admin status, prize and standings guards

Date 2026-11-07. Staging `vtwgqyxglevcsxwdmhop`. Related issue #38 and 80-item tracker item 77.

## Applied migration

`secure_1v1_admin_status_prize_and_standings_guards` replaces `current_user != 'postgres'` exception in authorization branches of three SECURITY DEFINER functions:

- `public.admin_update_1v1_tournament_status(uuid,text,uuid)`
- `public.mark_1v1_prize_delivered_atomic(uuid,text)`
- `public.publish_1v1_final_standings_atomic(uuid)`

Only the guard condition was replaced; the original admin role checks remain. The existing explicit `service_role` path remains.

## Negative test results

All tests used `SET LOCAL ROLE authenticated` without JWT and placeholder UUIDs, within transactions rolled back:

- Tournament status: SQL exception `يجب تسجيل الدخول لتنفيذ هذه العملية` (login required), thrown at authorization guard before tournament lookup.
- Prize delivery: `{success:false,error:'غير مصرح: فقط الأدمن يمكنه توثيق تسليم الجوائز.'}`.
- Final standings publication: `{success:false,error:'غير مصرح: فقط الأدمن يمكنه اعتماد ونشر النتائج.'}`.

These are role-level negative tests, **not** real JWT positive or cross-account E2E tests. Do not close item 77. Production and main unchanged.

## Cumulative count

Nine privileged functions with targeted caller authorization fixes across recent staging batches: booking cancellation, 1v1 payment confirmation, 1v1 finalization, owner cash debt settlement, rate limiter, booking QR token, 1v1 tournament status, 1v1 prize delivery, 1v1 standings publication.
