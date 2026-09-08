import '../../../data/models.dart';

/// Enum representing the competitive dynamic between two teams based on past matches.
enum H2HHypeType { youDominate, seriesTied, timeForRevenge }

/// Pure domain service for team selection, FairPlay safety checks, and H2H statistics evaluation.
class ChallengeTeamService {
  const ChallengeTeamService._();

  /// Minimum FairPlay score required to participate in challenges and matches.
  static const int minFairPlayScore = 40;

  /// Checks whether a team meets the minimum FairPlay threshold.
  static bool isFairPlayEligible(Team? team) {
    if (team == null) return false;
    return team.fairPlayScore >= minFairPlayScore;
  }

  /// Evaluates head-to-head statistics and determines the competitive sentiment.
  static H2HHypeType evaluateH2HHype({
    required int yourWins,
    required int theirWins,
  }) {
    if (yourWins > theirWins) {
      return H2HHypeType.youDominate;
    } else if (yourWins < theirWins) {
      return H2HHypeType.timeForRevenge;
    }
    return H2HHypeType.seriesTied;
  }
}
