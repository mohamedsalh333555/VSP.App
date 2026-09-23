# VSP Current System SSOT
## Current as of 2026-09-23

This document describes the production architecture that code, Supabase, Edge Functions, and business rules must converge on.

## Runtime

- Flutter application: lib/
- Primary backend: Supabase Auth + PostgreSQL + Realtime + Storage + Edge Functions
- Firebase: auxiliary mobile services only (FCM, Analytics, Crashlytics); not the primary authentication or database
- State management: Provider
- Routing: GoRouter
- Critical financial and authorization decisions are server-authoritative.

## Booking SSOT

Booking creation is server-authoritative through atomic PostgreSQL RPCs. The server calculates stadium price from the stadium configuration and duration. Client-supplied totals are not authoritative.

The normal electronic-payment lock window is 8 minutes.

Booking payment states must distinguish: pending, partially_paid, paid, failed, refunded.
partially_paid is not final payment completion.

## Payment and Fees

Approved booking-payment contract:
- VSP commission: 2.00%
- Paymob: 2.75%
- Fixed Paymob fee: 3.00 EGP

Authoritative values live in public.platform_fee_config.
The client may display the current configuration, but the server computes and verifies the final checkout amount.
Electronic webhook processing verifies the gross amount against the server fee configuration before financial state changes.

## Tournament Payment

Paid team-tournament registration:
create_tournament_order_atomic → server-created tournament_orders row → Paymob checkout using that exact order reference → verified Paymob webhook → confirm_tournament_order_atomic → roster synchronization.

Paid 1v1 registration uses vsp_1v1_tournament_orders and its own confirmation RPC.
The client must never invent a tournament price or bypass the server-created payment order.

## Attendance

QR attendance uses a cryptographically random raw token, SHA-256 stored hash, single-use validation, expiration, and owner/admin authorization.

Approved no-show dispute rules:
- GPS accuracy <= 50m
- Player distance <= 200m from stadium
- Dispute window: 60 minutes after match end

Manual attendance verification remains an explicit owner/admin override path and is not equivalent to QR verification for referral qualification.

## Challenge Results

Challenge result submission is server-authoritative through submit_challenge_result_atomic(uuid, uuid, text).
The server rejects results before match end, validates team membership and captain/admin authorization, stores the first result as waitingOpponent, finalizes matching second results, and marks conflicting results as disputed.

## Referrals

Referral qualification is tied to successful QR verification through process_referral_reward_on_qr_verification.
Referral records and points ledger are server-side sources of truth.

## Owner Finance

Owner financial truth is derived from server accounting/ledger RPCs and transaction records. Client-side revenue calculations are presentation concerns only and must not override server accounting.
Cash collection may increase owner cash debt according to the configured VSP commission policy.

## Security

SECURITY DEFINER functions must use an explicit search path, validate caller identity and role where required, and expose the minimum required execute surface.
Admin RPCs are authenticated operations with server-side RBAC.

## Deployment

Repository source and deployed Edge Functions must remain synchronized.
Production migration history must be represented in the repository before a production deployment is considered reproducible.
The staging Supabase project is a separate environment until its schema is intentionally provisioned and verified; do not assume empty staging represents production.

## Change Rule

For every business rule there must be one authoritative definition, one backend contract, and one test contract.
Never reintroduce hardcoded financial percentages in client code, client-authoritative tournament prices, final-success semantics for partial payments, or parallel direct booking state mutation when an atomic RPC exists.

