# VSP — Profile photo failure, retry and discard (task 12.06, 19 November 2026)

**Branch:** `uxlp-44-implementation`, PR #35 Draft. **Bounded acceptance:** Flutter widget test and UI error handling only, not actual Supabase Storage upload or production/device verification.

## Delivered
- `EditProfileScreen` now catches image picker and compression/upload exceptions without showing private backend errors. After the text profile is persisted, an unsuccessful avatar save correctly says the text data was saved but the image was not. The selected image remains available for an explicit retry.
- A bilingual **Discard selected photo / إلغاء اختيار الصورة** action lets the user roll back the uncommitted image selection. Image-picker responses are tied to the originating account ID and ignored after a switch.
- The profile editor now supports injected image-picker, compressor and preview callbacks for deterministic UI tests. In production, the normal image-picker/compression/photo rendering paths remain the defaults.
- Ten new focused widget cases (five each in Arabic and English): picker throws; compression throws; server-photo update returns false; server-photo update throws; discard-before-save; recovery/retry succeeds after failures. Mocked profile repository, image picker and compressor; no external data mutation.
- The test fixture uses synchronous file creation/cleanup because Flutter widget tests run under FakeAsync; this avoids blocking IO inside the test harness.

## Passing proof
- [VSP Profile Edit Position and Validation Regression #44443912415 — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44443912415) at commit `c8d77b68d249fd69a2bb3c827108c4e380472c93`: Flutter Analyze plus **29 tests passed**, including all ten new Arabic/English photo failure/discard/retry cases.
- Source changes were committed on `uxlp-44-implementation` in `f98312e`, `dbbe03e`, `7eb7615`, `2bbeb3f`, `643af8f`, `98cc719`; latest fixture stabilization in `c8d77b6`.
- The previous broad Flutter CI issue requiring the literal `verifiedStagePoints(rows)` call was separately corrected in `decc6dd` to assert the live weight-limited score rendering. Full-suite green remains a **separate** release gate.

## Completion boundary
**12.06** verifies client photo-upload failure, partial-save explanation, retry and rollback of unsaved selection. **12.03** (real avatar upload/persistence), **12.04** (privacy/server authorization), and **12.07** (two-device conflict) remain open. No Supabase/Paymob/production schema mutation or `main` merge, no APK.

## Count
From **640 total / 337 accepted / 303 open** to **640 / 338 accepted / 302 open = 52.81%**.
