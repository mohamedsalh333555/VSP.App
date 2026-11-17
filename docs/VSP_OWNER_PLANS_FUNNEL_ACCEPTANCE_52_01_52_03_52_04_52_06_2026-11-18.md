# VSP — Owner subscription comparison, safe upgrade path and expiry notices

**18 November 2026 (Cairo)** · Branch `uxlp-44-implementation` · PR #35 draft.

**Exact tested code:** [1b68fbe](https://github.com/mohamedsalh333555/VSP.App/commit/1b68fbe0d5d223e2c308554abbe7d63b5e1c34c4).
**Evidence:** [VSP Owner Plans and Funnel Contracts — SUCCESS](https://github.com/mohamedsalh333555/VSP.App/actions/runs/44187634461), including Flutter source Analyze and focused tests of owner plan comparison, checkout destination, expiry/timezone boundaries, owner dashboard event placement, legacy expiry tests and existing Phase 10 analytics placement.

## Narrow acceptance of four previously open tasks

### 52.01 — Owner dashboard entry measurement, source contract only

`OwnerDashboardScreen` sends `owner_dashboard_viewed` for an authenticated owner only on a visible home dashboard and on transition back from another owner tab. The event helper keys deduplication by owner within a session; IDs are used for in-process deduplication, not event parameters. New tests exercise same-owner repetition, a different owner on a shared client, and transport-failure retry. This is **event-hook and deduplication acceptance**, not confirmation that Firebase accepted a live event or that a production owner funnel has been measured.

### 52.03 — Clear Free versus Pro differences

`OwnerPlanComparisonContract.additionalProFeatures` computes only allowlisted, explicitly enabled features in the server-returned Pro plan that were not in Free, and permits higher venue capacity to be advertised only when Pro's verified limit is greater. The subscription screen displays the additional benefits without inventing prices or promising disabled features. It now refuses the unconditional "Free forever" display if the server's Basic pricing contradicts free status; the Pro Copilot badge is conditional on the current plan's actual `ai_insights` feature. The comparison is a **source and UI contract**, not verified commercial product entitlement or manual device user research.

### 52.04 — Safer owner upgrade journey

The owner checkout still starts an RPC-created subscription order and uses the existing Edge Function to obtain a Paymob URL. It now rejects non-HTTPS links, URL-embedded user credentials, spoofed hostnames, alternative hosts, unusual ports, missing payment token fields, modified checkout path, fragments, and bogus schemes. The only accepted destination matches the **currently implemented** `https://accept.paymob.com/unifiedcheckout/` from `create_paymob_intention`. Tests also verify that opening checkout does **not** mark the subscription activated. This is **secure client routing acceptance**, not a test of a real Paymob transaction, future provider domain changes, active subscription after webhook or full owner upgrade E2E.

### 52.06 — Subscription expiration message tests

Bilingual notice tests cover paid versus trial expiry, exact expiry boundaries, Cairo timezone offsets, active paid/trial suppression, non-owner/free-plan suppression, and presence only on the expired UI state. `OwnerPlanExpiryPresentation` is presentation-only and cannot modify subscriptions or issue server commands. This accepts **in-app expiry message testing**, not remote expiry notification delivery, a genuine timed subscription change on a physical device, or enforcement by the server.

## Not accepted here

Tasks **52.05** (live confirmed subscription conversion), 54.04/54.08 (server FCM consent), and all Paymob hosted/Sandbox and release-security checks remain open. The existing activation-funnel viewer is offline-only and remains unaccepted for full production analytics.

## Accounting and boundaries

Four existing task IDs accepted, **no new unique task IDs**. From **633 total / 285 accepted / 348 open**, revised tally is **633 total / 289 accepted / 344 open (45.66%)**. Tests were executed against the linked SHA before these documentation commits. No database mutation, subscription activation, real payment, production deployment, APK build or `main` merge.
