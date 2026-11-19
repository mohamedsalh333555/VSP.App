# VSP — Owner Free / Pro source-of-truth entitlement inventory (25.01, 25.02)

**Date:** 2026-11-13. **Scope:** Read-only plan inventory and documentation acceptance for *venue owners only*. **Environment:** staging project `vtwgqyxglevcsxwdmhop`. **No customer data or production access.**

## Source and scope

- Read-only PostgreSQL query on `public.public_subscription_plans`, restricted to public plan codes `basic` and `pro`, returned exactly two public plan rows. Selected only `code,name_ar,name_en,monthly_price,yearly_price,trial_days,max_stadiums,features`.
- [Flutter owner subscription repository](../lib/core/repositories/owner_subscription_repository.dart) reads these columns (plus descriptions/order) from the same table through `fetchPublicPlans()`.
- [Subscription plans screen](../lib/features/owner/screens/subscription_plans_screen.dart) selects `basic` and `pro`, requires nonnegative prices/trial and positive `max_stadiums`, renders enabled feature flags dynamically, and declines to show stale hardcoded plan prices if the query fails. Pro/trial UI is read from owner model state.
- All values below are **staging configuration observed on this date**, *not* an approved commercial change, promise that all features are implemented, verified server authorization, or production prices.

## Staging plan comparison — EGP

| Item | Free (`basic`) | Pro (`pro`) |
|---|---|---|
| Monthly price | 0 EGP | 1,000 EGP |
| Annual price | 0 EGP | 11,000 EGP |
| Maximum registered stadiums in plan data | 1 | 3 |
| Trial length configured | 0 days | 7 days |
| Cash booking management | Enabled flag | Enabled flag |
| Online booking management | Enabled flag | Enabled flag |
| Shift/slot management | Enabled flag | Enabled flag |
| No-show protection | Enabled flag | Enabled flag |
| Tournament management | Enabled flag | Enabled flag |
| Atomic/conflict-safe booking flag | Enabled flag | Enabled flag |
| AI insights / VSP Copilot | Disabled flag | Enabled flag |
| Excel reports | Disabled flag | Enabled flag |
| Search priority boost | Disabled flag | Enabled flag |
| WhatsApp booking confirmation | Disabled flag | Enabled flag |
| Support tier | `standard` | `priority_24_7` |

The product-screen copy says owners can start free and upgrade by **subscription, with no per-booking commission**. Do not infer a booking commission or modify a fee model from this audit.

## Source-of-truth caveats and required follow-up

1. The table holds **displayed plan definitions and limits**. It does *not* independently demonstrate that every feature flag is enforced by an owner-scoped, server-side authorization check. Task **25.03**, feature restriction and tamper-proofing **25.06**, renewal **25.05/25.08**, expiry **25.04**, and free-plan downgrade **25.07** remain open pending real isolated role/expiry tests.
2. A plan marketing flag for WhatsApp, analytics, search, reports or support does not prove that its delivery, reporting dataset, policy or support SLA is live; these require separate feature acceptance.
3. Billing is a venue-owner subscription model, not a booking commission. Prices shown are **staging state at inspection**, not a pricing recommendation or approval to change charges. Keep production untouched without a reviewed commercial decision.
4. This inventory does **not** describe player paid/free feature access; such entitlements must be traced separately before making player pricing promises.
5. No `UPDATE`, `INSERT`, `DELETE`, schema migration, RPC mutation, external charge, production deployment or plan-price edit was performed.

**Acceptance boundary:** **25.01** and **25.02** are documented with code and live staging plan-row evidence, *as plan-documentation tasks only*. Server enforcement, real paid entitlements, subscription payment settlement, and user-facing production operation are **not accepted** by this inventory.
