import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium details disables booking until valid live data is available', () {
    final details = File(
      'lib/features/player/screens/stadium_details_screen.dart',
    ).readAsStringSync();
    expect(details, contains('bookingEnabled: !hasStreamIssue && snapshot.hasData && snapshot.data!.isNotEmpty'));
    expect(details, contains('final hasStreamIssue = snapshot.hasError || parseFailed;'));
  });

  test('disabled booking action cannot open booking type modal', () {
    final bar = File(
      'lib/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart',
    ).readAsStringSync();
    expect(bar, contains('final bool bookingEnabled;'));
    expect(bar, contains('onPressed: bookingEnabled ? () {'));
    expect(bar, contains('BookingTypeModal.show(context, stadium);'));
  });
}
