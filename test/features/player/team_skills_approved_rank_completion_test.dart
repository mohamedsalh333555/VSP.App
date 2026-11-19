import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/services/team_skills_ranking_service.dart';

void main() {
  test('server approval governs completion, not a fabricated twelve-stage cap', () {
    final ranking = TeamSkillsRankingService.rank([
      {'team_id': 'team-a', 'points': 84, 'completed_stages': 10,
        'all_stages_approved': true},
      {'team_id': 'team-b', 'points': 72, 'completed_stages': 13,
        'all_stages_approved': true},
      {'team_id': 'team-c', 'points': 25, 'completed_stages': 12,
        'all_stages_approved': false},
    ]);
    expect(ranking.map((r) => r.rank), [1, 2, 3]);
    expect(ranking[0].complete, isTrue);
    expect(ranking[1].complete, isTrue);
    expect(ranking[2].complete, isFalse);
  });
}
