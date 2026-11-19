# VSP — 24 End-to-End Journeys Execution Log

Last updated: 2026-11-05 (Staging only)

This is an evidence log, not a release declaration. A journey is marked Passed
only when its complete required path was exercised against Staging. Production
was queried read-only for contract comparison and was never mutated.

| Journey | Status | What was actually exercised | Defect / fix | Verification evidence |
|---|---|---|---|---|
| 01 Owner registration | Blocked | Real owner password authentication and owner profile role verified | Real email inbox/link delivery is unavailable; email-verification source-of-truth defect fixed in `8d8be09d` | Staging auth token and `public.users` profile verified |
| 02 Add stadium | Passed | Real owner created a stadium with price, hours, location and deposit rules; uploaded a real image and private owner document | Restored the required Storage buckets and owner-folder policies without public document access | Stadium `a34382ee-6c12-4b82-b5fd-389c04c11922`; public image 200, private owner read 200, cross-account read/upload rejected; `e7a7009c` |
| 03 Admin approval | Blocked | Real admin approved the owner/stadium through the authoritative RPC; player was denied | Backend passes; no usable in-app admin dashboard route was found | `admin_approve_owner_atomic` success/denial evidence |
| 04 Stadium visibility | Passed | Anonymous read before approval returned 0; after approval returned the verified stadium | None in exercised contract | Before/after anonymous REST results |
| 05 Player registration | Blocked | Two real player password authentications and profile roles verified | Real email inbox/link delivery is unavailable | Both Staging auth tokens and profiles verified |
| 06 Normal booking | Passed | Created cash booking, owner confirmed it, and a second user was rejected on the same slot | None in exercised contract | Booking `5c3d63cb-1a3d-47fe-85fc-792cb78fcbaa`; duplicate returned `SLOT_LOCKED_OR_TAKEN` |
| 07 Group booking | Blocked | Created a real `open_join` booking; restored and verified all 20 canonical booking triggers | A valid new collective requires full online payment, so invite/join cannot be re-proven without Paymob Sandbox | Trigger fix `d73328ac`; prior booking `5afd7511-d876-4b55-b0a7-cda522035c28` predates restoration |
| 08 Challenge booking | Failed | Two real captains generated/consumed a challenge code and created a confirmed cash challenge | Current implementation disables opponent acceptance and confirms code-based challenges immediately, which does not satisfy the requested accept/reject journey | Booking `39ce86e5-f58f-402a-8ac4-c553c1e1dde8` |
| 09 Full electronic payment | Blocked | Payment-required guards and Staging function inventory checked | Paymob Sandbox secrets and required deployed functions are unavailable; no real charge attempted | 1v1 registration returned `PAYMENT_REQUIRED` |
| 10 Deposit payment | Blocked | Cash attempt on a deposit-required stadium returned the exact required deposit | Full online deposit, webhook and settlement require Sandbox payment | Server returned `ONLINE_DEPOSIT_REQUIRED` with 100 EGP deposit |
| 11 Cash payment | Failed | Cash booking creation and confirmation succeeded | No per-stadium “cash allowed” setting exists; cash is exposed globally subject to user restrictions | Confirmed cash booking plus source/schema evidence |
| 12 Cancellation/refund | Blocked | Authoritative cash cancellation succeeded; repeat was idempotent; illegal state reversal was rejected; slot was released | Fixed cancellation/booking-guard conflict. Paid refund remains untestable without a successful Sandbox payment | Booking is `cancelled/unpaid`, zero duplicate refunds, slot released; `d73328ac` |
| 13 Booking management | Passed | Player/owner listing, confirmation, reschedule request and owner acceptance exercised | None in exercised path | Booking moved to 20:00–21:00 with `reschedule_status=accepted` |
| 14 Team creation/invites | Failed | Two real captains created teams; captain update passed; unauthorized update and cross-governorate membership were rejected | Team schema defect fixed, but member flow adds users directly and has no invitation acceptance lifecycle | Teams `ade22b42-4761-4ae7-902a-cc4f1dfeabaa` / `f3407e8c-7da2-4720-ac83-faf3f48c953a`; `TEAM_GOVERNORATE_MISMATCH` |
| 15 Private tournament | Blocked | Owner cup approved; both teams registered with confirmed rosters; non-captain registration rejected | Fixed captain-name and roster timestamp contracts. Start correctly stops at unpaid creation fee | Championship `babff0ab-5ab4-48f6-ad29-55320cef5acd`; registrations `cadb3085-498e-40b3-b241-f7529ac32e2a` / `7c752a39-1bcb-4fea-8224-c93f449e1411`; `fd4be565` |
| 16 Open league | Blocked | Real captain created a four-team league; second captain joined; both received 30 EGP payment requirements | Fixed missing reference fee, required end date and deadline. Payment confirmation, fixtures, results and standings remain blocked | League `f950ed41-7a5c-4c85-9f48-80b42eada91a`; `fd4be565` |
| 17 1v1 tournament | Blocked | Admin created a real 1v1 tournament; player created a pending order; unpaid join was rejected | Completing payment is blocked by unavailable Paymob Sandbox integration | Tournament `b6db518e-deb4-4eff-82f0-603004cc74ae`; order `aa4a299f-404a-4eae-ab1d-9443cf0cdcbc` |
| 18 Winners screen | Not Run | Source rules inspected | Requires a legitimately completed tournament and approved final result | No completed isolated tournament exists |
| 19 Collective match | Blocked | Real collective booking attempted; all 20 canonical booking triggers attached and verified | New collective creation is restricted to full online payment; no active invite lifecycle can be completed without Sandbox | `COLLECTIVE_REQUIRES_FULL_ONLINE_PAYMENT`; `d73328ac` |
| 20 Chats/notifications | Blocked | Booking-scoped chat created; message sent/read by another account; read state updated; notification read verified | Device FCM push/deep-link delivery requires deployed FCM function and device token | Conversation `3b7b35ca-3fc4-483f-bb00-48c005059f20` |
| 21 Owner finance | Blocked | Owner summary loaded; canonical Free/Pro plans restored | No successful Sandbox subscription invoice/payment or supported payout flow exists to prove settlement | Zero-balance summary consistent; reference seed `fd4be565` |
| 22 Settings/privacy | Not Run | Source routes for language, notification preferences, privacy and sign-out found | Full device/account state verification remains | Pending Android authenticated journey |
| 23 Admin panel | Blocked | Non-admin admin-RPC denial and admin report visibility exercised | Backend access works; no usable in-app admin dashboard route was found | Report `9731701b-7647-48a5-bd92-8ca08efc8bfc` visible to admin, hidden from player |
| 24 Comprehensive release | Not Run | Live database journey calls completed and Supabase advisors rerun | Current head has no CI run, local Flutter SDK is unavailable, blocked payment/device journeys remain, and no APK was started | Head `8260cef9`; PR #35 remains Draft |

## Current totals

- Passed: 4
- Failed: 3
- Blocked: 14
- Not Run: 3

## Applied Staging-only fixes

- Restored all 20 canonical booking triggers.
- Repaired cancellation compatibility while keeping direct lifecycle mutations blocked.
- Aligned team creation with the actual team schema.
- Aligned tournament captain snapshots with `public.users.name`.
- Added the roster timestamp required by tournament RPCs.
- Restored canonical league fee and owner subscription reference rows without overwriting existing values.
- Supplied required league end date and registration deadline from the existing league format.
- Restored secure owner-scoped Storage for stadium images, profile pictures and private owner documents.

Commits:

- `0b0d5fab` — team schema and legacy cancellation contracts.
- `d73328ac` — booking trigger contract and atomic cancellation guard.
- `fd4be565` — tournament and open-league schema/reference contracts.
- `e7a7009c` — required Storage buckets and owner-scoped policies.

## Remaining blockers

- Required payment/FCM Edge Functions and Sandbox secrets are incomplete.
- Real email inbox/link verification is unavailable.
- Team invitations are not implemented as an accept/reject lifecycle.
- The requested challenge acceptance step conflicts with current code-based immediate confirmation.
- There is no per-stadium cash-allowed switch.
- No usable in-app admin dashboard route was found.
- Advisors still report pre-existing security-definer views/functions and multiple permissive policies. They were recorded, not changed wholesale, because broad permission/RLS rewrites require a separate audited security scope.
- No workflow run existed for head `8260cef9` when this report was recorded; no APK was built.

Blocked journeys are not counted as passed. No payment success, push delivery,
winner publication, final release validation or APK integrity claim is made.
