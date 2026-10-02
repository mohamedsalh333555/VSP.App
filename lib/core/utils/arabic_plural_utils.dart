/// Utility for accurate and natural Arabic and English pluralization across VSP.
/// Adheres strictly to standard Arabic counting rules (مفرد، مثنى، جمع ٣-١٠، تمييز مفرد منصوب ١١+)
/// and colloquial Egyptian clarity.
class ArabicPluralUtils {
  ArabicPluralUtils._();

  /// ملاعب / Stadiums
  static String formatStadiumCount(int count, {bool isArabic = true}) {
    if (!isArabic) {
      return count == 1 ? '1 Stadium' : '$count Stadiums';
    }
    if (count <= 0) return 'لا توجد ملاعب';
    if (count == 1) return 'ملعب واحد';
    if (count == 2) return 'ملعبان';
    if (count >= 3 && count <= 10) return '$count ملاعب';
    return '$count ملعباً';
  }

  /// حجوزات / Bookings
  static String formatBookingCount(int count, {bool isArabic = true}) {
    if (!isArabic) {
      return count == 1 ? '1 Booking' : '$count Bookings';
    }
    if (count <= 0) return 'لا توجد حجوزات';
    if (count == 1) return 'حجز واحد';
    if (count == 2) return 'حجزان';
    if (count >= 3 && count <= 10) return '$count حجوزات';
    return '$count حجزاً';
  }

  /// حجوزات نقدية معلقة / Pending Cash Bookings
  static String formatPendingCashBookingCount(int count, {bool isArabic = true}) {
    if (!isArabic) {
      return count == 1
          ? '1 cash booking pending collection/confirmation'
          : '$count cash bookings pending collection/confirmation';
    }
    if (count <= 0) return 'كل الحجوزات النقدية مؤكدة ومحدثة';
    if (count == 1) return 'حجز نقدي واحد بحاجة للتحصيل أو التأكيد';
    if (count == 2) return 'حجزان نقديان بحاجة للتحصيل أو التأكيد';
    if (count >= 3 && count <= 10) return '$count حجوزات نقدية بحاجة للتحصيل أو التأكيد';
    return '$count حجزاً نقدياً بحاجة للتحصيل أو التأكيد';
  }

  /// لاعبين / Players
  static String formatPlayerCount(int count, {bool isArabic = true}) {
    if (!isArabic) {
      return count == 1 ? '1 Player' : '$count Players';
    }
    if (count <= 0) return 'لا يوجد لاعبون';
    if (count == 1) return 'لاعب واحد';
    if (count == 2) return 'لاعبان';
    if (count >= 3 && count <= 10) return '$count لاعبين';
    return '$count لاعباً';
  }

  /// ساعات / Hours
  static String formatHourCount(num count, {bool isArabic = true}) {
    if (!isArabic) {
      final formatted = count % 1 == 0 ? count.toInt().toString() : count.toStringAsFixed(1);
      return count == 1 ? '$formatted Hour' : '$formatted Hours';
    }
    if (count <= 0) return '0 ساعة';
    if (count == 1) return 'ساعة واحدة';
    if (count == 2) return 'ساعتان';
    if (count >= 3 && count <= 10 && count % 1 == 0) {
      return '${count.toInt()} ساعات';
    }
    final formatted = count % 1 == 0 ? count.toInt().toString() : count.toStringAsFixed(1);
    return '$formatted ساعة';
  }
}
