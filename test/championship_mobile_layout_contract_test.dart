import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared segmented tabs never wrap into vertical circles', () {
    final source = File('lib/core/ui/components/vsp_segmented_control.dart')
        .readAsStringSync();
    expect(source, contains('child: Row('));
    expect(source, isNot(contains('wrapActions')));
    expect(source, isNot(contains('FractionallySizedBox(')));
  });

  test('owner and player championship filters share a single style', () {
    for (final path in [
      'lib/features/owner/widgets/tournament/cups/cups_filter_dropdowns.dart',
      'lib/features/player/screens/champion_screen.dart',
    ]) {
      expect(File(path).readAsStringSync(),
          contains('VSPFilterDropdown<String>('));
    }
    final shared = File('lib/core/ui/components/vsp_filter_dropdown.dart')
        .readAsStringSync();
    expect(shared, contains('height: 44'));
    expect(shared, contains('VSPColors.surface'));
    expect(shared, contains('VSPRadius.md'));
  });

  test('owner tournament add button clears the navigation bar', () {
    final source = File('lib/features/owner/screens/owner_cup_screen.dart')
        .readAsStringSync();
    expect(source, contains('fabBottomOffset + 28'));
  });
}
