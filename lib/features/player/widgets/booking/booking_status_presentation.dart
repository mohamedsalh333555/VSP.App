import '../../../../data/models.dart';

/// Presentation-only labels. Never infer a confirmed booking from arriving
/// on a success route: use the actual booking lifecycle state.
abstract final class BookingStatusPresentation {
  static bool isConfirmed(BookingStatus status) =>
      status == BookingStatus.confirmed ||
      status == BookingStatus.upcoming ||
      status == BookingStatus.completed;

  static String heading(BookingStatus status, {required bool isArabic}) {
    switch (status.canonical) {
      case BookingStatus.confirmed:
        return isArabic ? 'الحجز مؤكد' : 'Booking confirmed';
      case BookingStatus.completed:
        return isArabic ? 'الحجز مكتمل' : 'Booking completed';
      case BookingStatus.pending:
        return isArabic ? 'الحجز قيد التأكيد' : 'Booking awaiting confirmation';
      case BookingStatus.cancelled:
        return isArabic ? 'الحجز ملغي' : 'Booking cancelled';
      case BookingStatus.expired:
        return isArabic ? 'انتهت صلاحية الحجز' : 'Booking expired';
      case BookingStatus.noShow:
        return isArabic ? 'تم تسجيل عدم الحضور' : 'Marked as no-show';
      case BookingStatus.upcoming:
        // canonical normalizes this alias to confirmed.
        return isArabic ? 'الحجز مؤكد' : 'Booking confirmed';
    }
  }
}
