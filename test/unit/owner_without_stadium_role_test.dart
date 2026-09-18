import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';

void main() {
  group('Owner Without Stadium Role Preservation Tests', () {
    test('Owner registered without stadiums is strictly preserved as owner', () {
      final rawMap = {
        'id': 'test-owner-uid',
        'email': 'vsp.stadiums@gmail.com',
        'name': 'Test Owner',
        'phone': '01100229462',
        'role': 'owner',
        'has_stadium': false,
        'hasStadium': false,
        'is_registration_complete': true,
        'is_onboarding_confirmed': true,
      };

      final model = UserModel.fromMap(rawMap);

      expect(model.role, equals('owner'));
      expect(model.isOwner, isTrue);
      expect(model.isPlayer, isFalse);
      expect(model.hasStadium, isFalse);
      expect(model.isOnboardingConfirmed, isTrue);
    });

    test('Owner with unconfirmed onboarding remains owner', () {
      final rawMap = {
        'id': 'test-owner-uid-2',
        'email': 'new.owner@vsp.com',
        'role': 'owner',
        'has_stadium': false,
        'is_onboarding_confirmed': false,
      };

      final model = UserModel.fromMap(rawMap);

      expect(model.role, equals('owner'));
      expect(model.isOwner, isTrue);
      expect(model.isPlayer, isFalse);
      expect(model.hasStadium, isFalse);
      expect(model.isOnboardingConfirmed, isFalse);
    });

    test('Player role with has_stadium indicator is elevated to owner', () {
      final rawMap = {
        'id': 'test-owner-legacy',
        'email': 'legacy.owner@vsp.com',
        'role': 'player',
        'has_stadium': true,
      };

      final model = UserModel.fromMap(rawMap);

      expect(model.role, equals('owner'));
      expect(model.isOwner, isTrue);
    });

    test('Standard player without stadium remains player', () {
      final rawMap = {
        'id': 'test-player-uid',
        'email': 'player@vsp.com',
        'role': 'player',
        'has_stadium': false,
      };

      final model = UserModel.fromMap(rawMap);

      expect(model.role, equals('player'));
      expect(model.isOwner, isFalse);
      expect(model.isPlayer, isTrue);
    });
  });
}
