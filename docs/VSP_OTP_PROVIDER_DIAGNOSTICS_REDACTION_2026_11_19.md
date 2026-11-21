# OTP privacy redaction in Flutter — 19 November 2026

On the developer branch, VerifyEmailScreen no longer prints raw verification, resend, or secure-storage cleanup exception details or stack traces. False OTP results no longer show auth.errorMessage, which may contain provider information. Instead the UI uses the existing generic Arabic/English invalid/expired OTP text.

The focused OTP workflow now analyzes and tests three source-privacy regressions alongside the existing accessibility widget tests. These are scoped client checks, not hosted Supabase authorization/rate-limit or email delivery tests.

Task counter remains 640 total / 343 accepted / 297 open. No production changes, payments, deployment, APK or main merge.
