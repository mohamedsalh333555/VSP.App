import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team creation ignores repeated taps while submitting', () {
    final source = File(
      'lib/features/player/widgets/create_team_sheet.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _handleCreateTeam() async {');
    final end = source.indexOf('final name = _nameController.text.trim();', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(source.substring(start, end), contains('if (_isSubmitting) return;'));
  });

  test('team picker cannot select more than eleven players plus captain', () {
    final source = File(
      'lib/features/player/widgets/create_team_sheet.dart',
    ).readAsStringSync();
    expect(source, contains('if (_teamMembers.length >= 11) return;'));
    expect(source, contains('if (_teamMembers.length + 1 >= 12) break;'));
  });
}
