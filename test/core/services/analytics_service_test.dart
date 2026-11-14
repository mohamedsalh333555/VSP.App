import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';

void main() {
  group('Session funnel deduplication', () {
    test('counts one venue visit once despite repeated route rebuilds', () {
      final dedupe = AnalyticsSessionDedupe();
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.venueViewed, dedupeKey: 'venue_viewed:venue-a'), isTrue);
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.venueViewed, dedupeKey: 'venue_viewed:venue-a'), isFalse);
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.venueViewed, dedupeKey: 'venue_viewed:venue-b'), isTrue);
    });

    test('isolates event types even when supplied the same dedupe key', () {
      final dedupe = AnalyticsSessionDedupe();
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.venueViewed, dedupeKey: 'same'), isTrue);
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.bookingStarted, dedupeKey: 'same'), isTrue);
      expect(dedupe.markFirst(name: VSPAnalyticsEvents.bookingStarted, dedupeKey: 'same'), isFalse);
    });

    test('a new session registry allows a new session visit', () {
      final firstSession = AnalyticsSessionDedupe();
      final secondSession = AnalyticsSessionDedupe();
      expect(firstSession.markFirst(name: VSPAnalyticsEvents.appOpened, dedupeKey: 'app_opened'), isTrue);
      expect(firstSession.markFirst(name: VSPAnalyticsEvents.appOpened, dedupeKey: 'app_opened'), isFalse);
      expect(secondSession.markFirst(name: VSPAnalyticsEvents.appOpened, dedupeKey: 'app_opened'), isTrue);
    });
  });

  group('Offline analytics event retry', () {
    test('failed delivery is retried and success is deduplicated', () async {
      final dedupe = AnalyticsSessionDedupe();
      var attempts = 0;
      Future<bool> simulateSend() async {
        attempts++;
        return attempts > 1;
      }

      Future<bool> emit() => dedupe.sendOnce(
            name: VSPAnalyticsEvents.bookingCompleted,
            dedupeKey: 'booking_completed:booking-1',
            send: simulateSend,
          );

      expect(await emit(), isFalse);
      expect(await emit(), isTrue);
      expect(await emit(), isFalse);
      expect(attempts, 2);
    });

    test('concurrent requests suppress a duplicate pending send', () async {
      final dedupe = AnalyticsSessionDedupe();
      final pending = Completer<bool>();
      var attempts = 0;
      Future<bool> send() {
        attempts++;
        return pending.future;
      }

      Future<bool> emit() => dedupe.sendOnce(
            name: VSPAnalyticsEvents.venueViewed,
            dedupeKey: 'venue_viewed:venue-1',
            send: send,
          );

      final first = emit();
      expect(await emit(), isFalse);
      expect(attempts, 1);
      pending.complete(true);
      expect(await first, isTrue);
      expect(await emit(), isFalse);
      expect(attempts, 1);
    });

    test('sender exceptions release the deduplication key', () async {
      final dedupe = AnalyticsSessionDedupe();
      Future<bool> fail() async => throw StateError('offline');
      expect(
        () => dedupe.sendOnce(
          name: VSPAnalyticsEvents.bookingStarted,
          dedupeKey: 'booking_started:venue-1',
          send: fail,
        ),
        throwsStateError,
      );
      // Allow the previous Future to settle before attempting another send.
      await Future<void>.delayed(Duration.zero);
      expect(
        await dedupe.sendOnce(
          name: VSPAnalyticsEvents.bookingStarted,
          dedupeKey: 'booking_started:venue-1',
          send: () async => true,
        ),
        isTrue,
      );
    });
  });

  group('AnalyticsService privacy contract', () {
    test('removes direct personal and credential-like parameters', () {
      final safe = AnalyticsService.privacySafeParameters({
        'role': 'owner',
        'plan_code': 'pro',
        'payment_method': 'online',
        'email': 'person@example.com',
        'phone_number': '01000000000',
        'display_name': 'Example Person',
        'auth_token': 'secret',
        'free_message': 'private text',
        'street_address': 'private address',
      });

      expect(
        safe,
        {
          'role': 'owner',
          'plan_code': 'pro',
          'payment_method': 'online',
        },
      );
    });

    test('returns an immutable empty map for absent parameters', () {
      final safe = AnalyticsService.privacySafeParameters(null);
      expect(safe, isEmpty);
      expect(() => safe['role'] = 'player', throwsUnsupportedError);
    });
  });

  group('Phase 10 conversion event schema', () {
    test('keeps the documented funnel event names stable and Firebase-safe', () {
      const expected = <String>{
        'app_opened',
        'onboarding_started',
        'signup_completed',
        'venue_viewed',
        'booking_started',
        'booking_completed',
        'match_viewed',
        'match_joined',
        'team_created',
        'owner_registration_started',
        'owner_registration_completed',
        'subscription_viewed',
        'subscription_activated',
      };

      expect(VSPAnalyticsEvents.conversionFunnel, expected);
      for (final eventName in VSPAnalyticsEvents.conversionFunnel) {
        expect(
          eventName,
          matches(RegExp(r'^[a-z][a-z0-9_]{0,39}$')),
          reason: 'Invalid analytics event name: $eventName',
        );
      }
    });

    test('does not accidentally duplicate a conversion event name', () {
      final events = VSPAnalyticsEvents.conversionFunnel.toList();
      expect(events.toSet().length, events.length);
    });
  });
}
