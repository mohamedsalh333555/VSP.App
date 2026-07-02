import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:vsp_application/core/repositories/tournament_repository.dart';

class MockSupabaseHttpClient extends http.BaseClient {
  final Map<String, List<Map<String, dynamic>>> db = {
    'championships': [
      {
        'id': 'champ1',
        'name': 'Test Cup',
        'joined_teams': ['t1', 't2', 't3', 't4'],
        'max_teams': 4,
        'status': 'open',
        'type': 'Cup',
        'sport_type': 'Football'
      }
    ],
    'teams': [
      {'id': 't1', 'name': 'Team A', 'captain_name': 'Captain A', 'logo_url': ''},
      {'id': 't2', 'name': 'Team B', 'captain_name': 'Captain B', 'logo_url': ''},
      {'id': 't3', 'name': 'Team C', 'captain_name': 'Captain C', 'logo_url': ''},
      {'id': 't4', 'name': 'Team D', 'captain_name': 'Captain D', 'logo_url': ''},
    ],
    'team_members': [],
    'users': [],
    'tournament_matches': [],
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    final method = request.method;
    final path = uri.path;

    String responseBody = '[]';
    int statusCode = 200;

    if (method == 'GET') {
      if (path.contains('championships')) {
        responseBody = jsonEncode(db['championships']);
      } else if (path.contains('teams')) {
        final idMatch = uri.queryParameters['id'];
        if (idMatch != null && idMatch.startsWith('eq.')) {
          final id = idMatch.substring(3);
          final team = db['teams']!.firstWhere((t) => t['id'] == id, orElse: () => {});
          responseBody = jsonEncode(team.isEmpty ? [] : [team]);
        } else if (idMatch != null && idMatch.startsWith('in.')) {
          // Parse in.(t1,t2,t3,t4)
          final inContent = idMatch.substring(4, idMatch.length - 1);
          final ids = inContent.split(',');
          final matches = db['teams']!.where((t) => ids.contains(t['id'])).toList();
          responseBody = jsonEncode(matches);
        } else {
          responseBody = jsonEncode(db['teams']);
        }
      } else if (path.contains('team_members')) {
        responseBody = jsonEncode(db['team_members']);
      } else if (path.contains('users')) {
        responseBody = jsonEncode(db['users']);
      } else if (path.contains('tournament_matches')) {
        final idMatch = uri.queryParameters['id'];
        if (idMatch != null && idMatch.startsWith('eq.')) {
          final id = idMatch.substring(3);
          final match = db['tournament_matches']!.firstWhere((m) => m['id'] == id, orElse: () => {});
          responseBody = jsonEncode(match.isEmpty ? [] : [match]);
        } else {
          responseBody = jsonEncode(db['tournament_matches']);
        }
      }
    } else if (method == 'POST') {
      if (request is http.Request) {
        final data = jsonDecode(request.body);
        if (path.contains('tournament_matches')) {
          if (data is List) {
            db['tournament_matches']!.addAll(List<Map<String, dynamic>>.from(data));
          } else {
            db['tournament_matches']!.add(Map<String, dynamic>.from(data));
          }
          responseBody = jsonEncode(data);
        }
      }
    } else if (method == 'PATCH') {
      if (request is http.Request) {
        final data = jsonDecode(request.body);
        if (path.contains('championships')) {
          final idMatch = uri.queryParameters['id']?.substring(3);
          final champ = db['championships']!.firstWhere((c) => c['id'] == idMatch);
          champ.addAll(Map<String, dynamic>.from(data));
          responseBody = jsonEncode([champ]);
        } else if (path.contains('tournament_matches')) {
          final idMatch = uri.queryParameters['id']?.substring(3);
          final match = db['tournament_matches']!.firstWhere((m) => m['id'] == idMatch);
          match.addAll(Map<String, dynamic>.from(data));
          responseBody = jsonEncode([match]);
        } else if (path.contains('teams')) {
          final idMatch = uri.queryParameters['id']?.substring(3);
          final team = db['teams']!.firstWhere((t) => t['id'] == idMatch);
          team.addAll(Map<String, dynamic>.from(data));
          responseBody = jsonEncode([team]);
        }
      }
    }

    final bytes = utf8.encode(responseBody);
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      request: request,
      headers: {
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }
}

class MockGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async => _storage[key];

  @override
  Future<void> removeItem({required String key}) async => _storage.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async => _storage[key] = value;
}

void main() {
  group('Tournament System Tests', () {
    late MockSupabaseHttpClient mockHttpClient;
    late TournamentRepository tournamentRepo;

    setUp(() async {
      mockHttpClient = MockSupabaseHttpClient();
      try {
        TestWidgetsFlutterBinding.ensureInitialized();
        await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          anonKey: 'placeholder',
          httpClient: mockHttpClient,
          authOptions: FlutterAuthClientOptions(
            localStorage: const EmptyLocalStorage(),
            pkceAsyncStorage: MockGotrueAsyncStorage(),
          ),
        );
      } catch (_) {}
      tournamentRepo = TournamentRepository();
    });

    test('Full Tournament Lifecycle: Generate -> Play -> Qualify', () async {
      // 1. Action: Generate Fixtures
      await tournamentRepo.generateFixtures('champ1');

      // 2. Verification: Check Matches Count
      // With 4 teams, we expect 3 matches total (2 semis, 1 final)
      final matchesList = mockHttpClient.db['tournament_matches']!;
      expect(matchesList.length, 3, reason: "Should generate exactly 3 matches for 4 teams");
      
      // Verify Round 1 (Semis) has 2 matches
      final round1Matches = matchesList.where((m) => m['round_index'] == 1).toList();
      expect(round1Matches.length, 2, reason: "Round 1 (Semis) should have 2 matches");

      // Verify Round 0 (Final) has 1 match and is empty
      final finalMatchDoc = matchesList.firstWhere((m) => m['round_index'] == 0);
      expect(finalMatchDoc['home_team_id'], isNull, reason: "Final match should be empty initially");

      // 3. Action: Play Match 1 (Team A vs Team B)
      // Let's find the match where t1 is playing
      final match1 = round1Matches.firstWhere((m) => m['home_team_id'] == 't1' || m['away_team_id'] == 't1');
      final String match1Id = match1['id'];
      
      // Assume Team A (t1) wins 3-0
      await tournamentRepo.updateTournamentMatchScore(
        matchId: match1Id,
        homeScore: 3,
        awayScore: 0,
        winnerId: 't1',
        winnerName: 'Team A',
      );

      // 4. Verification: Check Progression
      // The winner (t1) should now appear in the Final Match (Round 0)
      final finalMatchUpdated = matchesList.firstWhere((m) => m['id'] == finalMatchDoc['id']);
      
      final bool isHomeSlot = finalMatchUpdated['home_team_id'] == 't1';
      final bool isAwaySlot = finalMatchUpdated['away_team_id'] == 't1';

      expect(isHomeSlot || isAwaySlot, true, reason: "Winner T1 should be moved to the Final Match");
    });
  });
}
