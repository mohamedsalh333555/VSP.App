import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:vsp_application/core/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vsp_application/core/repositories/match_repository.dart';
import 'package:vsp_application/core/repositories/team_repository.dart';
import 'package:vsp_application/core/repositories/tournament_repository.dart';

void main() {
  group('Tournament System Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService dbService;

    // تجهيز البيئة قبل كل اختبار
    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      dbService = DatabaseService(firestore: fakeFirestore);
    });

    test('Full Tournament Lifecycle: Generate -> Play -> Qualify', () async {
      // 1. Setup: Create a Championship with 4 Teams
      // (Using 4 teams means: Round of 4 -> Final)
      
      // Create Dummy Teams
      await fakeFirestore.collection('teams').doc('t1').set({'name': 'Team A'});
      await fakeFirestore.collection('teams').doc('t2').set({'name': 'Team B'});
      await fakeFirestore.collection('teams').doc('t3').set({'name': 'Team C'});
      await fakeFirestore.collection('teams').doc('t4').set({'name': 'Team D'});

      // Create Championship
      await fakeFirestore.collection('championships').doc('champ1').set({
        'name': 'Test Cup',
        'joinedTeams': ['t1', 't2', 't3', 't4'],
        'maxTeams': 4,
        'status': 'open',
        'type': 'Cup',
        'sportType': 'Football',
        'logoUrl': '',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.now(),
        'entryFee': 0,
        'grandPrize': 0,
        'ownerId': 'owner1',
        'governorate': 'Cairo',
      });

      // // print('🔹 Step 1: Championship Created with 4 Teams.');

      // 2. Action: Generate Fixtures
      await dbService.generateFixtures('champ1');
      // // print('🔹 Step 2: Fixtures Generated.');

      // 3. Verification: Check Matches Count
      // With 4 teams, we expect 3 matches total (2 semis, 1 final)
      final matchesSnap = await fakeFirestore.collection('tournament_matches').get();
      expect(matchesSnap.docs.length, 3, reason: "Should generate exactly 3 matches for 4 teams");
      
      // Verify Round 1 (Semis) has 2 matches
      final round1Matches = matchesSnap.docs.where((m) => m['roundIndex'] == 1).toList();
      expect(round1Matches.length, 2, reason: "Round 1 (Semis) should have 2 matches");

      // Verify Round 0 (Final) has 1 match and is empty
      final finalMatchDoc = matchesSnap.docs.firstWhere((m) => m['roundIndex'] == 0);
      expect(finalMatchDoc['homeTeamId'], isNull, reason: "Final match should be empty initially");

      // // print('✅ Fixture Generation Test Passed.');

      // 4. Action: Play Match 1 (Team A vs Team B)
      // Let's find the match where t1 is playing
      final match1 = round1Matches.firstWhere((m) => m['homeTeamId'] == 't1' || m['awayTeamId'] == 't1');
      final String match1Id = match1.id;
      
      // // print('🔹 Step 3: Simulating Match 1 (Winner: Team A)...');
      
      // Assume Team A (t1) wins 3-0
      await dbService.updateTournamentMatchScore(
        matchId: match1Id,
        homeScore: 3,
        awayScore: 0,
        winnerId: 't1',
        winnerName: 'Team A',
      );

      // 5. Verification: Check Progression
      // The winner (t1) should now appear in the Final Match (Round 0)
      final finalMatchUpdated = await fakeFirestore.collection('tournament_matches').doc(finalMatchDoc.id).get();
      
      // Determine expected slot (Home or Away based on index logic)
      final bool isHomeSlot = finalMatchUpdated['homeTeamId'] == 't1';
      final bool isAwaySlot = finalMatchUpdated['awayTeamId'] == 't1';

      expect(isHomeSlot || isAwaySlot, true, reason: "Winner T1 should be moved to the Final Match");
      
      // // print('✅ Progression Test Passed: Team A is in the Final!');
    });
  });
}
