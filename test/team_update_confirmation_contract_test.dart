import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team update success feedback requires server confirmation', () {
    final source = File(
      'lib/features/player/widgets/my_team/my_team_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> handleUpdateTeam(');
    final end = source.indexOf('// ── Required overrides', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final method = source.substring(start, end);
    final update = method.indexOf('final updated = await TeamRepository().updateTeam(');
    final guard = method.indexOf('if (!updated)');
    final success = method.indexOf('l10n.teamUpdatedSuccess');
    expect(update, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(update));
    expect(success, greaterThan(guard));
    expect(method, contains("throw StateError('Team update was not confirmed by the server')"));
  });
}
