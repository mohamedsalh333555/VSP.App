import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment/checkout logs do not print raw transport or provider exceptions', () {
    const files = <String>[
      'lib/features/player/screens/payment_gateway_screen.dart',
      'lib/features/player/services/payment_checkout_coordinator.dart',
      'lib/core/services/paymob_service.dart',
    ];
    for (final file in files) {
      final contents = File(file).readAsStringSync();
      final logLines = contents.split('\n')
          .where((line) => line.contains('debugPrint(')).toList();
      expect(logLines, isNotEmpty, reason: 'Expected payment diagnostics in $file');
      for (final line in logLines) {
        expect(line, isNot(contains(r'$e')),
            reason: 'Payment exception leaked into debug log in $file');
        expect(line, isNot(contains(r'$err')),
            reason: 'Realtime exception leaked into debug log in $file');
        expect(line, isNot(contains(r'$error')),
            reason: 'Checkout exception leaked into debug log in $file');
      }
    }
  });
}
