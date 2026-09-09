import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/providers/auth/auth_account_coordinator.dart';
import 'package:vsp_application/core/providers/auth/auth_profile_coordinator.dart';
import 'package:vsp_application/core/providers/auth/auth_session_sync_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProfileCoordinator Tests', () {
    test('null user handling in mutations', () async {
      final coordinator = AuthProfileCoordinator();

      final profileRes = await coordinator.updateProfile(
        authUser: null,
        currentUserModel: null,
        userType: null,
        data: {},
      );
      expect(profileRes, isNull);

      final favRes = await coordinator.toggleFavoriteStadium(
        authUser: null,
        currentUserModel: null,
        userType: null,
        stadiumId: 's1',
      );
      expect(favRes, isNull);

      final fineRes = await coordinator.payRehabilitationFine(authUser: null);
      expect(fineRes.success, isFalse);

      final deleteRes = await coordinator.deleteAccount(currentUserModel: null);
      expect(deleteRes.success, isFalse);
    });
  });

  group('AuthAccountCoordinator Tests', () {
    test('instantiates with default dependencies', () {
      final coordinator = AuthAccountCoordinator();
      expect(coordinator, isNotNull);
    });
  });

  group('AuthSessionSyncCoordinator Tests', () {
    test('instantiates and provides notificationService', () {
      final coordinator = AuthSessionSyncCoordinator();
      expect(coordinator, isNotNull);
      expect(coordinator.notificationService, isNotNull);
    });
  });
}
