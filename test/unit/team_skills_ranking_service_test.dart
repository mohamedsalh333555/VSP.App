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
  test('no leaderboard rank is published for duplicate or invalid team identities', () {
    final base = <String, dynamic>{
      'team_id': 'team-a', 'points': '65',
      'completed_stages': 3, 'all_stages_approved': true,
    };
    expect(() => TeamSkillsRankingService.rank([base, {...base}]), throwsFormatException);
    expect(() => TeamSkillsRankingService.rank([{...base, 'team_id': ''}]), throwsFormatException);
    expect(() => TeamSkillsRankingService.rank([{...base, 'team_id': null}]), throwsFormatException);
    expect(() => TeamSkillsRankingService.rank([{...base, 'team_id': '  '}]), throwsFormatException);
  });

  test('malformed approval and stage-count values never imply finished stages', () {
    const base = {'team_id':'team-a','points':55};
    for (final stage in [-1, 3.5, '3']) {
      expect(() => TeamSkillsRankingService.rank([{...base, 'completed_stages':stage}]),
        throwsFormatException);
    }
    for (final approved in ['true', 1, 0]) {
      expect(() => TeamSkillsRankingService.rank([{...base, 'all_stages_approved':approved}]),
        throwsFormatException);
    }
    expect(TeamSkillsRankingService.rank([{...base}]).single.complete, false);
  });

}
