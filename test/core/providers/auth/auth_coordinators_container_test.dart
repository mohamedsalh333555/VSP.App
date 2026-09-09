import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/auth/auth_coordinators.dart';

void main() {
  group('AuthCoordinators Tests', () {
    test('initializes all coordinators with defaults', () {
      final coordinators = AuthCoordinators();
      expect(coordinators.account, isNotNull);
      expect(coordinators.profileService, isNotNull);
      expect(coordinators.realtime, isNotNull);
      expect(coordinators.sessionSync, isNotNull);
      expect(coordinators.otp, isNotNull);
      expect(coordinators.location, isNotNull);
      expect(coordinators.profile, isNotNull);
    });
  });
}
