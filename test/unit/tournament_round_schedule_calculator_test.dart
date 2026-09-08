import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/owner/widgets/brackets/tournament_round_schedule_calculator.dart';

void main() {
  group('TournamentRoundScheduleCalculator Unit Tests', () {
    test('isRoundLocked identifies unplayed vs started or completed matches', () {
      final unplayedMatches = [
        TournamentMatch(
          id: 'm1',
          championshipId: 'c1',
          roundIndex: 0,
          matchIndex: 0,
        ),
      ];

      expect(TournamentRoundScheduleCalculator.isRoundLocked(unplayedMatches), isFalse);

      final startedMatches = [
        TournamentMatch(
          id: 'm1',
          championshipId: 'c1',
          roundIndex: 0,
          matchIndex: 0,
          homeScore: 2,
          awayScore: 1,
        ),
      ];

      expect(TournamentRoundScheduleCalculator.isRoundLocked(startedMatches), isTrue);

      final completedMatches = [
        TournamentMatch(
          id: 'm1',
          championshipId: 'c1',
          roundIndex: 0,
          matchIndex: 0,
          winnerId: 't1',
        ),
      ];

      expect(TournamentRoundScheduleCalculator.isRoundLocked(completedMatches), isTrue);
    });

    test('calculateAvailableDaysOptions scales with match volume', () {
      // 8 or more matches (Round of 16 / 32)
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(8), [1, 2, 4]);
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(16), [1, 2, 4]);

      // 4 to 7 matches (Quarterfinals)
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(4), [1, 2]);
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(6), [1, 2]);

      // Less than 4 matches (Semifinals / Finals)
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(2), [1]);
      expect(TournamentRoundScheduleCalculator.calculateAvailableDaysOptions(1), [1]);
    });

    test('calculateDurationOptions integrates and sorts custom preset duration', () {
      final options1 = TournamentRoundScheduleCalculator.calculateDurationOptions(30);
      expect(options1, [15, 20, 30, 45, 60, 90]);

      // 25 is not in standard list, should be inserted in sorted order
      final options2 = TournamentRoundScheduleCalculator.calculateDurationOptions(25);
      expect(options2, [15, 20, 25, 30, 45, 60, 90]);
    });

    test('calculateMatchesPerDay rounds up match division accurately', () {
      expect(TournamentRoundScheduleCalculator.calculateMatchesPerDay(8, 1), 8);
      expect(TournamentRoundScheduleCalculator.calculateMatchesPerDay(8, 2), 4);
      expect(TournamentRoundScheduleCalculator.calculateMatchesPerDay(8, 4), 2);

      // Odd count
      expect(TournamentRoundScheduleCalculator.calculateMatchesPerDay(7, 2), 4);
    });

    test('buildScheduleSummary generates localized Arabic and English texts', () {
      final summaryAr = TournamentRoundScheduleCalculator.buildScheduleSummary(
        matchCount: 8,
        daysCount: 2,
        formattedStartTime: '06:00 PM',
        matchDuration: 30,
        isArabic: true,
      );

      expect(summaryAr[0], contains('4 مباريات يومياً'));
      expect(summaryAr[0], contains('يومين'));
      expect(summaryAr[1], contains('06:00 PM'));
      expect(summaryAr[1], contains('30 دقيقة'));

      final summaryEn = TournamentRoundScheduleCalculator.buildScheduleSummary(
        matchCount: 8,
        daysCount: 2,
        formattedStartTime: '06:00 PM',
        matchDuration: 30,
        isArabic: false,
      );

      expect(summaryEn[0], contains('4 matches daily'));
      expect(summaryEn[0], contains('2 day(s)'));
    });
  });
}
