import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';

void main() {
  group('VSP 1v1 Official League - Core Logic & Data Tests', () {
    
    test('1. Model Parsing: Tackles and Titles must be parsed correctly', () {
      // // print('🔹 Testing VSP1v1Player Model...');
      final mockData = {
        'name': 'Ahmed VIP',
        'totalPoints': 150,
        'skillPoints': 30,
        'goals': 10,
        'tackles': 5,
        'titles': 2,
        'trend': 'up'
      };

      final player = VSP1v1Player.fromFirestore(mockData, 'p1');

      expect(player.name, 'Ahmed VIP');
      expect(player.tackles, 5, reason: "Tackles must be parsed");
      expect(player.titles, 2, reason: "Titles must be parsed");
      // // print('✅ Model parsing is solid.');
    });

    test('2. Podium Split Logic (Safe Array Handling)', () {
      // // print('🔹 Testing Podium Splitting Logic...');
      final players = VSP1v1Player.getMockStandings(); // Returns 5 mock players
      
      // Simulating the UI logic
      final top3 = players.take(3).toList();
      final rest = players.skip(3).toList();

      expect(top3.length, 3, reason: "Podium must have exactly 3 players");
      expect(top3[0].rank, 1, reason: "First element must be Rank 1");
      expect(rest.length, 2, reason: "Remaining list must have the rest (2 players)");

      // Edge Case: What if there are only 2 players in the database?
      final smallList = players.take(2).toList();
      final top3Small = smallList.take(3).toList();
      final restSmall = smallList.skip(3).toList();

      expect(top3Small.length, 2, reason: "Must not crash if less than 3 players exist");
      expect(restSmall.length, 0, reason: "Rest list should be empty without crashing");
      
      // // print('✅ Podium split logic is crash-proof.');
    });
  });
}
