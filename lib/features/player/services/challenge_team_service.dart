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

  /// Normalize untrusted invite input without guessing which historical code
  /// format is still recognized by the server. Restrict the transport size and
  /// alphabet; all eligibility, expiry and consent checks remain server-side.
  static String? normalizeChallengeCode(String value) {
    final code = value.trim().toUpperCase();
    if (code.isEmpty || code.length > 32) return null;
    return RegExp(r'^[A-Z0-9-]+
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
).hasMatch(code) ? code : null;
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
