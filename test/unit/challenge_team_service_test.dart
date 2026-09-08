import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/services/challenge_team_service.dart';

void main() {
  group('ChallengeTeamService Unit Tests', () {
    Team createMockTeam({required int fairPlay}) {
      return Team(
        id: 'team_1',
        name: 'Thunder FC',
        captainName: 'Captain Tsubasa',
        captainImageUrl: '',
        logoUrl: '',
        date: '2026-09-09',
        stadium: 'Cairo Stadium',
        pricePerPerson: 50,
        currentPlayers: 5,
        maxPlayers: 10,
        fairPlayScore: fairPlay,
      );
    }

    test('isFairPlayEligible enforces minimum score threshold of 40', () {
      expect(ChallengeTeamService.isFairPlayEligible(createMockTeam(fairPlay: 100)), isTrue);
      expect(ChallengeTeamService.isFairPlayEligible(createMockTeam(fairPlay: 40)), isTrue);
      expect(ChallengeTeamService.isFairPlayEligible(createMockTeam(fairPlay: 39)), isFalse);
      expect(ChallengeTeamService.isFairPlayEligible(createMockTeam(fairPlay: 15)), isFalse);
      expect(ChallengeTeamService.isFairPlayEligible(null), isFalse);
    });

    test('evaluateH2HHype returns youDominate when user team has more wins', () {
      final hype = ChallengeTeamService.evaluateH2HHype(yourWins: 5, theirWins: 2);
      expect(hype, equals(H2HHypeType.youDominate));
    });

    test('evaluateH2HHype returns timeForRevenge when opponent has more wins', () {
      final hype = ChallengeTeamService.evaluateH2HHype(yourWins: 1, theirWins: 4);
      expect(hype, equals(H2HHypeType.timeForRevenge));
    });

    test('evaluateH2HHype returns seriesTied when wins are equal', () {
      final hype = ChallengeTeamService.evaluateH2HHype(yourWins: 3, theirWins: 3);
      expect(hype, equals(H2HHypeType.seriesTied));
    });
  });
}
