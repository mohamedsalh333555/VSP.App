import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  group('Phase 10 analytics placement contract', () {
    test('records the player funnel at real journey boundaries', () {
      expect(
        _source('lib/main.dart'),
        contains('AnalyticsService.logAppOpened()'),
      );
      expect(
        _source('lib/features/auth/screens/welcome_screen.dart'),
        contains('AnalyticsService.logOnboardingStarted()'),
      );
      expect(
        _source('lib/features/auth/screens/player_onboarding_screen.dart'),
        contains("AnalyticsService.logSignupCompleted(role: 'player')"),
      );
      expect(
        _source('lib/features/player/screens/stadium_details_screen.dart'),
        contains('AnalyticsService.logVenueViewed('),
      );
      expect(
        _source(
          'lib/features/player/widgets/stadium_details/'
          'stadium_bottom_booking_bar.dart',
        ),
        contains('AnalyticsService.logBookingStarted('),
      );
      expect(
        _source('lib/features/player/screens/booking_success_screen.dart'),
        contains('AnalyticsService.logBookingCompleted('),
      );
      expect(
        _source('lib/features/player/screens/match_details_screen.dart'),
        allOf(
          contains('AnalyticsService.logMatchViewed('),
          contains('AnalyticsService.logMatchJoined('),
        ),
      );
    });

    test('records owner registration and pricing entry points', () {
      final ownerOnboarding =
          _source('lib/features/auth/screens/owner_onboarding_screen.dart');
      expect(
        ownerOnboarding,
        allOf(
          contains('AnalyticsService.logOwnerRegistrationStarted()'),
          contains("AnalyticsService.logSignupCompleted(role: 'owner')"),
          contains('AnalyticsService.logOwnerRegistrationCompleted()'),
        ),
      );
      expect(
        _source('lib/features/owner/screens/subscription_plans_screen.dart'),
        contains('AnalyticsService.logSubscriptionViewed()'),
      );
    });

    test('does not report financial completion before confirmation', () {
      final confirmation =
          _source('lib/features/player/screens/booking_confirmation_screen.dart');
      final subscriptionPlans =
          _source('lib/features/owner/screens/subscription_plans_screen.dart');

      expect(
        confirmation,
        isNot(contains('AnalyticsService.logBookingCompleted(')),
      );
      expect(
        subscriptionPlans,
        isNot(contains('AnalyticsService.logSubscriptionActivated(')),
        reason:
            'Paid activation must wait for authoritative payment/webhook state.',
      );
    });
  });
}
