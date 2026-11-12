import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking slot grid distinguishes empty, booked, and elapsed dates', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();

    expect(source, contains('if (timeSlots.isEmpty) {'));
    expect(source, contains('لا توجد فترات حجز محددة لهذا اليوم'));
    expect(source, contains('final allSlotsBooked = timeSlots.every('));
    expect(source, contains('if (allSlotsBooked) {'));
    expect(source, contains('كل المواعيد محجوزة'));
    expect(source, contains('All slots are booked'));
    expect(source, contains('final allSlotsPassed = timeSlots.every('));
    expect(source, contains('if (allSlotsPassed) {'));
    expect(source, contains('انتهت مواعيد اليوم'));
    expect(source, contains('All slots have passed'));

    final emptyIndex = source.indexOf('if (timeSlots.isEmpty) {');
    final bookedIndex = source.indexOf('if (allSlotsBooked) {');
    final passedIndex = source.indexOf('if (allSlotsPassed) {');
    final cardsIndex = source.indexOf('return Column(\n          children: List.generate');
    expect(emptyIndex, lessThan(bookedIndex));
    expect(bookedIndex, lessThan(passedIndex));
    expect(passedIndex, lessThan(cardsIndex));
  });
}
