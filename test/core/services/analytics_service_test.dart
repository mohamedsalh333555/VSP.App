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
