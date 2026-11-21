# VSP — Scoped acceptance: motion preferences, role choice and small-screen auth UX

**18 November 2026 — Branch `uxlp-44-implementation` — No production/main changes**

**Exact UI code tested:** [`4d25b675`](https://github.com/mohamedsalh333555/VSP.App/commit/4d25b67594c5c39e44157d2d7ad5d6c141ee2ce1)  
**Targeted Flutter analyze + 19 widget tests:** [SUCCESS, run 44217138909](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44217138909).

## Evidence and scoped task acceptances

| ID | Verified client behavior | Boundary of acceptance |
|---|---|---|
| 04.03 | Arabic direction in role selection and screen-reader role choice at 320dp/1.6x; distinct player/owner actions succeed | Only the authentication role selection, not all RTL app screens or Android screenshot audit |
| 05.04 | Login, create-account (player/owner), role selection and signup name fields render with 1.6x and 1.8x text scaling and remain accessible in widget tests | Other app features and physical-device TalkBack/VoiceOver still open |
| 06.02 | `VSPFadeInItem` stops staggering when reduced-motion is requested; shared terms checkbox and text-field status animations use zero duration; animated auth button remains fully scaled and tappable | Not a global audit of every app animation, nor proof of Android device setting behavior |
| 06.03 | Delayed/staggered auth sections show their full content immediately as the no-motion alternative, including when the preference changes during transition | Other animation alternatives, blinking effects and system accessibility tests remain open |
| 08.03 | Explicit player versus stadium owner choices in English/Arabic select independent account types; semantics includes readable labels/tap actions; switch-account link has a minimum target | Backend role authorization, provisioning and real OAuth are separate |
| 09.02 | Tested 320/360dp signup name fields, 320dp login and player/owner account-entry screens, with large text; fixed confirmed overflow issues | Not a full app-wide small-device sweep |
| 09.04 | Changed fixed social-login button height to minimum flexible height, made localized Google button text wrap, wrapped login section heading/divider, and reflowed create-account sign-in copy; final widget tests have no overflow | Actual on-device keyboard/landscape and every form remain pending |
| 09.07 | Verified login controls can be reached inside a 320dp viewport with simulated 260dp keyboard inset and 1.6x text, for both languages | Synthetic Flutter inset only; keyboard open/close hardware-device acceptance still open |

## Source changes
- `lib/shared/widgets/vsp_fade_in_item.dart`, `vsp_terms_checkbox.dart`, `custom_text_field.dart` — reduced motion visibility/transition timing.
- `lib/features/auth/screens/select_role_screen.dart` — screen-reader labeled role selection/switch account and 48dp switch-account target.
- `lib/features/auth/screens/create_account_screen.dart`, `login_screen.dart`, `signup_screen.dart` — responsive labels, row wrapping, flexible sign-in switch.
- `lib/features/auth/widgets/login_social_auth_row.dart`, `social_auth_buttons_row.dart`, `shared/widgets/social_auth_button.dart` — Google label wraps and button expands when large-text content requires it.
- New source-controlled tests for motion, role choice, RTL, signup name-field dimensions, login keyboard and both account-entry roles, wired into `.github/workflows/vsp-auth-ux-regressions.yml`.

## Accounting and exclusions
- 633 original unique task IDs unchanged.
- Previous: 309 accepted / 324 open.
- Eight new *limited-scope* acceptances: **04.03, 05.04, 06.02, 06.03, 08.03, 09.02, 09.04, 09.07**.
- New: **317 accepted / 316 open (50.08%)**.
- **Still open:** 05.02/05.03/05.05-07, 04.06 (every screen bilingual), 06.04/06.05, 09.03/09.05/09.06, broad regression and physical devices, real Supabase authentication/access control and all high-risk bookings/payments/challenges/security. This report is not a blanket release or accessibility pass.
- No changes to Supabase database, payments, production, `main`, or app store release. PR #35 remains draft. Latest full Flutter/Android CI requires independent confirmation.
