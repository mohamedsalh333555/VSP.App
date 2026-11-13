import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product copy does not hard-code unverified limited-availability claims', () {
    final root = Directory('lib');
    final files = root
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    // User-facing hard-coded artificial countdowns and numerical scarcity
    // claims are disallowed. A true availability count must instead be
    // derived from the server-verified booking slots for that selected day.
    final forbidden = <RegExp>[
      RegExp(r'only\s+\d+\s+(?:slots?|spaces?|seats?)\s+left', caseSensitive: false),
      RegExp(r'last\s+chance\s+to\s+book', caseSensitive: false),
      RegExp(r'limited\s+spots?\s+left', caseSensitive: false),
      RegExp(r'باق[ىي]\s+\d+\s+(?:أماكن|اماكن|مواعيد|مقاعد)'),
      RegExp(r'آخر\s+فرصة\s+للحجز'),
    ];

    final violations = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(source)) {
          violations.add('${file.path}: ${pattern.pattern}');
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Marketing urgency requires verified source data; never hard-code it.',
    );
  });

  test('booked-availability labels rely on verified slot data, not a countdown', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    expect(source, contains('final existingBookings = snapshot.data!;'));
    expect(source, contains('final allSlotsBooked = widget.timeSlots.every('));
    expect(source, contains('_isSlotBooked(slot.key, existingBookings)'));
    expect(source.indexOf('if (snapshot.hasError)'),
        lessThan(source.indexOf('final existingBookings = snapshot.data!;')));
  });
}
