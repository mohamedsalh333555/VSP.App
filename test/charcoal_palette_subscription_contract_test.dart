import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical VSP palette does not reintroduce neon green', () {
    final tokens = File('lib/core/ui/tokens/vsp_design_tokens.dart')
        .readAsStringSync()
        .toLowerCase();
    expect(tokens, isNot(contains('0xff9fdf02')));
    expect(tokens, isNot(contains('0x1f9fdf02')));
    expect(tokens, isNot(contains('0x339fdf02')));
    expect(tokens, isNot(contains('0x409fdf02')));
  });

  test('owner subscription CTA uses charcoal and readable foreground', () {
    final screen = File(
      'lib/features/owner/screens/subscription_plans_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('backgroundColor: VSPColors.surfaceAlt,'));
    expect(screen, contains('foregroundColor: VSPColors.textPrimary,'));
    expect(screen, contains("_pendingAction == 'annual'"));
    expect(screen, contains("_pendingAction == 'monthly'"));
    expect(screen, contains("_pendingAction == 'trial'"));
  });
}
