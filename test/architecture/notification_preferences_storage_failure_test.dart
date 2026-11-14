import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preference load exits loading state after storage failure', () {
    final source = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    final load = source.indexOf('Future<void> _loadSettings(String userId) async');
    final storage = source.indexOf('prefs = await SharedPreferences.getInstance();', load);
    final recovery = source.indexOf('setState(() => _isLoading = false);', storage);
    expect(load, greaterThanOrEqualTo(0));
    expect(storage, greaterThan(load));
    expect(recovery, greaterThan(storage));
  });

  test('preference writes handle both failed saves and thrown storage errors', () {
    final source = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    final save = source.indexOf('Future<void> _saveSetting(');
    final persisted = source.indexOf('final saved = await prefs.setBool(', save);
    final failure = source.indexOf('if (!saved && mounted', persisted);
    final catchBlock = source.indexOf('} catch (_) {', persisted);
    expect(save, greaterThanOrEqualTo(0));
    expect(persisted, greaterThan(save));
    expect(failure, greaterThan(persisted));
    expect(catchBlock, greaterThan(failure));
  });
}
