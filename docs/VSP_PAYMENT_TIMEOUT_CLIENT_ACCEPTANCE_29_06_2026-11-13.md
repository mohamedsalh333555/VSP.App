# Payment timeout — client timer acceptance (task 29.06)

**Date:** 2026-11-13. **Acceptance is strictly client timing and recovery logic, not a Paymob live/sandbox settlement certification.**

## Test evidence
- [Flutter CI 43501718030](https://github.com/mohamedsalh333555/VSP.App/actions/runs/43501718030): 1288 unit/widget tests passed, 11 skipped, analyzer and architecture regression succeeded.
- [PaymentCheckoutCoordinator unit suite](../test/unit/payment_checkout_coordinator_test.dart) contains a **50 ms simulated webhook timeout** test asserting `onTimeout` fires after the deadline and **does not fire if the timer is canceled**. It also asserts the countdown ticks/cancels and coordinator `dispose()`/release cleanup do not throw.
- [Gateway screen](../lib/features/player/screens/payment_gateway_screen.dart) starts a 5-minute webhook timeout when awaiting confirmation and, if the current account and checkout context remain valid, transitions to an **uncertain** result rather than treating the missing callback as payment failure or charge success.
- [PaymentCheckoutCoordinator](../lib/features/player/services/payment_checkout_coordinator.dart) owns cancellable countdown, webhook, polling and stream subscriptions; current error display is localized by the [payment failure classifier](../lib/core/utils/payment_failure_classifier.dart). Uncertain outcomes require server reconciliation, not blind retry.

## Intentionally unaccepted release work
- The 50 ms test simulates timer behavior: it **does not** wait for five real minutes, use Paymob sandbox transactions or prove webhook delivery and provider state reversal.
- Related tasks **29.03–29.05, 29.07–29.08, 30.02–30.08** remain open; double-charge prevention and webhook idempotency require separate server and staged payment tests.
- If an account switches, the handler suppresses callbacks into the prior user's screen; this has not been proven on a physical Android device.
- No real booking, payment, subscription charge, production data, or server state was modified by this acceptance.

**Decision:** 29.06 accepted **for the tested client payment-timeout behavior only**; production release remains HOLD.
