import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking summary distinguishes preselection from a calculated balance', () {
    final summary = File(
      'lib/features/player/widgets/booking/booking_financial_summary.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();

    expect(summary, contains('final bool hasSelectedSlots;'));
    expect(summary, contains('required this.hasSelectedSlots,'));
    expect(summary, contains('hasSelectedSlots\n'));
    expect(summary, contains('يُحسب بعد اختيار الموعد'));
    expect(summary, contains('Calculated after selecting a slot'));
    expect(summary, contains('(totalPrice - deposit).clamp(0, double.infinity)'));
    expect(screen, contains('hasSelectedSlots: isSlotSelected,'));
  });
}
