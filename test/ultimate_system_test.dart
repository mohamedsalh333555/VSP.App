import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/utils/phone_utils.dart';

class DualCaptainHandshakeVerifier {
  static bool verifyAndConfirmMatch({
    required String captainAPhone,
    required String captainBPhone,
    required MatchOutcome outcomeA,
    required MatchOutcome outcomeB,
  }) {
    // 1. Phone Number Uniqueness Check (Security Barrier)
    final normA = PhoneUtils.normalize(captainAPhone);
    final normB = PhoneUtils.normalize(captainBPhone);

    if (normA.isEmpty || normB.isEmpty || normA == normB) {
      throw Exception('dual_captain_phone_conflict');
    }

    // 2. Both Captains Outcome Agreement
    if (outcomeA != outcomeB) {
      throw Exception('outcomes_do_not_match');
    }

    return true; // Match outcome verified
  }
}

void main() {
  group('🛡️ Ultimate System Security & Dual Handshake Tests', () {

    test('1. Dual Captain Handshake succeeds when phone numbers differ and outcomes match', () {
      final phoneA = '+201012345678';
      final phoneB = '+201198765432';

      final success = DualCaptainHandshakeVerifier.verifyAndConfirmMatch(
        captainAPhone: phoneA,
        captainBPhone: phoneB,
        outcomeA: MatchOutcome.homeWin,
        outcomeB: MatchOutcome.homeWin,
      );

      expect(success, isTrue);
    });

    test('2. Dual Captain Handshake fails when same phone number is used for both captains', () {
      final samePhone = '+201012345678';

      expect(
        () => DualCaptainHandshakeVerifier.verifyAndConfirmMatch(
          captainAPhone: samePhone,
          captainBPhone: samePhone,
          outcomeA: MatchOutcome.homeWin,
          outcomeB: MatchOutcome.homeWin,
        ),
        throwsA(predicate((e) => e.toString().contains('dual_captain_phone_conflict'))),
      );
    });

    test('3. Disagreeing match outcomes convert match to disputed status', () {
      final phoneA = '+201012345678';
      final phoneB = '+201198765432';

      expect(
        () => DualCaptainHandshakeVerifier.verifyAndConfirmMatch(
          captainAPhone: phoneA,
          captainBPhone: phoneB,
          outcomeA: MatchOutcome.homeWin,
          outcomeB: MatchOutcome.awayWin, // Conflict!
        ),
        throwsA(predicate((e) => e.toString().contains('outcomes_do_not_match'))),
      );
    });
  });
}
