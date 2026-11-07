import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('result dialog owns failure feedback without duplicate snackbar', () {
    final actions = File(
      'lib/features/player/widgets/user_bookings/challenge_result_actions.dart',
    ).readAsStringSync();
    final modal = File(
      'lib/features/player/widgets/match_result_modal.dart',
    ).readAsStringSync();
    final start = actions.indexOf('Widget _openResultModal(');
    expect(start, greaterThanOrEqualTo(0));
    final callback = actions.substring(start);
    expect(callback, contains('if (success) {'));
    expect(callback, contains('VSPFeedback.showSuccess('));
    expect(callback, isNot(contains('ScaffoldMessenger.of(context).showSnackBar(')));
    expect(modal, contains('ScaffoldMessenger.of(context).showSnackBar('));
  });
}
