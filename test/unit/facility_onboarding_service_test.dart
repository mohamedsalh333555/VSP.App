import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/features/owner/services/facility_onboarding_service.dart';

void main() {
  group('FacilityOnboardingService Unit Tests', () {
    test('canAddStadium correctly gates addition based on owner capacity', () {
      final trialOwner = UserModel(
        uid: 'owner_trial',
        email: 'trial@vsp.com',
        role: 'owner',
        subscriptionPlan: 'free_trial',
        trialEndsAt: DateTime.now().add(const Duration(days: 30)),
      );

      // maxStadiums = 1
      expect(FacilityOnboardingService.canAddStadium(user: trialOwner, currentStadiumsCount: 0), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: trialOwner, currentStadiumsCount: 1), isFalse);
      expect(FacilityOnboardingService.canAddStadium(user: null, currentStadiumsCount: 0), isFalse);
    });

    test('canAddStadium allows up to 3 stadiums for Pro tier owners', () {
      final proOwner = UserModel(
        uid: 'owner_pro',
        email: 'pro@vsp.com',
        role: 'owner',
        subscriptionPlan: 'pro',
        subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      // maxStadiums = 3
      expect(FacilityOnboardingService.canAddStadium(user: proOwner, currentStadiumsCount: 0), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: proOwner, currentStadiumsCount: 2), isTrue);
      expect(FacilityOnboardingService.canAddStadium(user: proOwner, currentStadiumsCount: 3), isFalse);
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

    test('getPlanLabel returns localized labels accurately', () {
      final trialOwner = UserModel(
        uid: 'trial',
        email: 'trial@vsp.com',
        role: 'owner',
        subscriptionPlan: 'free_trial',
        trialEndsAt: DateTime.now().add(const Duration(days: 20)),
      );

      expect(
        FacilityOnboardingService.getPlanLabel(user: trialOwner, isArabic: true),
        equals('اشتراك مجاني — فترة تجريبية سنة'),
      );
      expect(
        FacilityOnboardingService.getPlanLabel(user: trialOwner, isArabic: false),
        equals('Free Trial — 1 Year Plan'),
      );

      final basicOwner = UserModel(
        uid: 'basic',
        email: 'basic@vsp.com',
        role: 'owner',
        subscriptionPlan: 'basic',
      );

      expect(
        FacilityOnboardingService.getPlanLabel(user: basicOwner, isArabic: true),
        equals('الباقة الأساسية (Basic)'),
      );
      expect(
        FacilityOnboardingService.getPlanLabel(user: basicOwner, isArabic: false),
        equals('Basic Plan'),
      );
    });

    test('getTrialDaysRemaining calculates clamped remaining days or zero', () {
      final activeTrial = UserModel(
        uid: 'active',
        email: 'active@vsp.com',
        role: 'owner',
        subscriptionPlan: 'free_trial',
        trialEndsAt: DateTime.now().add(const Duration(days: 15)),
      );
      expect(FacilityOnboardingService.getTrialDaysRemaining(activeTrial), greaterThanOrEqualTo(14));

      final expired = UserModel(
        uid: 'expired',
        email: 'expired@vsp.com',
        role: 'owner',
        subscriptionPlan: 'basic',
      );
      expect(FacilityOnboardingService.getTrialDaysRemaining(expired), equals(0));
    });
  });
}
