import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking slot grid distinguishes empty, booked, and elapsed dates', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();

    expect(source, contains('if (widget.timeSlots.isEmpty) {'));
    expect(source, contains('لا توجد فترات حجز محددة لهذا اليوم'));
    expect(source, contains('final allSlotsBooked = widget.timeSlots.every('));
    expect(source, contains('if (allSlotsBooked) {'));
    expect(source, contains('كل المواعيد محجوزة'));
    expect(source, contains('All slots are booked'));
    expect(source, contains('final allSlotsPassed = widget.timeSlots.every('));
    expect(source, contains('if (allSlotsPassed) {'));
    expect(source, contains('انتهت مواعيد اليوم'));
    expect(source, contains('All slots have passed'));

    final emptyIndex = source.indexOf('if (widget.timeSlots.isEmpty) {');
    final bookedIndex = source.indexOf('if (allSlotsBooked) {');
    final passedIndex = source.indexOf('if (allSlotsPassed) {');
    final cardsIndex = source.indexOf('return Column(\n          children: List.generate');
    final mixedIndex = source.indexOf('if (!hasBookableSlot) {');
    expect(source, contains('final hasBookableSlot = widget.timeSlots.any('));
    expect(source, contains('لا توجد مواعيد متبقية'));
    expect(source, contains('No slots remaining'));
    expect(emptyIndex, lessThan(passedIndex));
    expect(passedIndex, lessThan(bookedIndex));
    expect(bookedIndex, lessThan(mixedIndex));
    expect(mixedIndex, lessThan(cardsIndex));
  });
}
