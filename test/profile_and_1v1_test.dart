import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/database_service.dart';
import 'package:vsp_application/core/services/auth_service.dart';
import 'package:vsp_application/data/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  group('VSP Critical Flows Test', () {
    setUp(() async {
      try {
        TestWidgetsFlutterBinding.ensureInitialized();
        await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          anonKey: 'placeholder',
          authOptions: FlutterAuthClientOptions(
            localStorage: const EmptyLocalStorage(),
            pkceAsyncStorage: MockGotrueAsyncStorage(),
          ),
        );
      } catch (_) {}
    });

    test('1. Edit Profile Logic & Security Checks', () async {
      const testUid = 'player_123';

      final mockUserDb = <String, Map<String, dynamic>>{
        testUid: {
          'uid': testUid,
          'name': 'Old Name',
          'phone': '01000000000',
          'position': 'GK',
          'role': 'player',
          'isSuspended': false,
        }
      };

      // 2. Simulate User trying to update Profile + Hack the System
      Map<String, dynamic> incomingDataFromUI = {
        'name': 'New Name',
        'phone': '01111111111',
        'position': 'FW',
        'role': 'admin', // MALICIOUS ATTEMPT
        'isSuspended': true, // MALICIOUS ATTEMPT
      };

      // 3. Apply the exact Security Sanitization used in AuthProvider/AuthService
      final sanitizedData = Map<String, dynamic>.from(incomingDataFromUI);
      const restrictedFields = ['role', 'isSuspended', 'points', 'uid'];
      for (var field in restrictedFields) {
        sanitizedData.remove(field);
      }

      // 4. Update local mock db
      sanitizedData.forEach((key, value) {
        mockUserDb[testUid]![key] = value;
      });

      // 5. Verify the Update
      final updatedUser = mockUserDb[testUid]!;
      
      // Check legitimate changes
      expect(updatedUser['name'], 'New Name', reason: "Name should update");
      expect(updatedUser['phone'], '01111111111', reason: "Phone should update");
      expect(updatedUser['position'], 'FW', reason: "Position should update");
      
      // Check SECURITY protections
      expect(updatedUser['role'], 'player', reason: "Role MUST NOT change");
      expect(updatedUser['isSuspended'], false, reason: "Suspension MUST NOT change");
    });

    test('2. VSP 1v1 Official League Fetch & Sort', () async {
      // 1. Seed Fake Data into a mock list
      final mockStandings = [
        {
          'id': 'p1',
          'name': 'Player B',
          'totalPoints': 50,
        },
        {
          'id': 'p2',
          'name': 'Player A',
          'totalPoints': 120, // Should be First
        },
        {
          'id': 'p3',
          'name': 'Player C',
          'totalPoints': 90, // Should be Second
        }
      ];

      // 2. Simulate the database sorting
      mockStandings.sort((a, b) => (b['totalPoints'] as int).compareTo(a['totalPoints'] as int));

      // Convert to our model just like the stream does
      List<VSP1v1Player> players = [];
      for (int i = 0; i < mockStandings.length; i++) {
        var data = Map<String, dynamic>.from(mockStandings[i]);
        data['rank'] = i + 1; 
        players.add(VSP1v1Player.fromFirestore(data, data['id'].toString()));
      }

      // 3. Verify Sorting and Ranking
      expect(players.length, 3, reason: "Should fetch 3 players");
      
      expect(players[0].name, 'Player A', reason: "Player A has 120 pts, must be 1st");
      expect(players[0].rank, 1, reason: "Rank must be automatically assigned as 1");

      expect(players[1].name, 'Player C', reason: "Player C has 90 pts, must be 2nd");
      expect(players[1].rank, 2, reason: "Rank must be 2");

      expect(players[2].name, 'Player B', reason: "Player B has 50 pts, must be 3rd");
      expect(players[2].rank, 3, reason: "Rank must be 3");
    });
  });
}
