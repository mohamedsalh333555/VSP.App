import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending or cancelled bookings never emit completed booking analytics', () {
    final screen = File(
      'lib/features/player/screens/booking_success_screen.dart',
    ).readAsStringSync();
    final start = screen.indexOf('void initState() {');
    final analytics = screen.indexOf('AnalyticsService.logBookingCompleted(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(analytics, greaterThan(start));
    expect(
      screen.substring(start, analytics),
      contains('if (BookingStatusPresentation.isConfirmed(widget.booking.status)) {'),
    );
    expect(screen, contains('bookingStatusHeading,'));
    expect(screen, contains('BookingStatusPresentation.heading(widget.booking.status, isArabic: isArabic)'));
  });

  test('payment receipt never advertises paid online while still pending', () {
    final screen = File(
      'lib/features/player/screens/booking_success_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('final paymentPendingVerification ='));
    expect(screen, contains('widget.booking.paymentStatus.toLowerCase()'));
    expect(screen, contains('الدفع قيد التحقق'));
    expect(screen, contains('Payment pending verification'));
    expect(screen, contains('if (mounted && BookingStatusPresentation.isConfirmed(widget.booking.status)) {'));
  });
}
