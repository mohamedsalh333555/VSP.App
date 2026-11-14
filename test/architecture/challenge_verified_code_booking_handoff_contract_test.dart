import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge booking receives its own verified code, never an old draft', () {
    final select = File(
      'lib/features/player/screens/challenge_select_team_screen.dart',
    ).readAsStringSync();
    final confirmation = File(
      'lib/features/player/screens/booking_confirmation_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();

    expect(select, contains('verifiedChallengeCode: verifiedCode'));
    expect(select, isNot(contains('context.read<BookingProvider>().updateDraft(')));
    expect(confirmation, contains('verifiedChallengeCode: _activeVerifiedChallengeCode'));
    expect(confirmation, contains('_activeVerifiedChallengeCode = null;'));
    expect(handler, contains('verifiedChallengeCode.trim().isEmpty'));
    expect(handler, contains('No verified challenge code.'));
    expect(handler, contains('challengeCode: bType == BookingType.challenge'));
    expect(handler, isNot(contains('bookingProvider.currentDraft?.challengeCode')));
  });
}
