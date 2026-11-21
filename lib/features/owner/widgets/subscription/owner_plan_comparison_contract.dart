/// Shows only documented, server-enabled benefits that a Pro owner gains
/// over the Free plan. This class never changes entitlements or prices.
///
/// Unknown or disabled feature keys do not turn into marketing promises.
abstract final class OwnerPlanComparisonContract {
  static const Set<String> knownFeatureKeys = <String>{
    'cash_booking',
    'online_booking',
    'shift_management',
    'no_show_protection',
    'tournament_management',
    'ai_insights',
    'excel_reports',
    'search_priority_boost',
    'whatsapp_confirmation',
    'atomic_booking',
  };

  /// A deliberately small, read-only diff of the current public plan rows.
  /// Never infer a premium entitlement from a missing or false value.
  static Map<String, dynamic> additionalProFeatures({
    required Map<String, dynamic> basicFeatures,
    required Map<String, dynamic> proFeatures,
  }) {
    final additions = <String, dynamic>{};
    for (final key in knownFeatureKeys) {
      if (proFeatures[key] == true && basicFeatures[key] != true) {
        additions[key] = true;
      }
    }
    if (proFeatures['support'] == 'priority_24_7' &&
        basicFeatures['support'] != 'priority_24_7') {
      additions['support'] = 'priority_24_7';
    }
    return Map<String, dynamic>.unmodifiable(additions);
  }

  /// Only advertise a capacity difference when both plan limits are valid
  /// positive integers and the Pro allowance is actually larger.
  static bool hasHigherStadiumCapacity({
    required int freeMaxStadiums,
    required int proMaxStadiums,
  }) =>
      freeMaxStadiums > 0 && proMaxStadiums > freeMaxStadiums;
}
