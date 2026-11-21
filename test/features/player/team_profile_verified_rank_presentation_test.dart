import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_profile_hero_header.dart';

Team sampleTeam({int played=0,int points=0}) => Team(
  id:'sample-team', name:'Falcons', captainName:'Captain',
  captainImageUrl:'', date:'', stadium:'', pricePerPerson:0,
  currentPlayers:5, maxPlayers:5, matchesPlayed:played, points:points,
);

void main() {
  test('no match history must not create a rank or a synthetic progress badge', () {
    expect(TeamProfileHeroHeader.recordedPointsCaption(
        sampleTeam(), isArabic:true), isNull);
    expect(TeamProfileHeroHeader.recordedPointsCaption(
        sampleTeam(points:150), isArabic:false), isNull);
    expect(TeamProfileHeroHeader.recordedPointsCaption(
        sampleTeam(played:3, points:-1), isArabic:false), isNull);
    expect(TeamProfileHeroHeader.recordedPointsCaption(
        sampleTeam(played:2, points:12), isArabic:true),
        'نقاط الفريق المسجلة: 12');
    expect(TeamProfileHeroHeader.recordedPointsCaption(
        sampleTeam(played:2, points:12), isArabic:false),
        'Recorded team points: 12');
  });

  testWidgets('team header shows recorded points instead of invented tier rank',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: TeamProfileHeroHeader(team:sampleTeam(played:2,points:12),
          has1v1Champion:false),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recorded team points: 12'), findsOneWidget);
    expect(find.text('Falcons'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
