import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preferences load checks mounted before setState', () {
    final source = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    final load = source.indexOf('Future<void> _loadSettings() async {');
    final awaitPrefs = source.indexOf(
      'await SharedPreferences.getInstance()', load,
    );
    final mounted = source.indexOf('if (!mounted) return;', awaitPrefs);
    final update = source.indexOf('setState(() {', awaitPrefs);
    expect(load, greaterThanOrEqualTo(0));
    expect(mounted, greaterThan(awaitPrefs));
    expect(update, greaterThan(mounted));
  });
}
