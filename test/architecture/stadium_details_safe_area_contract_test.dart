import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium details content respects the system top inset', () {
    final source = File(
      'lib/features/player/screens/stadium_details_screen.dart',
    ).readAsStringSync();
    expect(source, contains('body: SafeArea(\n            bottom: false,'));
    expect(source, contains('if (hasStreamIssue)'));
    expect(source, contains('StadiumImageCarousel('));
    expect(source, contains('bottomNavigationBar: StadiumBottomBookingBar('));
    expect(source, contains('bookingEnabled: stadium.isVerified && !hasStreamIssue && snapshot.hasData && snapshot.data!.isNotEmpty'));
  });
}
