import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedule, card, and confirmation all guard maintenance closures', () {
    final slots = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    final card = File(
      'lib/features/player/widgets/booking/booking_slot_card.dart',
    ).readAsStringSync();
    final confirmation = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();
    final calculator = File(
      'lib/features/player/widgets/booking/booking_slot_calculator.dart',
    ).readAsStringSync();

    expect(slots, contains('final isClosed = _isSlotClosed(slotItem.key)'));
    expect(slots, contains('isClosed: isClosed'));
    expect(slots, contains("isArabic ? 'الملعب مغلق مؤقتًا'"));
    expect(card, contains('this.isClosed = false'));
    expect(card, contains("isArabic ? ' مغلق' : ' Closed'"));
    expect(calculator, contains('static bool isVenueSlotClosed('));
    expect(confirmation, contains('BookingSlotCalculator.isVenueSlotClosed('));
  });
}
