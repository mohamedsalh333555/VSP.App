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
  test('ball rental consent resets when date changes or slots clear', () {
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('onSlotsCleared: () => setState(() {\\n        _selectedTimeSlots.clear();\\n        _isBallRented = false;'.replaceAll(r'\n', '\n')));
    expect(screen, contains('_selectedDate = date;\\n                _selectedTimeSlots.clear();\\n                _isBallRented = false;'.replaceAll(r'\n', '\n')));
  });
}
