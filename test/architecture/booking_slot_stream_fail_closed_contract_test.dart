import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking availability stream errors always fail closed', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();

    expect(source, contains('if (snapshot.hasError) {'));
    expect(source, isNot(contains(
      'snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)',
    )));
    expect(source, contains('state: VSPUiState.error'));
    expect(source, contains('onRetry: _retry'));
    expect(source, contains('if (!snapshot.hasData) {'));
    expect(source, contains('final existingBookings = snapshot.data!;'));
    expect(source.indexOf('if (snapshot.hasError) {'),
        lessThan(source.indexOf('final existingBookings = snapshot.data!;')));
  });
}
