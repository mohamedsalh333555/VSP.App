import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import 'logger_service.dart';

class StatsService {
  /// Aggregates stats for a specific player
  Future<Map<String, dynamic>> getPlayerStats(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('bookings')
          .select('id, stadium_name, booking_type, player_team_id, joined_user_ids, final_outcome')
          .eq('status', 'completed')
          .contains('joined_user_ids', [userId])
          .order('start_time', ascending: false)
          .limit(100);

      final bookings = (response as List)
          .map((doc) => Booking.fromFirestore(doc, doc['id'].toString()))
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
        'wins': wins,
        'challengeMatches': challengeMatchesCount,
      };
    } catch (e, stack) {
      VSPLogger.e('Error calculating stats for player $userId', e, stack);
      return {
        'winRate': '0.0',
        'favoriteStadium': 'Error',
        'matchesPlayed': 0,
        'wins': 0,
        'challengeMatches': 0,
      };
    }
  }
}
