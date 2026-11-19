/// Display-only ranking over server-approved Team Skills leaderboard rows.
/// A rank does not grant a title; official awards come exclusively from
/// team_skills_awards after server-side approval.
class RankedTeamSkillsEntry {
  final Map<String, dynamic> data;
  final int rank;
  final bool complete;

  const RankedTeamSkillsEntry({
    required this.data,
    required this.rank,
    required this.complete,
  });
}

abstract final class TeamSkillsRankingService {
  static double _points(Map<String, dynamic> row) {
    final value = double.tryParse(row['points']?.toString() ?? '');
    // Staging SQL allows 0–25 points PER approved stage. Competitions
    // configure their own number of stages; a global 100-point ceiling
    // rejects legitimate 10–13-stage tournaments and larger totals.
    final stages = row['completed_stages'];
    if (stages is! int || stages < 0 ||
        value == null || !value.isFinite || value < 0 ||
        value > stages * 25) {
      throw const FormatException('Invalid verified Team Skills points');
    }
    return value;
  }

  /// Same competition rank for equal points: e.g. 1, 1, 3.
  static List<RankedTeamSkillsEntry> rank(List<Map<String, dynamic>> rows) {
    // One public row per team. Duplicates or missing IDs can fabricate a
    // rank/placement; fail closed rather than showing contradictory awards.
    final seen = <String>{};
    for (final row in rows) {
      final id = row['team_id'];
      if (id is! String || id.trim().isEmpty || !seen.add(id.trim())) {
        throw const FormatException('Invalid Team Skills ranking identity');
      }
      final completed = row['completed_stages'];
      if (completed != null && (completed is! int || completed < 0)) {
        throw const FormatException('Invalid Team Skills stage count');
      }
      final approved = row['all_stages_approved'];
      if (approved != null && approved is! bool) {
        throw const FormatException('Invalid Team Skills approval flag');
      }
      _points(row);
    }
    final ordered = List<Map<String, dynamic>>.of(rows)
      ..sort((a, b) {
        final score = _points(b).compareTo(_points(a));
        if (score != 0) return score;
        return (a['team_id']?.toString() ?? '')
            .compareTo(b['team_id']?.toString() ?? '');
      });
    final output = <RankedTeamSkillsEntry>[];
    double? previous;
    var currentRank = 0;
    for (var i = 0; i < ordered.length; i++) {
      final row = ordered[i];
      final score = _points(row);
      if (previous == null || score != previous) currentRank = i + 1;
      previous = score;
      output.add(RankedTeamSkillsEntry(
        data: row,
        rank: currentRank,
        // The verified server view is the authority for stage completion:
        // valid competitions may have a different number of stages.
        complete: row['all_stages_approved'] == true,
      ));
    }
    return output;
  }
}
