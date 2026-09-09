import 'dart:math';
import '../../../../data/models.dart';

/// Pure bracket-round computation logic, extracted from
/// [showTournamentBracketPreviewDialog] for testability.
class TournamentBracketBuilder {
  /// Builds the list of rounds for a bracket preview given [teams].
  ///
  /// Returns an empty list when fewer than 2 teams are provided.
  /// Each round is a list of match maps with `'home'` and `'away'` keys.
  static List<List<Map<String, String>>> buildRounds(List<Team> teams) {
    final int totalTeams = teams.length;
    if (totalTeams < 2) return [];

    int targetP2 = 1;
    while (targetP2 * 2 <= totalTeams) {
      targetP2 *= 2;
    }
    final int totalBracketRounds = (log(targetP2) / log(2)).round();
    final int numOpeningMatches = totalTeams - targetP2;
    final int numTeamsR0 = numOpeningMatches * 2;

    final List<List<Map<String, String>>> rounds = [];
    final previewTeams = List<Team>.from(teams);

    if (numOpeningMatches > 0) {
      final List<Map<String, String>> r0 = [];
      for (int m = 0; m < numOpeningMatches; m++) {
        r0.add({
          'home': previewTeams[m * 2].name,
          'away': previewTeams[m * 2 + 1].name,
        });
      }
      rounds.add(r0);
    }

    final List<Map<String, String>> r1 = [];
    final int matchCountR1 = targetP2 ~/ 2;
    for (int m = 0; m < matchCountR1; m++) {
      String homeName = '';
      String awayName = '';

      final int slotH = m * 2;
      if (slotH < numOpeningMatches) {
        homeName = 'فائز مـ ${slotH + 1} (R0)';
      } else {
        final int byeIndex = slotH - numOpeningMatches + numTeamsR0;
        homeName = byeIndex < totalTeams ? previewTeams[byeIndex].name : 'BYE';
      }

      final int slotA = m * 2 + 1;
      if (slotA < numOpeningMatches) {
        awayName = 'فائز مـ ${slotA + 1} (R0)';
      } else {
        final int byeIndex = slotA - numOpeningMatches + numTeamsR0;
        awayName = byeIndex < totalTeams ? previewTeams[byeIndex].name : 'BYE';
      }

      r1.add({'home': homeName, 'away': awayName});
    }
    rounds.add(r1);

    for (int r = 2; r <= totalBracketRounds; r++) {
      final List<Map<String, String>> rx = [];
      final int matchCount = targetP2 ~/ pow(2, r);
      for (int m = 0; m < matchCount; m++) {
        rx.add({
          'home': 'فائز مـ ${m * 2 + 1}',
          'away': 'فائز مـ ${m * 2 + 2}',
        });
      }
      rounds.add(rx);
    }

    return rounds;
  }
}
