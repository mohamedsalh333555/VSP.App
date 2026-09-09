import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/tournament/tournament_bracket_engine.dart';
import 'package:vsp_application/core/repositories/tournament/tournament_payload_builder.dart';
import 'package:vsp_application/core/repositories/tournament/tournament_query_coordinator.dart';
import 'package:vsp_application/core/repositories/tournament_repository.dart';

void main() {
  group('TournamentBracketEngine Tests', () {
    test('computeBracketCapacity calculates powers of 2', () {
      expect(TournamentBracketEngine.computeBracketCapacity(2, 4), 4);
      expect(TournamentBracketEngine.computeBracketCapacity(5, 8), 8);
      expect(TournamentBracketEngine.computeBracketCapacity(8, 8), 8);
      expect(TournamentBracketEngine.computeBracketCapacity(9, 16), 16);
      expect(TournamentBracketEngine.computeBracketCapacity(17, 32), 32);
    });

    test('computeTotalRounds calculates correct binary tree rounds', () {
      expect(TournamentBracketEngine.computeTotalRounds(4), 2);
      expect(TournamentBracketEngine.computeTotalRounds(8), 3);
      expect(TournamentBracketEngine.computeTotalRounds(16), 4);
      expect(TournamentBracketEngine.computeTotalRounds(32), 5);
    });

    test('buildKnockoutMatchList generates bracket matches', () {
      final matches = TournamentBracketEngine.buildKnockoutMatchList(
        championshipId: 'c1',
        bracketCapacity: 4,
        slots: ['t1', 't2', 't3', 't4'],
        teamMap: {'t1': 'Team 1', 't2': 'Team 2', 't3': 'Team 3', 't4': 'Team 4'},
      );

      expect(matches.length, 3); // 2 semifinals + 1 final
    });

    test('buildLeagueMatchList generates round-robin pairs', () {
      final matches = TournamentBracketEngine.buildLeagueMatchList(
        championshipId: 'c1',
        teamIds: ['t1', 't2', 't3', 't4'],
        teamMap: {'t1': 'Team 1', 't2': 'Team 2', 't3': 'Team 3', 't4': 'Team 4'},
        isTwoLegs: false,
      );

      // 4 teams -> n*(n-1)/2 = 6 matches
      expect(matches.length, 6);
    });

    test('buildGroupMatchList divides teams into groups and schedules matches', () {
      final matches = TournamentBracketEngine.buildGroupMatchList(
        championshipId: 'c1',
        teamIds: ['t1', 't2', 't3', 't4'],
        teamMap: {'t1': 'Team 1', 't2': 'Team 2', 't3': 'Team 3', 't4': 'Team 4'},
        numGroups: 2,
      );

      expect(matches.isNotEmpty, isTrue);
      for (final m in matches) {
        expect(m['group_name'], anyOf('A', 'B'));
      }
    });

    test('buildKnockoutFromQualifiedTeams generates cross-group fixtures', () {
      final qualified = [
        {'id': 't1', 'name': 'Team 1', 'group': 'A'},
        {'id': 't2', 'name': 'Team 2', 'group': 'B'},
        {'id': 't3', 'name': 'Team 3', 'group': 'A'},
        {'id': 't4', 'name': 'Team 4', 'group': 'B'},
      ];

      final matches = TournamentBracketEngine.buildKnockoutFromQualifiedTeams(
        championshipId: 'c1',
        qualifiedTeams: qualified,
      );

      expect(matches.isNotEmpty, isTrue);
    });
  });

  group('TournamentPayloadBuilder Tests', () {
    test('buildCreatePayload maps snake_case and default values', () {
      final raw = {
        'name': 'Ramadan Cup',
        'sportType': 'Football',
        'entryFee': 250,
        'maxTeams': 16,
      };

      final payload = TournamentPayloadBuilder.buildCreatePayload(
        raw,
        isAdminApproved: true,
        fallbackOwnerId: 'owner_123',
      );

      expect(payload['name'], 'Ramadan Cup');
      expect(payload['sport_type'], 'Football');
      expect(payload['entry_fee'], 250);
      expect(payload['max_teams'], 16);
      expect(payload['is_approved'], isTrue);
      expect(payload['owner_id'], 'owner_123');
    });

    test('buildUpdatePayload handles empty or partial updates', () {
      expect(TournamentPayloadBuilder.buildUpdatePayload({}), isEmpty);

      final updated = TournamentPayloadBuilder.buildUpdatePayload({
        'name': 'Updated Cup',
        'grandPrize': 5000,
      });

      expect(updated['name'], 'Updated Cup');
      expect(updated['grand_prize'], 5000);
    });
  });

  group('TournamentQueryCoordinator Tests', () {
    test('parseChampionshipsList applies filters', () {
      final coordinator = TournamentQueryCoordinator();
      final rawList = [
        {
          'id': 'c1',
          'name': 'Cairo League',
          'governorate': 'Cairo',
          'sport_type': 'Football',
          'is_approved': true,
          'owner_id': 'o1',
          'max_teams': 8,
          'entry_fee': 100,
          'status': 'open',
          'format': 'League',
        },
        {
          'id': 'c2',
          'name': 'Giza Cup',
          'governorate': 'Giza',
          'sport_type': 'Basketball',
          'is_approved': false,
          'owner_id': 'o2',
          'max_teams': 8,
          'entry_fee': 0,
          'status': 'open',
          'format': 'Cup',
        },
      ];

      // Non-owner filter should only return approved
      final approvedOnly = coordinator.parseChampionshipsList(rawList, isOwner: false);
      expect(approvedOnly.length, 1);
      expect(approvedOnly.first.id, 'c1');

      // Owner filter allows unapproved
      final ownerList = coordinator.parseChampionshipsList(
        rawList,
        isOwner: true,
        ownerId: 'o2',
      );
      expect(ownerList.length, 1);
      expect(ownerList.first.id, 'c2');
    });
  });

  group('TournamentRepository Facade Tests', () {
    test('instantiates cleanly with lazy clients', () {
      final repo = TournamentRepository();
      expect(repo, isNotNull);
      expect(repo.statsCoord, isNotNull);
      expect(repo.rosterCoord, isNotNull);
      expect(repo.registrationCoord, isNotNull);
      expect(repo.matchCoord, isNotNull);
      expect(repo.fixtureCoord, isNotNull);
    });
  });
}
