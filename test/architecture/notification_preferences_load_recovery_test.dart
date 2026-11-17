import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preferences never reuse old account switches on load error', () {
    final source = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    final switchStart = source.indexOf('if (_settingsUserId != userId) {');
    final reset = source.indexOf('_resetNotificationSettings();', switchStart);
    final load = source.indexOf('_loadSettings(userId);', switchStart);
    expect(switchStart, greaterThan(0));
    expect(reset, greaterThan(switchStart));
    expect(reset, lessThan(load));
    final catchStart = source.indexOf('} catch (_) {', source.indexOf('Future<void> _loadSettings'));
    final loadError = source.indexOf('_settingsLoadFailed = true;', catchStart);
    final finish = source.indexOf('setState(() => _isLoading = false);', loadError);
    expect(loadError, greaterThan(catchStart));
    expect(finish, greaterThan(loadError));
    expect(source, contains('state: VSPUiState.error'));
    expect(source, contains('onRetry: () {'));
    expect(source, contains('if (!mounted || userId == null || userId.isEmpty) return;'));
  });

  test('preferences are reloaded for the same account on retry', () {
    final source = File(
      'lib/features/player/screens/profile_subscreens/notifications_screen.dart',
    ).readAsStringSync();
    final retry = source.indexOf('onRetry: () {');
    final loading = source.indexOf('_isLoading = true;', retry);
    final reload = source.indexOf('_loadSettings(userId);', retry);
    expect(retry, greaterThan(0));
    expect(loading, greaterThan(retry));
    expect(reload, greaterThan(loading));
  });
}
