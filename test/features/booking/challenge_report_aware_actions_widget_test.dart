import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/core/repositories/booking/challenge_captain_private_submission_repository.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_report_aware_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Booking _challenge({MatchResultStatus resultStatus = MatchResultStatus.confirmed}) {
  final now = DateTime.now();
  return Booking(
    id: 'synthetic-challenge',
    stadiumId: 'venue',
    stadiumName: 'Venue',
    stadiumImageUrl: '',
    ownerId: 'owner',
    startTime: now.subtract(const Duration(hours: 3)),
    endTime: now.subtract(const Duration(hours: 2)),
    bookingType: BookingType.challenge,
    playerTeamId: 'home',
    opponentTeamId: 'away',
    isPrivate: true,
    rentBall: false,
    totalPrice: 300,
    paymentMethod: 'cash',
    status: BookingStatus.completed,
    createdByUserId: 'captain',
    createdAt: now,
    matchResultStatus: resultStatus,
    finalOutcome: resultStatus == MatchResultStatus.confirmed
        ? MatchOutcome.homeWin : null,
  );
}

Widget _wrap(Widget widget, {String language = 'en'}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: widget)),
);

void main() {
  testWidgets('default gate preserves old result UI without contacting server',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(ChallengeReportAwareActions(
      booking: _challenge(), myTeamId: 'home', badgeOnly: true,
      statusLoader: (id) async {
        calls++;
        return {'success': true, 'reported': true, 'state': 'excluded'};
      },
    )));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.text('Match excluded'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final lang in ['ar','en']) {
    testWidgets('server exclusion overrides previously confirmed result: ' + lang,
        (tester) async {
      var calls = 0;
      final fetcher = (String id) async {
        calls++;
        expect(id, 'synthetic-challenge');
        return <String, Object?>{
          'success': true, 'reported': true, 'state': 'excluded',
          'under_review': true, 'my_appeal_submitted': false,
          'opponent_outcome': 'awayWin',
        };
      };
      await tester.pumpWidget(_wrap(Column(children: [
        ChallengeReportAwareActions(
          booking: _challenge(), myTeamId: 'home',
          badgeOnly: true, reportFeatureEnabled: true,
          statusLoader: fetcher,
        ),
        ChallengeReportAwareActions(
          booking: _challenge(), myTeamId: 'home',
          reportFeatureEnabled: true,
          statusLoader: fetcher,
        ),
      ]), language: lang));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(lang == 'ar'
          ? 'بلاغ قيد المراجعة' : 'Report under review'), findsOneWidget);
      expect(find.text(lang == 'ar'
          ? 'المباراة مستبعدة بسبب بلاغ عدم اللعب'
          : 'Match excluded: reported not played'), findsOneWidget);
      expect(find.text('awayWin'), findsNothing);
      expect(find.text('Record my result'), findsNothing);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final data in [
    {'lang': 'en', 'team': 'home', 'expected': 'Your submitted result: Win'},
    {'lang': 'en', 'team': 'away', 'expected': 'Your submitted result: Loss'},
    {'lang': 'ar', 'team': 'home', 'expected': 'النتيجة التي سجلتها: فوز'},
    {'lang': 'ar', 'team': 'away', 'expected': 'النتيجة التي سجلتها: خسارة'},
  ]) {
    testWidgets('only my vote is shown in pending challenge: ' +
        data['lang']! + '/' + data['team']!, (tester) async {
      var privateReads = 0;
      final ownVote = ChallengeCaptainSubmission.fromScopedRpc({
        'success': true, 'submitted': true,
        'my_outcome': 'homeWin', 'my_revision': 1,
        'opponent_outcome': 'awayWin', 'opponent_captain_id': 'SECRET',
      });
      await tester.pumpWidget(_wrap(ChallengeReportAwareActions(
        booking: _challenge(resultStatus: MatchResultStatus.waitingOpponent),
        myTeamId: data['team']!,
        reportFeatureEnabled: true,
        statusLoader: (_) async => {'success': true, 'reported': false},
        submissionLoader: (id) async {
          privateReads++;
          expect(id, 'synthetic-challenge');
          return ownVote;
        },
      ), language: data['lang']!));
      await tester.pumpAndSettle();
      expect(privateReads, 1);
      expect(find.text(data['expected']!), findsOneWidget);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('opponent_outcome'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('server exclusion suppresses private vote label even if loaded',
      (tester) async {
    final ownVote = ChallengeCaptainSubmission.fromScopedRpc({
      'success': true, 'submitted': true,
      'my_outcome': 'homeWin', 'my_revision': 1,
    });
    await tester.pumpWidget(_wrap(ChallengeReportAwareActions(
      booking: _challenge(resultStatus: MatchResultStatus.disputed),
      myTeamId: 'home',
      reportFeatureEnabled: true,
      statusLoader: (_) async => {
        'success': true, 'reported': true, 'state': 'excluded',
      },
      submissionLoader: (_) async => ownVote,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Match excluded: reported not played'), findsOneWidget);
    expect(find.textContaining('Your submitted result'), findsNothing);
  });

  testWidgets('captain own vote is refreshed after manual status retry',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(_wrap(ChallengeReportAwareActions(
      booking: _challenge(resultStatus: MatchResultStatus.disputed),
      myTeamId: 'home',
      reportFeatureEnabled: true,
      statusLoader: (_) async => {'success': true, 'reported': false},
      submissionLoader: (_) async {
        reads++;
        return ChallengeCaptainSubmission.fromScopedRpc(
          reads == 1
              ? {'success': true, 'submitted': false}
              : {'success': true, 'submitted': true,
                  'my_outcome': 'draw', 'my_revision': 2},
        );
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('You have not submitted your result.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Your submitted result: Draw'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network failure stays closed and refresh restores a trusted view',
      (tester) async {
    var calls = 0;
    Future<Map<String, Object?>?> fetch(String id) async {
      calls++;
      if (calls == 1) return null;
      return {'success': true, 'reported': false};
    }
    await tester.pumpWidget(_wrap(ChallengeReportAwareActions(
      booking: _challenge(),
      myTeamId: 'home',
      reportFeatureEnabled: true,
      statusLoader: fetch,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Match report status unavailable. Please retry.'),
        findsOneWidget);
    expect(find.text('Result confirmed. View your team profile and match history.'),
        findsNothing);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Result confirmed. View your team profile and match history.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
