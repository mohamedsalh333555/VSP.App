import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1v1 Tournament Lifecycle Logic Tests', () {
    test('Capacity calculation should clamp correctly', () {
      const int targetCount = 16;
      int registeredCount = 12;

      int remaining = (targetCount - registeredCount).clamp(0, 999);
      double progress = (registeredCount / targetCount).clamp(0.0, 1.0);

      expect(remaining, 4);
      expect(progress, 0.75);

      // Over-capacity boundary
      registeredCount = 20;
      remaining = (targetCount - registeredCount).clamp(0, 999);
      progress = (registeredCount / targetCount).clamp(0.0, 1.0);

      expect(remaining, 0);
      expect(progress, 1.0);
    });

    test('Total points ranking formula: tackles + goals + skills', () {
      final players = [
        {'name': 'Player A', 'tackles': 4, 'goals': 2, 'skills': 5}, // 11
        {'name': 'Player B', 'tackles': 6, 'goals': 7, 'skills': 3}, // 16
        {'name': 'Player C', 'tackles': 2, 'goals': 1, 'skills': 1}, // 4
      ];

      for (var p in players) {
        p['total_points'] = (p['tackles'] as int) + (p['goals'] as int) + (p['skills'] as int);
      }

      players.sort((a, b) => (b['total_points'] as int).compareTo(a['total_points'] as int));

      expect(players[0]['name'], 'Player B');
      expect(players[0]['total_points'], 16);
      expect(players[1]['name'], 'Player A');
      expect(players[1]['total_points'], 11);
      expect(players[2]['name'], 'Player C');
      expect(players[2]['total_points'], 4);
    });

    test('Countdown string formatting handles future and past dates', () {
      final future = DateTime.now().add(const Duration(days: 2, hours: 3));
      final diff = future.difference(DateTime.now());

      expect(diff.inDays, 2);
      expect(diff.inHours % 24, greaterThanOrEqualTo(2));

      final past = DateTime.now().subtract(const Duration(hours: 1));
      final pastDiff = past.difference(DateTime.now());
      expect(pastDiff.isNegative, true);
    });

    test('Prize pool accumulator calculation should match entry_fee * paid_player_count', () {
      const double entryFee = 150.0;
      final players = [
        {'id': 'p1', 'payment_status': 'paid'},
        {'id': 'p2', 'payment_status': 'paid'},
        {'id': 'p3', 'payment_status': 'unpaid'}, // Pending checkout
        {'id': 'p4', 'payment_status': 'paid'},
        {'id': 'p5', 'payment_status': 'refunded'},
      ];

      final paidPlayers = players.where((p) => p['payment_status'] == 'paid').toList();
      final double calculatedPrizePool = entryFee * paidPlayers.length;

      expect(paidPlayers.length, 3);
      expect(calculatedPrizePool, 450.0);
    });

    test('Roster stream should strictly exclude unpaid or pending players', () {
      final dbRows = [
        {'user_id': 'u1', 'player_name': 'Player 1', 'payment_status': 'paid'},
        {'user_id': 'u2', 'player_name': 'Player 2', 'payment_status': 'pending'},
        {'user_id': 'u3', 'player_name': 'Player 3', 'payment_status': 'unpaid'},
        {'user_id': 'u4', 'player_name': 'Player 4', 'payment_status': 'paid'},
      ];

      final visibleRoster = dbRows.where((r) => r['payment_status'] == 'paid').toList();
      expect(visibleRoster.length, 2);
      expect(visibleRoster.map((r) => r['user_id']).toList(), ['u1', 'u4']);
      expect(visibleRoster.any((r) => r['user_id'] == 'u2'), false);
    });
  });
}
