import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

/// Result outcome presentation metadata
class MatchupOutcomePresentation {
  final String text;
  final Color color;

  const MatchupOutcomePresentation({
    required this.text,
    required this.color,
  });
}

/// Domain service handling validation, formatting, and presentation logic for live matchup sessions.
class MatchupDashboardService {
  const MatchupDashboardService();

  /// Validates team selections before submitting a match result.
  /// Returns an error message if invalid, or null if valid.
  static String? validateResultSubmission({
    required String? teamAId,
    required String? teamBId,
    bool isArabic = true,
  }) {
    if (teamAId == null || teamBId == null) {
      return isArabic ? 'يرجى اختيار الفريقين المتنافسين' : 'Select both competing teams.';
    }
    if (teamAId == teamBId) {
      return isArabic ? 'لا يمكن تسجيل مباراة بين نفس الفريق' : 'A team cannot play against itself.';
    }
    return null;
  }

  /// Validates if a matchup can be closed.
  /// Requires at least one recorded match result.
  static bool canCloseMatchup(int resultsCount) {
    return resultsCount > 0;
  }

  /// Formats the outcome display text and color for a recorded match result.
  static MatchupOutcomePresentation getOutcomePresentation({
    required String outcome,
    required String teamAName,
    required String teamBName,
    bool isArabic = true,
  }) {
    if (outcome == 'team_a_win') {
      return MatchupOutcomePresentation(
        text: isArabic ? 'فوز $teamAName' : '$teamAName win',
        color: VSPColors.success,
      );
    } else if (outcome == 'team_b_win') {
      return MatchupOutcomePresentation(
        text: isArabic ? 'فوز $teamBName' : '$teamBName win',
        color: VSPColors.success,
      );
    } else {
      return MatchupOutcomePresentation(
        text: isArabic ? 'تعادل' : 'Draw',
        color: VSPColors.warning,
      );
    }
  }
}
