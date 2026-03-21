import 'dart:math';

class EloCalculator {
  static const int kFactor = 32;

  /// Calculates the new ratings for two teams based on match result.
  /// [outcome] should be: 1.0 for home win, 0.5 for draw, 0.0 for away win.
  static Map<String, int> calculateNewRatings({
    required int homeRating,
    required int awayRating,
    required double outcome,
  }) {
    double expectedHome = 1 / (1 + pow(10, (awayRating - homeRating) / 400));
    double expectedAway = 1 / (1 + pow(10, (homeRating - awayRating) / 400));

    int newHomeRating = (homeRating + kFactor * (outcome - expectedHome)).round();
    int newAwayRating = (awayRating + kFactor * ((1 - outcome) - expectedAway)).round();

    return {
      'home': newHomeRating,
      'away': newAwayRating,
    };
  }

  static String getRankTitle(int points) {
    if (points >= 2000) return 'Legendary';
    if (points >= 1500) return 'Diamond';
    if (points >= 1200) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 800) return 'Silver';
    return 'Bronze';
  }
}
