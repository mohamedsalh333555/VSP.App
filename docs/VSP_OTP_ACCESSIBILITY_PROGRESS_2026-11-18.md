# VSP — OTP verification accessibility improvement (05.02, scoped)

**18 November 2026 | branch `uxlp-44-implementation` | no production deployment.**

## Change

- The six verification-code fields now expose distinct one-based accessibility labels, in Arabic and English, to identify the current digit and the six-digit total.
- The existing OTP text-field behavior (paste, input formatters, focus and keyboard handling) remains intact; the visual layout is unchanged.
- Verification errors are exposed as a semantics live region so assistive technologies can be notified when the error text appears.
- Added Flutter widget tests for the first/last input in both languages, including unchanged numeric editing, plus a narrow CI gate.

## Acceptance boundaries

This is a **partial implementation of 05.02**, not completion of screen-reader labels across all VSP pages. The task counter remains unchanged until the wider requirement is proven. A passing widget test is not a substitute for TalkBack/VoiceOver device walkthroughs, actual error announcements, keyboard scaling, OTP delivery, or real-account verification. No Supabase, Paymob, owner balances, `main` merge, or APK changes.
