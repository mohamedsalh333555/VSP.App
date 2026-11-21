import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking and challenge screens do not log raw provider exceptions', () {
    const paths = <String>[
      'lib/features/player/screens/booking_confirmation_screen.dart',
      'lib/features/player/screens/bookings_screen.dart',
      'lib/features/player/screens/challenge_select_team_screen.dart',
      'lib/features/player/widgets/booking_type_modal.dart',
    ];
    for (final path in paths) {
      final source = File(path).readAsStringSync();
      final logLines = source
          .split('\n')
          .where((line) => line.contains('debugPrint('));
      for (final line in logLines) {
        expect(
          RegExp(r'\$(?:e|error|teamId|userId|uid)\b').hasMatch(line),
          isFalse,
          reason: 'Do not emit sensitive exception or account data in $path',
        );
      }
    }
  });

  test('stadium repository logs redact IDs, exception objects and traces', () {
    final source = File(
      'lib/core/repositories/stadium_repository.dart',
    ).readAsStringSync();
    final lines = source.split('\n').where(
          (line) => line.contains('VSPLogger.w(') || line.contains('VSPLogger.e('),
        );
    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(line, contains('details redacted'));
      expect(
        RegExp(r'\$(?:e|error|ownerId|ids)\b').hasMatch(line),
        isFalse,
      );
      expect(line, isNot(contains(', e,')));
      expect(line, isNot(contains(', stack)')));
    }
  });
}
