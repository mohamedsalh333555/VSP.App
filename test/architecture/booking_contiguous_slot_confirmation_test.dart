import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/booking/booking_slot_calculator.dart';

void main() {
  test('accepts consecutive half-hour slots independent of input order', () {
    final base = DateTime.utc(2026, 11, 12, 18);
    expect(
      BookingSlotCalculator.areContiguousHalfHourStarts([
        base.add(const Duration(minutes: 60)),
        base,
        base.add(const Duration(minutes: 30)),
      ]),
      isTrue,
    );
  });

  test('rejects empty, duplicate, and gapped times', () {
    final base = DateTime.utc(2026, 11, 12, 18);
    expect(BookingSlotCalculator.areContiguousHalfHourStarts([]), isFalse);
    expect(
      BookingSlotCalculator.areContiguousHalfHourStarts([base, base]),
      isFalse,
    );
    expect(
      BookingSlotCalculator.areContiguousHalfHourStarts([
        base,
        base.add(const Duration(minutes: 60)),
      ]),
      isFalse,
    );
  });

  test('confirmation applies contiguity and expiry checks before drafting', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();
    final check = source.indexOf(
      'BookingSlotCalculator.areContiguousHalfHourStarts(selectedStarts)',
    );
    final draft = source.indexOf('final draft = BookingDraft(');
    expect(check, greaterThanOrEqualTo(0));
    expect(check, lessThan(draft));
    expect(source, contains('selectedStarts.any((start) => !start.isAfter(DateTime.now()))'));
    expect(source, contains('onSlotsCleared();'));
  });
}
