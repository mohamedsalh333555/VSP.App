import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';

void main() {
  group('51.07 — booking completion metrics during network interruptions', () {
    test('transport failure is not treated as an accepted completion event',
        () async {
      final dedupe = AnalyticsSessionDedupe();
      var transmitted = 0;
      var confirmed = false;

      Future<bool> record() {
        if (!confirmed) return Future<bool>.value(false);
        return dedupe.sendOnce(
          name: VSPAnalyticsEvents.bookingCompleted,
          dedupeKey: 'booking_completed:confirmed-booking',
          send: () async {
            transmitted++;
            return transmitted > 1;
          },
        );
      }

      expect(await record(), isFalse);
      expect(transmitted, 0,
          reason: 'A booking start or unresolved booking is not a completion');
      confirmed = true;
      expect(await record(), isFalse,
          reason: 'Offline analytics transport must not be marked delivered');
      expect(await record(), isTrue,
          reason: 'An identical confirmed booking may retry its unsent event');
      expect(await record(), isFalse,
          reason: 'A delivered completion cannot double count this session');
      expect(transmitted, 2);
    });

    test('a pending request cannot race a second success or create duplicates',
        () async {
      final gate = Completer<bool>();
      final dedupe = AnalyticsSessionDedupe();
      var transports = 0;
      Future<bool> send() => dedupe.sendOnce(
        name: VSPAnalyticsEvents.bookingCompleted,
        dedupeKey: 'booking_completed:booking-race',
        send: () {
          transports++;
          return gate.future;
        },
      );
      final first = send();
      expect(await send(), isFalse);
      expect(transports, 1);
      gate.complete(false);
      expect(await first, isFalse);
      // Simulate a network retry after an ambiguous failed transport.
      expect(await dedupe.sendOnce(
        name: VSPAnalyticsEvents.bookingCompleted,
        dedupeKey: 'booking_completed:booking-race',
        send: () async => true,
      ), isTrue);
      expect(await send(), isFalse);
      expect(transports, 1);
    });

    test('a thrown analytics exception allows a later retry', () async {
      final dedupe = AnalyticsSessionDedupe();
      var attempts = 0;
      Future<bool> transmit() => dedupe.sendOnce(
        name: VSPAnalyticsEvents.bookingCompleted,
        dedupeKey: 'booking_completed:offline-interrupted',
        send: () async {
          attempts++;
          if (attempts == 1) throw StateError('simulated network failure');
          return true;
        },
      );
      await expectLater(transmit(), throwsStateError);
      expect(await transmit(), isTrue);
      expect(await transmit(), isFalse);
      expect(attempts, 2);
    });

    test('booking logic, payment routing, and receipts do not claim completion early', () {
      final confirmation = File(
        'lib/features/player/screens/booking_confirmation_screen.dart',
      ).readAsStringSync();
      final handler = File(
        'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
      ).readAsStringSync();
      final receipt = File(
        'lib/features/player/screens/booking_success_screen.dart',
      ).readAsStringSync();
      final analytics = File('lib/core/services/analytics_service.dart')
          .readAsStringSync();

      expect(confirmation, isNot(contains(
        'AnalyticsService.logBookingCompleted(',
      )));
      expect(handler, isNot(contains(
        'AnalyticsService.logBookingCompleted(',
      )));
      expect(handler, contains('fetchStadiumBookingsDirectly('));
      expect(handler, contains('BookingPriceSnapshotGuard.matches('));
      expect(receipt, contains(
        'if (BookingStatusPresentation.isConfirmed(widget.booking.status)) {',
      ));
      expect(receipt, contains(
        'AnalyticsService.logBookingCompleted(',
      ));
      expect(analytics, contains('if (await send()) return true;'));
      expect(analytics, contains('parameters: safeParameters.isEmpty ? null : safeParameters,'));
      expect(analytics, contains('catch (_)'));
      expect(analytics, contains('return false;'));
      // A failed analytics upload is auxiliary, never a booking failure gate.
      expect(receipt, contains('unawaited('));
    });
  });
}
