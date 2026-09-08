import '../../../../data/models.dart';

/// Pure domain helper and calculator for tournament round auto-scheduling.
class TournamentRoundScheduleCalculator {
  const TournamentRoundScheduleCalculator._();

  /// Determines whether a tournament round is locked from automatic rescheduling.
  /// A round is locked if any match has already started or has a recorded score/winner.
  static bool isRoundLocked(List<TournamentMatch> matches) {
    return matches.any((m) => m.winnerId != null || m.homeScore != null);
  }

  /// Calculates available day division options based on total matches in the round.
  static List<int> calculateAvailableDaysOptions(int matchCount) {
    if (matchCount >= 8) {
      return [1, 2, 4];
    } else if (matchCount >= 4) {
      return [1, 2];
    }
    return [1];
  }

  /// Calculates available match duration choices including the tournament preset.
  static List<int> calculateDurationOptions(int presetDuration) {
    final List<int> options = [15, 20, 30, 45, 60, 90];
    if (!options.contains(presetDuration) && presetDuration > 0) {
      options.add(presetDuration);
      options.sort();
    }
    return options;
  }

  /// Calculates number of matches distributed per day.
  static int calculateMatchesPerDay(int matchCount, int daysCount) {
    if (daysCount <= 0) return matchCount;
    return (matchCount / daysCount).ceil();
  }

  /// Builds human-readable summary text for the auto-schedule configuration.
  static List<String> buildScheduleSummary({
    required int matchCount,
    required int daysCount,
    required String formattedStartTime,
    required int matchDuration,
    required bool isArabic,
  }) {
    final matchesPerDay = calculateMatchesPerDay(matchCount, daysCount);

    if (isArabic) {
      final daysText = daysCount == 1 ? 'يوم واحد' : (daysCount == 2 ? 'يومين' : '$daysCount أيام');
      final matchesText = matchesPerDay == 1 ? 'مباراة' : 'مباريات';
      return [
        '• سيتم إدراج $matchesPerDay $matchesText يومياً على مدار $daysText.',
        '• تبدأ المباريات يومياً الساعة $formattedStartTime بفاصل $matchDuration دقيقة.',
      ];
    } else {
      return [
        '• $matchesPerDay matches daily over $daysCount day(s).',
        '• Matches start at $formattedStartTime with $matchDuration min interval.',
      ];
    }
  }
}
