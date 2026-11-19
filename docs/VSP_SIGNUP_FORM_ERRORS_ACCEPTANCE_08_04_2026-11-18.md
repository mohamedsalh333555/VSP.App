# VSP — Registration form input and error handling (08.04)

**18 November 2026 · Branch `uxlp-44-implementation`**

**Exact tested SHA:** [70964e7](https://github.com/mohamedsalh333555/VSP.App/commit/70964e7ee9e431f13011ee3d43c71dd2678ad525). **Passing [Signup Input and Error Validation CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44204735513)**: scoped Flutter Analyze plus pre-existing signup-unit and component-widget tests and new `test/unit/signup_invalid_email_contract_test.dart`.

## Narrow acceptance: 08.04 — Improve registration form errors

- `SignupValidationService.validateForm` now rejects malformed/whitespace-containing email syntax **before any phone-uniqueness request or account-creation API call**. An empty required email still receives the generic required-fields error, while a nonempty malformed email receives `SignupValidationError.invalidEmail`.
- The error maps to the existing, localized Arabic/English `AppLocalizations.invalidEmail` strings, and the signup screen already calls `getLocalizedErrorMessage` before initiating the request.
- New tests cover invalid formats (missing `@`, missing host or suffix, whitespace, multiple `@`, truncated suffix) and valid trimmed/case-insensitive, plus-tagged addresses. Existing tests verify the consent, name, date-of-birth/18+, Egypt mobile number, password match/length, success payload and component widgets.
- This improves **client form validation and actionable bilingual feedback**, not SMTP deliverability, ownership of an email, live backend registration errors, every owner onboarding form, signup rate limiting or live Android keyboard layout. Those remain separate tasks.

## Counters / deployment scope

**633 unique / 305 accepted / 328 open (48.18%)**. One pre-existing task accepted narrowly, zero new IDs. No DB writes, Supabase auth provisioning, production deployment, payments, APK or `main` merge.
