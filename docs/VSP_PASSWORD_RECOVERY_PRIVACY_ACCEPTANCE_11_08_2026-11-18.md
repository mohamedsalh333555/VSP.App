# VSP — Password recovery cannot reveal whether an email exists (11.08)

**18 November 2026 · `uxlp-44-implementation`**

**Exact tested source SHA:** [d6579b1](https://github.com/mohamedsalh333555/VSP.App/commit/d6579b12a0b93d7ac834048a80c15f5b9261e689).

**Passing [VSP Password Recovery Privacy CI](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44206384812):** Flutter Analyze plus six focused Flutter tests, including widget-driven submissions for successful requests, unsuccessful/unknown addresses, thrown provider exceptions, Arabic feedback, invalid input and invariant wording.

## Narrow acceptance: 11.08 — Prevent client-side account enumeration during recovery

- The password recovery dialog now always presents the **same neutral acknowledgement** to a valid email submission, regardless of whether the mocked backend returns `true`, `false` or throws an exception. No raw provider error or email-registration flag reaches the user-facing message.
- A neutral Arabic/English `PasswordResetPrivacyMessage` is a single source for the acknowledgement. It does not assert that a message was definitely sent or that an email is registered.
- Invalid email input is rejected before any reset request. The dialog opens from the originating screen and shows the acknowledgement through that screen's still-mounted context after closing.
- **Real defect found and fixed during widget tests:** the old `TextEditingController` was disposed when the `showDialog` Future completed, potentially **before** the reverse close transition stopped using it, triggering a `TextEditingController was used after being disposed` Flutter exception. The new `_ForgotPasswordDialogContent` is a stateful dialog widget that owns and disposes its controller only when unmounted. Widget tests now verify the dialog's full submit/close transition in both languages.
- The shared toast's existing three-second auto-dismiss timer is consumed during tests; production timing is unchanged.

## Explicit limits

**Client-only privacy and lifecycle evidence.** The test does not establish that live Supabase Auth reset responses, response timing, throttling, rate limits or SMTP delivery are enumeration-resistant. Staging tests for backend behavior and endpoint rate limits remain open under SEC-01/11.06. No real email sent, no live auth/user lookup and no changes to RLS or payment systems.

**Accounting:** 633 original tasks / **306 accepted** / **327 open** (**48.34%**). +1 pre-existing ID, no newly added tasks, no `main` merge or production deployment.
