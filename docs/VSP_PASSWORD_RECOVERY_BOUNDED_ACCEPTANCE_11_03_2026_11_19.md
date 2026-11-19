# VSP — 11.03 Password recovery, bounded Flutter acceptance

**19 Nov 2026 — acceptance scope: local Flutter widgets and fake AuthProvider only.**

## Evidence

- [VSP Password Recovery Privacy CI — 44 tests passed](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44486325222), at SHA c9abe473f5ce716f8bca5cec2af271c6dd6b1387, with Flutter analyze success.
- Existing password-reset dialog tests validate invalid email, normalized email submission, neutral acknowledgement on success/unknown/exception, duplicate-pending behavior and cancellation/back navigation (previous 11.08 privacy acceptance remains independent).
- Six new SetNewPasswordScreen widget scenarios prove short/mismatched passwords are blocked, an original recovery session can complete and sign out, a switched account is never logged out during an unfinished update or after the confirmation delay, and internal SDK exceptions do not show in Arabic copy.
- Five new PasswordRecoverySessionGuard tests independently cover same identity, changed identity after asynchronous delay, logout, disposed provider and blank identity.

## Deliberately not accepted

- A real Supabase recovery link, inbox delivery, TTL/expiry, actual recovery JWT, one-time use, an independently authenticated two-account session, request throttling, Android testing and production deployment.
- Existing 11.04, 11.05, 11.06, 11.07, 79 and SEC-01 still own those outcomes. No evidence of real credential reset was generated.

Only task **11.03** changes from open to accepted. Total **640 / 344 accepted / 296 open (53.75%)**. No main merge, production reads/writes or payment transactions.
