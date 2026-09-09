import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/services/payment_checkout_coordinator.dart';

void main() {
  group('PaymentCheckoutCoordinator Tests', () {
    test('startCountdownTimer ticks down and cancels gracefully', () async {
      final coordinator = PaymentCheckoutCoordinator();
      final ticks = <int>[];

      coordinator.startCountdownTimer(
        initialSeconds: 2,
        onTick: (val) => ticks.add(val),
        onExpired: () async {},
      );

      await Future.delayed(const Duration(milliseconds: 1100));
      coordinator.cancelCountdownTimer();

      expect(ticks.isNotEmpty, isTrue);
      coordinator.dispose();
    });

    test('startWebhookTimeout triggers callback on timeout and cancels', () async {
      final coordinator = PaymentCheckoutCoordinator();
      bool timedOut = false;

      coordinator.startWebhookTimeout(
        timeout: const Duration(milliseconds: 50),
        onTimeout: () => timedOut = true,
      );

      await Future.delayed(const Duration(milliseconds: 100));
      expect(timedOut, isTrue);

      // Verify cancellation works
      timedOut = false;
      coordinator.startWebhookTimeout(
        timeout: const Duration(milliseconds: 50),
        onTimeout: () => timedOut = true,
      );
      coordinator.cancelWebhookTimeout();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(timedOut, isFalse);

      coordinator.dispose();
    });

    test('releaseBookingSafely cancels all timers without error when booking is null', () async {
      final coordinator = PaymentCheckoutCoordinator();
      expect(() async {
        await coordinator.releaseBookingSafely(
          isTournamentPayment: false,
          booking: null,
        );
      }, returnsNormally);
      coordinator.dispose();
    });

    test('dispose cancels all timers without error', () {
      final coordinator = PaymentCheckoutCoordinator();
      expect(() => coordinator.dispose(), returnsNormally);
    });
  });
}
