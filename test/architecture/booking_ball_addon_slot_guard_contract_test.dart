import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ball rental cannot be toggled without a booking slot', () {
    final bar = File(
      'lib/features/player/widgets/booking/booking_bottom_bar.dart',
    ).readAsStringSync();
    expect(bar, contains('onTap: isSlotSelected && !isLoading'));
    expect(bar, contains('اختار موعد الحجز أولًا'));
    expect(bar, contains('Select a booking slot first'));
  });

  test('ball rental never increases a zero-slot booking total', () {
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    expect(
      screen,
      contains('if (_selectedTimeSlots.isNotEmpty && _isBallRented) total += _ballPrice;'),
    );
    expect(screen, contains('if (!isSlotSelected || _isLoading) return;'));
  });
  test('ball rental resets when the last selected slot is deselected', () {
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('if (_selectedTimeSlots.isEmpty) _isBallRented = false;'));
  });

  test('ball rental consent resets when date changes or slots clear', () {
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final onClearStart = screen.indexOf('onSlotsCleared: () {');
    final onClearEnd = screen.indexOf('onSlotsCleared:', onClearStart + 1);
    expect(onClearStart, greaterThanOrEqualTo(0));
    final clearCallback = screen.substring(
      onClearStart,
      onClearEnd < 0 ? screen.length : onClearEnd,
    );
    expect(clearCallback,
        contains('if (!mounted || _activeBookingUserId != initiatingUserId) return;'));
    expect(clearCallback, contains('_selectedTimeSlots.clear();'));
    expect(clearCallback, contains('_isBallRented = false;'));
    expect(screen, contains('_selectedDate = date;'));
    expect(RegExp(r'_selectedTimeSlots\.clear\(\);\s*_isBallRented = false;')
        .allMatches(screen).length, 2);

  });
}
