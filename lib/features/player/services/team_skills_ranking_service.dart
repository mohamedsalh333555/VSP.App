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
    if (value == null || !value.isFinite || value < 0 || value > 100) {
      throw const FormatException('Invalid verified Team Skills points');
    }
    return value;
  }

  /// Same competition rank for equal points: e.g. 1, 1, 3.
  static List<RankedTeamSkillsEntry> rank(List<Map<String, dynamic>> rows) {
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
        complete: row['all_stages_approved'] == true &&
            row['completed_stages']?.toString() == '12',
      ));
    }
    return output;
  }
}
