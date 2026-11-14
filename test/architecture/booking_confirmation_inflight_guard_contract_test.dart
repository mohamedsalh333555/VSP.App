import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking confirmation cannot be re-entered while loading', () {
    final source = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _handleBookingConfirmation() async {');
    final end = source.indexOf('await BookingConfirmationHandler.run(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final preflight = source.substring(start, end);
    expect(preflight, contains('if (_isLoading || _selectedTimeSlots.isEmpty) return;'));
  });

  test('slot and date changes are blocked during booking submission', () {
    final source = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final slotStart = source.indexOf(
        'void _onTimeSlotTap(String slotKey, List<Booking> existingBookings) {');
    final slotEnd = source.indexOf('Future<void> _handleBookingConfirmation()', slotStart);
    expect(slotStart, greaterThanOrEqualTo(0));
    expect(slotEnd, greaterThan(slotStart));
    final slotHandler = source.substring(slotStart, slotEnd);
    expect(slotHandler, contains('if (_isLoading || auth.isOwner'));
    expect(slotHandler,
        contains('auth.currentUser?.id != _activeBookingUserId) return;'));
    expect(
      source,
      contains('onDateChanged: (date) {\n              // Do not mutate the booking date while confirmation is in flight.\n              if (_isLoading) return;'),
    );
  });
}
