import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/analytics_service.dart';

void main() {
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
}
