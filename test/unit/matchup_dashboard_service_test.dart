import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/features/player/services/matchup_dashboard_service.dart';

void main() {
  group('MatchupDashboardService Tests', () {
    test('validateResultSubmission returns error when teamA or teamB is null', () {
      expect(
        MatchupDashboardService.validateResultSubmission(teamAId: null, teamBId: 'team-2'),
        'يرجى اختيار الفريقين المتنافسين',
      );
      expect(
        MatchupDashboardService.validateResultSubmission(teamAId: 'team-1', teamBId: null),
        'يرجى اختيار الفريقين المتنافسين',
      );
      expect(
        MatchupDashboardService.validateResultSubmission(teamAId: null, teamBId: null),
        'يرجى اختيار الفريقين المتنافسين',
      );
    });

    test('validateResultSubmission returns error when teamA and teamB are identical', () {
      expect(
        MatchupDashboardService.validateResultSubmission(teamAId: 'team-1', teamBId: 'team-1'),
        'لا يمكن تسجيل مباراة بين نفس الفريق',
      );
    });

    test('validateResultSubmission returns null when valid distinct teams are selected', () {
      expect(
        MatchupDashboardService.validateResultSubmission(teamAId: 'team-1', teamBId: 'team-2'),
        isNull,
      );
    });

    test('rejects missing, blank and stale team IDs before recording', () {
      final validTeams = ['team-1', 'team-2', 'team-3'];
      expect(
        MatchupDashboardService.validateResultSubmission(
          teamAId: '   ', teamBId: 'team-2',
          eligibleTeamIds: validTeams,
        ),
        'يرجى اختيار الفريقين المتنافسين',
      );
      expect(
        MatchupDashboardService.validateResultSubmission(
          teamAId: 'team-1', teamBId: 'team-from-another-booking',
          eligibleTeamIds: validTeams,
        ),
        'الفريق المحدد غير موجود في هذه المواجهة',
      );
      expect(
        MatchupDashboardService.validateResultSubmission(
          teamAId: 'team-1', teamBId: 'team-2',
          eligibleTeamIds: const <String>[],
          isArabic: false,
        ),
        'Selected team is not part of this matchup.',
      );
    });

    test('accepts only known teams and supported outcomes', () {
      final eligibleTeams = ['team-1', 'team-2'];
      for (final outcome in ['team_a_win', 'team_b_win', 'draw']) {
        expect(
          MatchupDashboardService.validateResultSubmission(
            teamAId: 'team-1', teamBId: 'team-2',
            eligibleTeamIds: eligibleTeams, outcome: outcome,
          ),
          isNull,
        );
      }
      expect(
        MatchupDashboardService.validateResultSubmission(
          teamAId: 'team-1', teamBId: 'team-2',
          eligibleTeamIds: eligibleTeams, outcome: 'unapproved',
          isArabic: false,
        ),
        'Invalid match result.',
      );
      expect(
        MatchupDashboardService.validateResultSubmission(
          teamAId: 'team-1', teamBId: 'team-1',
          eligibleTeamIds: eligibleTeams, outcome: 'draw',
        ),
        'لا يمكن تسجيل مباراة بين نفس الفريق',
      );
    });

    test('canCloseMatchup checks results count correctly', () {
      expect(MatchupDashboardService.canCloseMatchup(0), isFalse);
      expect(MatchupDashboardService.canCloseMatchup(1), isTrue);
      expect(MatchupDashboardService.canCloseMatchup(5), isTrue);
    });

    test('getOutcomePresentation formats outcomes accurately', () {
      final teamAWin = MatchupDashboardService.getOutcomePresentation(
        outcome: 'team_a_win',
        teamAName: 'الأبطال',
        teamBName: 'النسور',
      );
      expect(teamAWin.text, 'فوز الأبطال');
      expect(teamAWin.color, VSPColors.success);

      final teamBWin = MatchupDashboardService.getOutcomePresentation(
        outcome: 'team_b_win',
        teamAName: 'الأبطال',
        teamBName: 'النسور',
      );
      expect(teamBWin.text, 'فوز النسور');
      expect(teamBWin.color, VSPColors.success);

      final draw = MatchupDashboardService.getOutcomePresentation(
        outcome: 'draw',
        teamAName: 'الأبطال',
        teamBName: 'النسور',
      );
      expect(draw.text, 'تعادل');
      expect(draw.color, VSPColors.warning);
      final unknown = MatchupDashboardService.getOutcomePresentation(
        outcome: 'pending', teamAName: 'A', teamBName: 'B',
        isArabic: false,
      );
      expect(unknown.text, 'Result unavailable');
      expect(unknown.color, VSPColors.warning);
    });
  });
}
