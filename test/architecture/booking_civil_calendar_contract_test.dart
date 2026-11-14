import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('14-day booking picker advances civil dates, not elapsed 24h periods', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_date_selector.dart',
    ).readAsStringSync();
    expect(source, contains('AppDateFormatter.addCivilDays(operationalBaseDate, index)'));
    expect(source, isNot(contains('operationalBaseDate.add(Duration(days: index))')));
  });

  test('maintenance venue stays visible with warning but closed slots are guarded', () {
    final details = File(
      'lib/features/player/screens/stadium_details_screen.dart',
    ).readAsStringSync();
    final slots = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/features/player/widgets/stadium_details/stadium_snapshot_resolver.dart',
    ).readAsStringSync();
    expect(details, contains('if (stadium.isUnderMaintenance)'));
    expect(details, contains('bookingEnabled: resolved.canBook'));
    expect(resolver, contains('stadium.isVerified && !stadium.isBlocked'));
    expect(slots, contains('final isClosed = _isSlotClosed(slotItem.key)'));
    expect(slots, contains('isClosed: isClosed'));
  });
}
