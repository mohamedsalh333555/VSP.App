import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium details disables booking until valid live data is available', () {
    final details = File(
      'lib/features/player/screens/stadium_details_screen.dart',
    ).readAsStringSync();
    expect(details, contains('bookingEnabled: stadium.isVerified && !stadium.isBlocked && !hasStreamIssue && snapshot.hasData && snapshot.data!.isNotEmpty'));
    expect(details, contains('final hasStreamIssue = snapshot.hasError || parseFailed;'));
    expect(details, contains('final isUnavailable = !stadium.isVerified || stadium.isBlocked ||'));
    expect(details, contains('onRetry: () => setState(_subscribeToStadium),'));
    expect(details, isNot(contains('final isUnavailable = !widget.stadium.isVerified ||')));
  });

  test('disabled booking action cannot open booking type modal', () {
    final bar = File(
      'lib/features/player/widgets/stadium_details/stadium_bottom_booking_bar.dart',
    ).readAsStringSync();
    expect(bar, contains('final bool bookingEnabled;'));
    // Formatter may wrap the conditional callback across several lines.
    // Verify that the disabled branch remains null, not the exact spacing.
    expect(
      RegExp(r'onPressed:\s*bookingEnabled\s*\?\s*\(\)\s*\{')
          .hasMatch(bar),
      isTrue,
    );
    expect(bar, contains(': null,'));
    expect(bar, contains('BookingTypeModal.show(context, stadium);'));
  });
}
