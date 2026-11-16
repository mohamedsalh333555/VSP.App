import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/services/team_skills_ranking_service.dart';

void main() {
  test('ties share rank and incomplete stages never imply completion', () {
    final rows = [
      <String,dynamic>{'team_id':'team-z','points':'70.00','completed_stages':12,'all_stages_approved':true},
      <String,dynamic>{'team_id':'team-b','points':'78.00','completed_stages':12,'all_stages_approved':true},
      <String,dynamic>{'team_id':'team-a','points':'78.00','completed_stages':8,'all_stages_approved':false},
    ];
    final ranked = TeamSkillsRankingService.rank(rows);
    expect(ranked.map((r)=>r.data['team_id']).toList(),['team-a','team-b','team-z']);
    expect(ranked.map((r)=>r.rank).toList(),[1,1,3]);
    expect(ranked.map((r)=>r.complete).toList(),[false,true,true]);
    expect(rows.first['team_id'],'team-z',reason:'Display sorting must not mutate input');
  });

  test('rejects malformed or impossible server leaderboard values', () {
    for (final points in ['NaN','Infinity','-1','100.01','not-a-number']) {
      expect(
        ()=>TeamSkillsRankingService.rank([
          <String,dynamic>{'team_id':'bad','points':points,
            'completed_stages':12,'all_stages_approved':true},
        ]),
        throwsFormatException,
        reason: points,
      );
    }
    expect(TeamSkillsRankingService.rank([]),isEmpty);
  });
}
