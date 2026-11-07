import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result modal blocks unrelated teams before callback invocation', () {
    final source = File(
      'lib/features/player/widgets/match_result_modal.dart',
    ).readAsStringSync();
    expect(source, contains('bool get _isParticipatingTeam =>'));
    expect(source, contains('widget.submittingTeamId == widget.booking.playerTeamId'));
    expect(source, contains('widget.submittingTeamId == widget.booking.opponentTeamId'));
    expect(source, contains('_selectedIndex == -1 || _isSubmitting || !_isParticipatingTeam'));
    expect(source, contains('if (_isSubmitting || _selectedIndex == -1 || !_isParticipatingTeam) return;'));
  });
}
