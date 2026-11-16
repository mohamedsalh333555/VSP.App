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

  /// Only acknowledge a trusted, booking-scoped server response. A network
  /// round trip, malformed map or success flag with a different booking ID
  /// must never create a "match result recorded" or "matchup closed" toast.
  static bool isConfirmedMutationReceipt(
    Object? raw, {
    required String bookingId,
    bool requireResultId = false,
  }) {
    if (raw is! Map || raw['success'] != true ||
        raw['booking_id']?.toString() != bookingId) return false;
    if (requireResultId) {
      final resultId = raw['result_id'];
      if (resultId is! String || resultId.trim().isEmpty) return false;
    }
    return true;
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
    } else if (outcome == 'draw') {
      return MatchupOutcomePresentation(
        text: isArabic ? 'تعادل' : 'Draw',
        color: VSPColors.warning,
      );
    }
    return MatchupOutcomePresentation(
      text: isArabic ? 'النتيجة غير متاحة' : 'Result unavailable',
      color: VSPColors.warning,
    );
  }
}
