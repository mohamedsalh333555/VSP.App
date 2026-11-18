import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_result_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Booking booking({
  MatchResultStatus result = MatchResultStatus.confirmed,
  MatchOutcome? outcome = MatchOutcome.homeWin,
}) => Booking(
  id: 'booking-1',
  stadiumId: 'venue-1',
  stadiumName: 'Pitch',
  ownerId: 'owner-1',
  startTime: DateTime(2026, 11, 16, 18),
  endTime: DateTime(2026, 11, 16, 19),
  bookingType: BookingType.challenge,
  playerTeamId: 'team-a',
  opponentTeamId: 'team-b',
  isPrivate: true,
  rentBall: false,
  totalPrice: 250,
  paymentMethod: 'cash',
  status: BookingStatus.completed,
  createdByUserId: 'captain-a',
  createdAt: DateTime(2026, 11, 15),
  matchResultStatus: result,
  finalOutcome: outcome,
);

Widget host(Booking item, {
  String teamId = 'team-a',
  Locale locale = const Locale('en'),
  bool requireReport = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: ChallengeResultActions(
    booking: item,
    myTeamId: teamId,
    reportLookupRequired: requireReport,
    teamProfileBuilder: (id) => Scaffold(body: Text('TEAM_' + id)),
  )),
);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('confirmed challenge offers team-profile history in '
        '${locale.languageCode}', (tester) async {
      await tester.pumpWidget(host(booking(), teamId: 'team-b', locale: locale));
      final label = locale.languageCode == 'ar' ? 'ملف الفريق' : 'Team profile';
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('TEAM_team-b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('waiting, disputed, missing outcome cannot open progress',
      (tester) async {
    final items = [
      booking(result: MatchResultStatus.confirmed, outcome: null),
      booking(result: MatchResultStatus.waitingOpponent),
      booking(result: MatchResultStatus.disputed),
    ];
    for (final item in items) {
      await tester.pumpWidget(host(item));
      await tester.pumpAndSettle();
      expect(find.text('Team profile'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unrelated team cannot open a participant profile', (tester) async {
    await tester.pumpWidget(host(booking(), teamId: 'outsider'));
    await tester.pumpAndSettle();
    expect(find.text('Team profile'), findsNothing);
  });

  testWidgets('unknown report status blocks old confirmed result', (tester) async {
    await tester.pumpWidget(host(booking(), requireReport: true));
    await tester.pumpAndSettle();
    expect(find.text('Team profile'), findsNothing);
    expect(find.textContaining('Match report status unavailable'), findsOneWidget);
  });
}
