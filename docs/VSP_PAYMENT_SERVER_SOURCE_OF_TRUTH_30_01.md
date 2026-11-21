# 30.01 — Authoritative payment state and reconciliation sources

## Decision

**The authoritative source of payment success is the persisted server-side payment/booking state after verified Paymob processing, not the client browser redirect, WebView result, countdown, or locally stored payment flag.**

## Evidence in repository

- `supabase/functions/paymob_webhook/index.ts`: Paymob server webhook computes SHA-512 HMAC from the documented transaction fields and uses the server's signing secret. It handles payment order correlation and server-side payment processing. The actual deployed webhook and signature-rejection behavior must be checked independently in 30.02 and 30.08.
- `lib/features/player/services/payment_checkout_service.dart`: `isPaymentConfirmed` requires booking status `confirmed` together with payment status `paid` or `partially_paid`. A legacy path accepts `paid` if booking status is omitted; this fallback needs strict review and must not authorize money movement.
- `lib/features/player/services/payment_checkout_coordinator.dart`: `startFallbackPolling` fetches a booking and checks `PaymentCheckoutService.isPaymentConfirmed`. `startTournamentOrderPolling` checks server payment order `success == true` and `payment_status == paid`. The browser result alone is not proof.
- `lib/core/repositories/booking/booking_creation_coordinator.dart`: booking creation goes through atomic Supabase RPCs. Creation and payment confirmation are separate states; a pending booking is not a paid booking.
- `lib/core/repositories/booking/booking_cancellation_coordinator.dart`: refund and cancellation flows use a server Edge Function or atomic RPC, and a pending-refund response can be considered cancelled only after reading the persisted booking state.

## Canonical client reconciliation contract

1. Resolve the transaction/order/booking reference from the server.
2. For money movement, trust verified webhook processing and server-side order/transaction records; never trust query parameters or WebView navigation as financial proof.
3. For a standard booking, show successful electronic payment only after server booking status is `confirmed` and payment status is `paid` or `partially_paid`.
4. For tournament orders, show success only when server order status is `paid`.
5. If a timeout, network failure, duplicate response, or unknown error occurs, keep the outcome **uncertain** until server reconciliation. Never start a fresh charge solely because the client timed out.
6. Handle delayed/out-of-order webhooks and retries idempotently. A refund-pending state is not the same as refund completed.

## Not yet verified

Live Paymob HMAC enforcement, provider transaction-to-booking matching, idempotent webhook replay, reversed event order, transaction audit log completeness, and sandbox outcomes remain in tasks 30.02–30.08. This document defines the source-of-truth contract, **not** a production verification report.
