import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_status_presentation.dart';

void main() {
  test('only confirmed, upcoming, and completed bookings can count as completed funnel actions', () {
    for (final status in BookingStatus.values) {
      expect(
        BookingStatusPresentation.isConfirmed(status),
        status == BookingStatus.confirmed ||
            status == BookingStatus.upcoming ||
            status == BookingStatus.completed,
        reason: 'Bad confirmation classification for $status',
      );
    }
  });

  test('all lifecycle states have distinct, nonempty bilingual status labels', () {
    for (final status in BookingStatus.values) {
      final arabic = BookingStatusPresentation.heading(status, isArabic: true);
      final english = BookingStatusPresentation.heading(status, isArabic: false);
      expect(arabic, isNotEmpty);
      expect(english, isNotEmpty);
      expect(arabic, isNot(english));
    }
    expect(
      BookingStatusPresentation.heading(BookingStatus.pending, isArabic: true),
      'الحجز قيد التأكيد',
    );
    expect(
      BookingStatusPresentation.heading(BookingStatus.cancelled, isArabic: false),
      'Booking cancelled',
    );
    expect(
      BookingStatusPresentation.heading(BookingStatus.expired, isArabic: false),
      'Booking expired',
    );
  });
}
