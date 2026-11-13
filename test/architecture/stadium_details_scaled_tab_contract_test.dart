import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stadium detail tabs can grow rather than clipping scaled labels', () {
    final source = File(
      'lib/features/player/screens/stadium_details_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('Widget _buildTabItem(');
    final end = source.indexOf('  @override\n  Widget build(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final tabItem = source.substring(start, end);
    expect(tabItem, contains('constraints: const BoxConstraints(minHeight: 48)'));
    expect(tabItem, contains('padding: const EdgeInsets.symmetric('));
    expect(tabItem, contains('textAlign: TextAlign.center'));
    expect(tabItem, isNot(contains('height: 48,')));
    expect(tabItem, isNot(contains('maxLines: 1')));

    // Both the selected tab and the encompassing surface must allow the
    // row to grow with Arabic, English, or larger accessibility text.
    expect(
      'constraints: const BoxConstraints(minHeight: 48)'.allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      source,
      isNot(contains('child: Container(\n                  height: 48,')),
    );
    expect(source, contains('bottomNavigationBar: StadiumBottomBookingBar('));
  });
}
