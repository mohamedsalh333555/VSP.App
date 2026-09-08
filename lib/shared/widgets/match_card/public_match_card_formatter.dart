import '../../../data/models.dart';

/// Pure domain helper for formatting match card information, time windows,
/// localized types, and capacity calculations.
class PublicMatchCardFormatter {
  const PublicMatchCardFormatter._();

  /// Shortens a standard time range string, e.g. "18:00 - 19:00" -> "18-19".
  static String formatTimeShort(String timeRange) {
    final parts = timeRange.split(' - ');
    if (parts.length == 2) {
      return '${parts[0].replaceAll(':00', '')}-${parts[1].replaceAll(':00', '')}';
    }
    return timeRange;
  }

  /// Returns localized label for booking types across player public matches.
  static String getLocalizedBookingType(BookingType type, {required bool isArabic}) {
    switch (type) {
      case BookingType.personal:
        return isArabic ? 'حجز عادي' : 'SOLO';
      case BookingType.openJoin:
        return isArabic ? 'تجميعي' : 'OPEN JOIN';
      case BookingType.team:
        return isArabic ? 'فريق' : 'TEAM';
      case BookingType.challenge:
        return isArabic ? 'تحدي' : 'CHALLENGE';
      case BookingType.matchup:
        return isArabic ? 'مواجهات' : 'MATCHUP';
    }
  }

  /// Calculates remaining player spots safely clamped between 0 and total capacity.
  static int calculateRemainingSpots({required int totalCapacity, required int currentPlayers}) {
    if (totalCapacity <= 0) return 0;
    return (totalCapacity - currentPlayers).clamp(0, totalCapacity);
  }

  /// Calculates per-player entry fee string rounded to the nearest integer.
  static String calculateEntryFee({required double totalPrice, required int totalCapacity}) {
    if (totalCapacity <= 0) return '0';
    return (totalPrice / totalCapacity).toStringAsFixed(0);
  }
}
