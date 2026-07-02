import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class StatsService {
  /// Aggregates stats for a specific player
  Future<Map<String, dynamic>> getPlayerStats(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('status', 'completed');

      final bookings = (response as List)
          .map((doc) => Booking.fromFirestore(doc, doc['id'].toString()))
          .where((booking) => booking.joinedUserIds.contains(userId))
          .toList();

      if (bookings.isEmpty) {
        return {
          'winRate': '0.0',
          'favoriteStadium': 'No matches yet',
          'matchesPlayed': 0,
        };
      }

      int wins = 0;
      int challengeMatchesCount = 0;
      Map<String, int> stadiumCounts = {};

      for (final booking in bookings) {
        // Track Favorite Stadium
        stadiumCounts[booking.stadiumName] = (stadiumCounts[booking.stadiumName] ?? 0) + 1;

        // Track Wins (if they are challenge matches)
        if (booking.bookingType == BookingType.challenge) {
          challengeMatchesCount++;
          final isHome = booking.playerTeamId != null && booking.joinedUserIds.contains(userId); 
          
          if (booking.finalOutcome != null) {
            if (isHome && booking.finalOutcome == MatchOutcome.homeWin) {
              wins++;
            } else if (!isHome && booking.finalOutcome == MatchOutcome.awayWin) {
              wins++;
            }
          }
        }
      }

      // Find top stadium
      String favStadium = 'None';
      int maxCount = 0;
      stadiumCounts.forEach((name, count) {
        if (count > maxCount) {
          maxCount = count;
          favStadium = name;
        }
      });

      final winRate = challengeMatchesCount > 0 ? (wins / challengeMatchesCount) * 100 : 0.0;

      return {
        'winRate': winRate.toStringAsFixed(1),
        'favoriteStadium': favStadium,
        'matchesPlayed': bookings.length,
      };
    } catch (e) {
      print('Error calculating stats: $e');
      return {
        'winRate': '0.0',
        'favoriteStadium': 'Error',
        'matchesPlayed': 0,
      };
    }
  }

  /// Calculates radar chart data based on position and Elo
  Map<String, double> getSkillMetrics(String? position, int elo) {
    // Basic logic to generate 5-6 points for a radar chart
    // Pace, Shooting, Passing, Dribbling, Defending, Physical
    
    double pace = 60 + (elo / 100);
    double shooting = 50 + (elo / 120);
    double passing = 55 + (elo / 110);
    double dribbling = 50 + (elo / 130);
    double defending = 40 + (elo / 150);
    double physical = 60 + (elo / 100);

    // Bias based on position
    switch (position?.toUpperCase()) {
      case 'ST':
      case 'CF':
        shooting += 20; pace += 10; defending -= 20;
        break;
      case 'GK':
        defending += 40; passing += 10; pace -= 20; shooting -= 30;
        break;
      case 'DEF':
      case 'CB':
        defending += 30; physical += 20; shooting -= 20;
        break;
      case 'MID':
      case 'CM':
        passing += 25; dribbling += 15;
        break;
    }

    // Clamp to 0-100
    return {
      'PAC': pace.clamp(30, 99),
      'SHO': shooting.clamp(30, 99),
      'PAS': passing.clamp(30, 99),
      'DRI': dribbling.clamp(30, 99),
      'DEF': defending.clamp(30, 99),
      'PHY': physical.clamp(30, 99),
    };
  }
}
