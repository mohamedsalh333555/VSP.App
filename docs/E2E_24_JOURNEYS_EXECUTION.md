# VSP — 24 End-to-End Journeys Execution Log

Last updated: 2026-11-05 (Staging only)

This is an evidence log, not a release declaration. A journey is marked Passed
only when its complete required path was exercised against Staging. Production
was queried read-only for contract comparison and was never mutated.

| Journey | Status | What was actually exercised | Defect / fix | Verification evidence |
|---|---|---|---|---|
| 01 Owner registration | Blocked | Real owner password authentication and owner profile role verified | Real email inbox/link delivery is unavailable; email-verification source-of-truth defect fixed in `8d8be09d` | Staging auth token and `public.users` profile verified |
| 02 Add stadium | Blocked | Real owner created `VSP E2E Cairo Pitch` with price, hours, location and deposit rules | Staging has no Storage buckets, so real image/document upload cannot complete | Stadium `a34382ee-6c12-4b82-b5fd-389c04c11922` persisted |
| 03 Admin approval | Blocked | Real admin approved the owner/stadium through the authoritative RPC | Backend passes; no usable in-app admin dashboard route was found | `admin_approve_owner_atomic` returned success; player call returned `Unauthorized` |
| 04 Stadium visibility | Passed | Anonymous read before approval returned 0; after approval returned the verified stadium | None in the exercised contract | Before/after anonymous REST results |
| 05 Player registration | Blocked | Two real player password authentications and profile roles verified | Real email inbox/link delivery is unavailable | Both Staging auth tokens and profiles verified |
| 06 Normal booking | Passed | Created cash booking, owner confirmed it, and a second user was rejected on the same slot | None in the exercised contract | Booking `5c3d63cb-1a3d-47fe-85fc-792cb78fcbaa`; duplicate returned `SLOT_LOCKED_OR_TAKEN` |
| 07 Group booking | Failed | Created a real `open_join` booking and attempted participant join/invite retrieval | Staging is missing booking triggers; booking was forced private but no invite token/code was generated | Booking `5afd7511-d876-4b55-b0a7-cda522035c28`; credentials returned null |
| 08 Challenge booking | Blocked | Source and RPC dependency chain inspected | Requires two valid teams; team creation is currently broken on the live schema | Journey 14 defect blocks setup |
| 09 Full electronic payment | Blocked | Payment-required guards and staging function inventory checked | Paymob Sandbox secrets and required deployed functions are unavailable; no real charge attempted | 1v1 registration returned `PAYMENT_REQUIRED` |
| 10 Deposit payment | Blocked | Cash attempt on a deposit-required stadium returned the exact required deposit | Full online deposit, webhook and settlement cannot run without Sandbox payment integration | Server returned `ONLINE_DEPOSIT_REQUIRED` with 100 EGP deposit |
| 11 Cash payment | Failed | Cash booking creation and confirmation succeeded | No per-stadium “cash allowed” setting exists; UI/server expose cash globally subject to user restrictions | Confirmed cash booking; source/schema search found no venue cash toggle |
| 12 Cancellation/refund | Failed | Rescheduled booking then attempted authoritative cancellation | Legacy 3-argument RPC writes unsupported `payment_status=cancelled`; compatibility migration prepared in `0b0d5fab` | Actual cancellation failed with constraint `bookings_payment_status_check` |
| 13 Booking management | Passed | Player/owner listing, confirmation, reschedule request and owner acceptance exercised | None in exercised path | Same booking moved to 20:00–21:00 with `reschedule_status=accepted` |
| 14 Team creation/invites | Failed | Real create-team calls made with player accounts | RPC references five nonexistent team columns; schema-alignment migration prepared. Current add-member flow drafts users without acceptance, so invitation acceptance is also missing | PostgreSQL `42703 preferred_formation does not exist`; fix in `0b0d5fab` |
| 15 Private tournament | Blocked | Owner created a real cup and admin approved it | Registration/matches/results require valid teams | Championship `babff0ab-5ab4-48f6-ad29-55320cef5acd`, approved/open |
| 16 Open league | Blocked | League source/RPC dependency chain inspected | Requires valid teams and paid/confirmed league setup | Journey 14 blocks participant setup |
| 17 1v1 tournament | Blocked | Admin created a real 1v1 tournament; player created a pending order; unpaid join was rejected | Completing payment is blocked by unavailable Paymob Sandbox integration | Tournament `b6db518e-deb4-4eff-82f0-603004cc74ae`; order `aa4a299f-404a-4eae-ab1d-9443cf0cdcbc` |
| 18 Winners screen | Not Run | Source rules inspected | Requires a legitimately completed tournament and approved final result | No completed isolated tournament exists |
| 19 Collective match | Failed | Real collective booking created; public join and private invite paths attempted | Staging has zero booking triggers versus 20 in Production, so invite/server counters are not initialized | Public join returned `match_not_public`; invite values were null |
| 20 Chats/notifications | Blocked | Booking-scoped chat created; message sent/read by other account; read state updated; notification read update verified | Device FCM push/deep-link delivery still requires deployed FCM function and device token | Conversation `3b7b35ca-3fc4-483f-bb00-48c005059f20`; message read changed false→true |
| 21 Owner finance | Blocked | Authoritative financial summary loaded for owner | Staging `subscription_plans` is empty while Production has Basic/Pro; no real payout exists | Summary returned consistent zero balance and one booking; plans returned `[]` |
| 22 Settings/privacy | Not Run | Source routes for language, notification preferences, privacy and sign-out found | Full device/account state verification remains | Pending Android authenticated journey |
| 23 Admin panel | Blocked | Non-admin admin-RPC denial and admin report visibility exercised with a real report | Backend access works; no usable in-app admin dashboard route was found | Report `9731701b-7647-48a5-bd92-8ca08efc8bfc` visible to admin, hidden from player |
| 24 Comprehensive release | Not Run | CI and Android smoke are running on the current branch | Must wait for allowed journeys and final review; APK not started | Current head `78c3632a`; PR #35 remains Draft |

## Current totals

- Passed: 3
- Failed: 4
- Blocked: 14
- Not Run: 3

## Confirmed Staging drift that prevents valid E2E evidence

- `public.bookings` has zero non-internal triggers in Staging; Production has 20.
- Staging Storage has no required buckets/policies.
- Staging `subscription_plans` has no Basic/Pro seed rows.
- Required payment/FCM Edge Functions and Sandbox secrets are incomplete.
- `create_team_atomic` does not match the actual `public.teams` columns.

The first three items are environment contract gaps. Until the authorized
Staging migrations are applied, results for bookings, collectives,
notifications, payments and tournaments cannot be treated as release evidence.
