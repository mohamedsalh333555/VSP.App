import '../../../core/models/user_model.dart';

/// Pure domain service managing facility onboarding business rules and validations.
class FacilityOnboardingService {
  const FacilityOnboardingService._();

  /// All verified owners can add stadiums without subscription paywall limits.
  static bool canAddStadium({
    required UserModel? user,
    required int currentStadiumsCount,
  }) {
    return user != null;
  }

  /// Constructs the additionalData payload marking onboarding as confirmed.
  static Map<String, dynamic> buildOnboardingConfirmedPayload(
    Map<String, dynamic>? currentAdditionalData,
  ) {
    final updated = Map<String, dynamic>.from(currentAdditionalData ?? {});
    updated['isOnboardingConfirmed'] = true;
    return updated;
  }

  /// Formats the current account label (subscriptions removed — unified partner account).
  static String getPlanLabel({
    required UserModel user,
    required bool isArabic,
  }) {
    return isArabic ? 'حساب شريك VSP (مجاني بدون اشتراك)' : 'VSP Partner Account (No Subscription)';
  }

  /// Calculates remaining trial days safely.
  static int getTrialDaysRemaining(UserModel user) {
    if (!user.isInActiveTrial || user.effectiveTrialEndsAt == null) {
      return 0;
    }
    final diff = user.effectiveTrialEndsAt!.difference(DateTime.now()).inDays;
    return diff.clamp(0, 999);
  }
}
