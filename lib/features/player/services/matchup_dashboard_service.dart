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
  }) {
    if (teamAId == null || teamBId == null) {
      return 'يرجى اختيار الفريقين المتنافسين';
    }
    if (teamAId == teamBId) {
      return 'لا يمكن تسجيل مباراة بين نفس الفريق';
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
  }) {
    if (outcome == 'team_a_win') {
      return MatchupOutcomePresentation(
        text: 'فوز $teamAName',
        color: VSPColors.success,
      );
    } else if (outcome == 'team_b_win') {
      return MatchupOutcomePresentation(
        text: 'فوز $teamBName',
        color: VSPColors.success,
      );
    } else {
      return const MatchupOutcomePresentation(
        text: 'تعادل',
        color: VSPColors.warning,
      );
    }
  }
}
