import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/services/facility_onboarding_service.dart';

void main() {
  group('FacilityOnboardingService Unit Tests', () {
    test('canAddStadium allows any authenticated owner without subscription paywall limits', () {
      final owner = UserModel(
        uid: 'owner_1',
        email: 'owner@vsp.com',
        role: 'owner',
      );

      expect(FacilityOnboardingService.canAddStadium(user: owner, currentStadiumsCount: 0), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: owner, currentStadiumsCount: 1), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: owner, currentStadiumsCount: 5), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: null, currentStadiumsCount: 0), isFalse);
    });

    test('buildOnboardingConfirmedPayload sets isOnboardingConfirmed flag preserving existing keys', () {
      final initialData = {'customKey': 'vsp_val', 'step': 1};
      final payload = FacilityOnboardingService.buildOnboardingConfirmedPayload(initialData);

      expect(payload['isOnboardingConfirmed'], isTrue);
      expect(payload['customKey'], equals('vsp_val'));
      expect(payload['step'], equals(1));
    });

    test('buildOnboardingConfirmedPayload handles null input safely', () {
      final payload = FacilityOnboardingService.buildOnboardingConfirmedPayload(null);
      expect(payload['isOnboardingConfirmed'], isTrue);
      expect(payload.length, equals(1));
    });

    test('getPlanLabel returns unified partner account labels accurately', () {
      final owner = UserModel(
        uid: 'owner',
        email: 'owner@vsp.com',
        role: 'owner',
      );

      expect(
        FacilityOnboardingService.getPlanLabel(user: owner, isArabic: true),
        equals('حساب شريك VSP (مجاني بدون اشتراك)'),
      );
      expect(
        FacilityOnboardingService.getPlanLabel(user: owner, isArabic: false),
        equals('VSP Partner Account (No Subscription)'),
      );
    });
  });
}
