import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_status_presentation.dart';

void main() {
  test('confirmation copy never labels a pending or cancelled booking confirmed', () {
    for (final status in [
      BookingStatus.pending,
      BookingStatus.cancelled,
      BookingStatus.expired,
      BookingStatus.noShow,
    ]) {
      expect(BookingStatusPresentation.isConfirmed(status), isFalse);
      final english = BookingStatusPresentation.heading(status, isArabic: false);
      final arabic = BookingStatusPresentation.heading(status, isArabic: true);
      expect(english, isNot('Booking confirmed'), reason: '$status');
      expect(arabic, isNot('الحجز مؤكد'), reason: '$status');
    }
    expect(
      BookingStatusPresentation.heading(BookingStatus.pending, isArabic: true),
      'الحجز قيد التأكيد',
    );
    expect(
      BookingStatusPresentation.heading(BookingStatus.cancelled, isArabic: false),
      'Booking cancelled',
    );
  });

  test('confirmed and upcoming aliases have positive copy in both languages', () {
    for (final status in [BookingStatus.confirmed, BookingStatus.upcoming]) {
      expect(BookingStatusPresentation.isConfirmed(status), isTrue);
      expect(BookingStatusPresentation.heading(status, isArabic: true),
          'الحجز مؤكد');
      expect(BookingStatusPresentation.heading(status, isArabic: false),
          'Booking confirmed');
    }
    expect(BookingStatusPresentation.isConfirmed(BookingStatus.completed), isTrue);
    expect(BookingStatusPresentation.heading(
        BookingStatus.completed, isArabic: false), 'Booking completed');
  });

  test('screen uses the booking lifecycle status for both icon and label', () {
    final source = File('lib/features/player/screens/booking_success_screen.dart')
        .readAsStringSync();
    expect(source, contains(
      'BookingStatusPresentation.isConfirmed(widget.booking.status)',
    ));
    expect(source, contains('BookingStatusPresentation.heading(widget.booking.status, isArabic: isArabic)'));
    expect(source, contains(
      'final confirmationColor = isBookingConfirmed ? VSPColors.accent : VSPColors.warning;',
    ));
    // Both badge and status label must use the actual warning/confirmed color.
    final badge = source.substring(source.indexOf('Icon(isBookingConfirmed'));
    expect(badge, contains('color: confirmationColor'));
    expect(badge, contains('style: TextStyle(\n           color: confirmationColor,'));
    expect(source, contains('Payment pending verification'));
    expect(source, contains('الدفع قيد التحقق'));
  });

  test('pending/failed outcomes do not emit confirmed-booking analytics', () {
    final source = File('lib/features/player/screens/booking_success_screen.dart')
        .readAsStringSync();
    final start = source.indexOf('void initState() {');
    final analytics = source.indexOf('AnalyticsService.logBookingCompleted(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(analytics, greaterThan(start));
    expect(source.substring(start, analytics), contains(
      'if (BookingStatusPresentation.isConfirmed(widget.booking.status)) {',
    ));
  });
}
