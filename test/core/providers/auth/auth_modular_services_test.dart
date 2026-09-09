import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/providers/auth/auth_draft_cleaner.dart';
import 'package:vsp_application/core/providers/auth/auth_onboarding_coordinator.dart';
import 'package:vsp_application/core/providers/auth/auth_profile_service.dart';
import 'package:vsp_application/core/providers/auth/auth_registration_form_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthRegistrationFormState Tests', () {
    test('initial values and reset functionality', () {
      final form = AuthRegistrationFormState();
      expect(form.position, 'GK');
      expect(form.governorate, 'Cairo');
      expect(form.email, isNull);

      form.email = 'player@vsp.com';
      form.name = 'Ahmed';
      form.phone = '01012345678';
      form.userType = 'player';
      form.position = 'ST';
      form.password = 'Secret123!';

      expect(form.email, 'player@vsp.com');
      expect(form.name, 'Ahmed');
      expect(form.phone, '01012345678');
      expect(form.userType, 'player');
      expect(form.position, 'ST');

      form.reset();

      expect(form.email, isNull);
      expect(form.name, isNull);
      expect(form.phone, isNull);
      expect(form.userType, isNull);
      expect(form.password, isNull);
      expect(form.position, 'GK');
      expect(form.governorate, 'Cairo');
    });
  });

  group('AuthDraftCleaner Tests', () {
    test('clearSessionDrafts removes temp and user-scoped keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_stadium_123', 'stadium_data');
      await prefs.setString('temp_tournament_456', 'tournament_data');
      await prefs.setString('vsp_draft_booking', 'booking_data');
      await prefs.setString('vsp_draft_stadium_userA_1', 'draft_1');
      await prefs.setString('unrelated_key', 'keep_me');

      await AuthDraftCleaner.clearSessionDrafts('userA');

      expect(prefs.containsKey('temp_stadium_123'), isFalse);
      expect(prefs.containsKey('temp_tournament_456'), isFalse);
      expect(prefs.containsKey('vsp_draft_booking'), isFalse);
      expect(prefs.containsKey('vsp_draft_stadium_userA_1'), isFalse);
      expect(prefs.containsKey('unrelated_key'), isTrue);
    });
  });

  group('AuthOnboardingCoordinator Tests', () {
    test('loadStatus and complete work with SharedPreferences', () async {
      final initial = await AuthOnboardingCoordinator.loadStatus();
      expect(initial, isFalse);

      await AuthOnboardingCoordinator.complete();

      final updated = await AuthOnboardingCoordinator.loadStatus();
      expect(updated, isTrue);
    });
  });

  group('AuthProfileService Helper Tests', () {
    test('sanitizeProfileData strips restricted fields and normalizes phone', () {
      final raw = {
        'name': 'Captain Tsubasa',
        'phone': '01012345678',
        'role': 'admin',
        'isVerified': true,
        'isRegistrationComplete': true,
        'wallet_balance': 999999,
        'points': 500,
        'position': 'AM',
      };

      final sanitized = AuthProfileService.sanitizeProfileData(raw);

      expect(sanitized['name'], 'Captain Tsubasa');
      expect(sanitized['position'], 'AM');
      expect(sanitized['phone'], isNotNull);
      expect(sanitized.containsKey('role'), isFalse);
      expect(sanitized.containsKey('isVerified'), isFalse);
      expect(sanitized.containsKey('isRegistrationComplete'), isFalse);
      expect(sanitized.containsKey('wallet_balance'), isFalse);
      expect(sanitized.containsKey('points'), isFalse);
    });

    test('toggleFavoriteStadiumList adds and removes stadium ID correctly', () {
      final service = AuthProfileService();
      final initialList = ['stadium_1', 'stadium_2'];

      final afterAdd = service.toggleFavoriteStadiumList(
        currentFavorites: initialList,
        stadiumId: 'stadium_3',
      );
      expect(afterAdd, contains('stadium_3'));
      expect(afterAdd.length, 3);

      final afterRemove = service.toggleFavoriteStadiumList(
        currentFavorites: afterAdd,
        stadiumId: 'stadium_1',
      );
      expect(afterRemove.contains('stadium_1'), isFalse);
      expect(afterRemove.length, 2);
    });
  });
}
