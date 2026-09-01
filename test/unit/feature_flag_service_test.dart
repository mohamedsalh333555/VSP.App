import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/feature_flag_service.dart';

void main() {
  group('FeatureFlagService Tests', () {
    final service = FeatureFlagService();

    test('Defaults provide safe offline values', () {
      expect(service.isOnlinePaymentEnabled, isTrue);
      expect(service.isMaintenanceMode, isFalse);
      expect(service.isEnabled('is_championships_enabled'), isTrue);
    });

    test('Handles fallback for non-existent flags gracefully', () {
      expect(service.isEnabled('non_existent_key', defaultValue: false), isFalse);
      expect(service.getInt('non_existent_int', defaultValue: 42), equals(42));
      expect(service.getString('non_existent_str', defaultValue: 'default_val'), equals('default_val'));
    });
  });
}
