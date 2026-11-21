import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/config/challenge_result_rollout_flags.dart';

void main() {
  test('neutral match reporting is disabled in default builds', () {
    expect(ChallengeResultRolloutFlags.nonPlayedReportsEnabled, isFalse);
  });
}
