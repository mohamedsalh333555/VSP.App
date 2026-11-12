import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no configured slots do not assert the venue is closed', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    final start = source.indexOf('if (widget.timeSlots.isEmpty) {');
    final end = source.indexOf('final now = VSPTimeService.now;', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final emptyState = source.substring(start, end);
    expect(emptyState, contains('لا توجد فترات حجز محددة لهذا اليوم'));
    expect(emptyState, contains('No booking time slots are configured for this day'));
    expect(emptyState, isNot(contains('الملعب لا يفتح مواعيد للحجز')));
  });

  test('booking availability stream failures have a separate error state', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    expect(source, contains('if (snapshot.hasError) {'));
    expect(source, isNot(contains('snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)')));
    expect(source, contains('state: VSPUiState.error'));
    expect(source, contains('if (widget.timeSlots.isEmpty)'));
  });
}
