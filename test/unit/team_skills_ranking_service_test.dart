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

  test('dynamic phase totals above 100 are allowed when server-approved', () {
    final result = TeamSkillsRankingService.rank([
      {'team_id':'a','points':'310.00','completed_stages':13,'all_stages_approved':true},
      {'team_id':'b','points':250,'completed_stages':10,'all_stages_approved':true},
      {'team_id':'c','points':125,'completed_stages':5,'all_stages_approved':false},
    ]);
    expect(result.map((r)=>r.data['team_id']), ['a','b','c']);
    expect(result.first.rank,1);
    expect(result.first.complete,isTrue);
  });

  test('scores cannot exceed 25 points per approved stage', () {
    for (final row in [
      {'team_id':'a','points':25.01,'completed_stages':1},
      {'team_id':'b','points':0.01,'completed_stages':0},
      {'team_id':'c','points':325.01,'completed_stages':13},
      {'team_id':'d','points':100,'completed_stages':null},
      {'team_id':'e','points':50,'completed_stages':'2'},
    ]) {
      expect(()=>TeamSkillsRankingService.rank([row]),throwsFormatException);
    }
  });

  test('rejects malformed or impossible server leaderboard values', () {
    for (final points in ['NaN','Infinity','-1','300.01','not-a-number']) {
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
    const base = {'team_id':'team-a','points':55,'completed_stages':3};
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
