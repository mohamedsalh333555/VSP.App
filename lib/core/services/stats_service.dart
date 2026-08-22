import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import 'logger_service.dart';

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
    } catch (e, stack) {
      VSPLogger.e('Error calculating stats for player $userId', e, stack);
      return {
        'winRate': '0.0',
        'favoriteStadium': 'Error',
        'matchesPlayed': 0,
      };
    }
  }

  /// Calculates radar chart data based on sport, position, and Elo
  Map<String, double> getSkillMetrics(String? position, int elo, {String? sport = 'Football'}) {
    final String currentSport = sport ?? 'Football';

    if (currentSport == 'Padel') {
      double serve = 60 + (elo / 100);
      double volley = 55 + (elo / 110);
      double smash = 50 + (elo / 120);
      double defense = 60 + (elo / 105);
      double speed = 55 + (elo / 125);
      double power = 50 + (elo / 115);

      if (position == 'Drive') {
        defense += 15; serve += 10;
      } else if (position == 'Revés') {
        smash += 15; power += 15;
      }

      return {
        'SER': serve.clamp(30, 99),
        'VOL': volley.clamp(30, 99),
        'SMA': smash.clamp(30, 99),
        'DEF': defense.clamp(30, 99),
        'SPD': speed.clamp(30, 99),
        'PWR': power.clamp(30, 99),
      };
    } else if (currentSport == 'Basketball') {
      double pts = 55 + (elo / 110);
      double reb = 50 + (elo / 120);
      double ast = 55 + (elo / 115);
      double stl = 50 + (elo / 125);
      double blk = 45 + (elo / 130);
      double threePt = 50 + (elo / 120);

      switch (position?.toUpperCase()) {
        case 'PG':
          ast += 20; stl += 15; reb -= 10;
          break;
        case 'SG':
          threePt += 20; pts += 15;
          break;
        case 'C':
        case 'PF':
          reb += 25; blk += 20; threePt -= 20;
          break;
      }

      return {
        'PTS': pts.clamp(30, 99),
        'REB': reb.clamp(30, 99),
        'AST': ast.clamp(30, 99),
        'STL': stl.clamp(30, 99),
        'BLK': blk.clamp(30, 99),
        '3PT': threePt.clamp(30, 99),
      };
    }

    // Default: Football
    double pace = 60 + (elo / 100);
    double shooting = 50 + (elo / 120);
    double passing = 55 + (elo / 110);
    double dribbling = 50 + (elo / 130);
    double defending = 40 + (elo / 150);
    double physical = 60 + (elo / 100);

    // Bias based on position
    switch (position?.toUpperCase()) {
      case 'ST':
      case 'FW':
      case 'CF':
        shooting += 20; pace += 10; defending -= 20;
        break;
      case 'GK':
        defending += 40; passing += 10; pace -= 20; shooting -= 30;
        break;
      case 'DF':
      case 'CB':
        defending += 30; physical += 20; shooting -= 20;
        break;
      case 'MF':
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
