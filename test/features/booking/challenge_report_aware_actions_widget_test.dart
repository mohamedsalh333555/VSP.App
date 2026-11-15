import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_report_aware_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Booking _challenge() {
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
    matchResultStatus: MatchResultStatus.confirmed,
    finalOutcome: MatchOutcome.homeWin,
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
    expect(find.text('Result confirmed. You can check the team standings.'),
        findsNothing);
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Result confirmed. You can check the team standings.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
