import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_result_actions.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_non_played_report_status.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Booking challengeFixture() {
  final now = DateTime.now();
  return Booking(
    id: 'challenge', stadiumId: 'venue', stadiumName: 'Venue',
    stadiumImageUrl: '', ownerId: 'owner',
    startTime: now.subtract(const Duration(hours: 3)),
    endTime: now.subtract(const Duration(hours: 2)),
    bookingType: BookingType.challenge, playerTeamId: 'home',
    opponentTeamId: 'away', isPrivate: true, rentBall: false,
    totalPrice: 300, paymentMethod: 'cash',
    status: BookingStatus.completed, createdByUserId: 'captain',
    createdAt: now, matchResultStatus: MatchResultStatus.confirmed,
    finalOutcome: MatchOutcome.homeWin,
  );
}

void main() {
  test('only scoped explicit server status is accepted', () {
    expect(ChallengeNonPlayedReportStatus.fromScopedRpc(null), isNull);
    expect(ChallengeNonPlayedReportStatus.fromScopedRpc({
      'success': false, 'reported': true, 'state': 'excluded',
    }), isNull);
    expect(ChallengeNonPlayedReportStatus.fromScopedRpc({
      'success': true, 'reported': true, 'state': 'unexpected',
    }), isNull);
    expect(ChallengeNonPlayedReportStatus.fromScopedRpc({
      'success': true, 'reported': false, 'state': 'excluded',
    }), isNull);
    final result = ChallengeNonPlayedReportStatus.fromScopedRpc({
      'success': true, 'reported': true, 'state': 'excluded',
      'under_review': true, 'my_appeal_submitted': true,
      'opponent_outcome': 'homeWin', 'other_appeal_reason': 'PRIVATE',
    });
    expect(result, isNotNull);
    expect(result!.isExcluded, isTrue);
    expect(result.underReview, isTrue);
    expect(result.myAppealSubmitted, isTrue);
  });

  for (final language in ['ar', 'en']) {
    for (final team in ['home', 'away']) {
      testWidgets('excluded challenge takes precedence over old win for $team in $language', (tester) async {
        final status = ChallengeNonPlayedReportStatus.fromScopedRpc({
          'success': true, 'reported': true, 'state': 'excluded',
          'under_review': true,
        })!;
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Builder(
            builder: (context) => Column(children: [
              ChallengeResultActions.buildChallengeStatusBadge(
                context, booking: challengeFixture(), myTeamId: team,
                reportStatus: status,
              ),
              ChallengeResultActions(
                booking: challengeFixture(), myTeamId: team,
                reportStatus: status,
              ),
            ]),
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text(language == 'ar'
            ? 'بلاغ قيد المراجعة' : 'Report under review'), findsOneWidget);
        expect(find.text(language == 'ar'
            ? 'المباراة مستبعدة بسبب بلاغ عدم اللعب'
            : 'Match excluded: reported not played'), findsOneWidget);
        expect(find.text('Standings'), findsNothing);
        expect(find.text(language == 'ar'
            ? 'تسجيل نتيجتي' : 'Record my result'), findsNothing);
        expect(find.text('PRIVATE'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('restored match preserves original result presentation for $team in $language', (tester) async {
        final status = ChallengeNonPlayedReportStatus.fromScopedRpc({
          'success': true, 'reported': true, 'state': 'restored',
          'under_review': true,
        })!;
        expect(status.underReview, isFalse);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Builder(
            builder: (context) => ChallengeResultActions(
              booking: challengeFixture(), myTeamId: team,
              reportStatus: status,
            ),
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text(language == 'ar'
            ? 'تمت استعادة المباراة بعد المراجعة'
            : 'Match restored after review'), findsOneWidget);
        expect(find.text(language == 'ar'
            ? 'تم اعتماد النتيجة. يمكنك مراجعة ترتيب الفرق.'
            : 'Result confirmed. You can check the team standings.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
