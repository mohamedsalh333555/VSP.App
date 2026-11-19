import '../../../../data/models.dart';
import 'owner_schedule_slots_builder.dart';

/// Pure, UI-facing operational-day selector. The authenticated repository is
/// responsible for owner scoping; this does not replace database RLS.
abstract final class OwnerBookingScheduleFilter {
  static List<Booking> select({
    required Iterable<Booking> bookings,
    required String stadiumId,
    required DateTime operationalDay,
    required int openingHour,
  }) {
    final normalizedStadiumId = stadiumId.trim().toLowerCase();
    if (normalizedStadiumId.isEmpty || openingHour < 0 || openingHour > 23) {
      return const <Booking>[];
    }
    final targetYear = operationalDay.year;
    final targetMonth = operationalDay.month;
    final targetDay = operationalDay.day;
    return bookings.where((booking) {
      if (booking.stadiumId.trim().toLowerCase() != normalizedStadiumId ||
          booking.status == BookingStatus.cancelled) {
        return false;
      }
      // A shifted overnight booking stays on the venue's operational date
      // instead of being incorrectly moved into the next calendar day.
      final date = booking.operationalDate ??
          OwnerScheduleSlotsBuilder.getShiftDate(
            booking.startTime,
            openingHour,
          );
      return date.year == targetYear &&
          date.month == targetMonth &&
          date.day == targetDay;
    }).toList(growable: false);
  }
}
