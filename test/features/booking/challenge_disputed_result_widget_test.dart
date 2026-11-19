import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_result_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final team in ['home', 'away']) {
      testWidgets('disagreement offers independent correction to $team in $language', (tester) async {
        final now = DateTime.now();
        final booking = Booking(
          id: 'challenge', stadiumId: 'venue', stadiumName: 'Venue',
          stadiumImageUrl: '', ownerId: 'owner',
          startTime: now.subtract(const Duration(hours: 3)),
          endTime: now.subtract(const Duration(hours: 2)),
          bookingType: BookingType.challenge,
          playerTeamId: 'home', opponentTeamId: 'away',
          isPrivate: true, rentBall: false, totalPrice: 300,
          paymentMethod: 'cash', status: BookingStatus.confirmed,
          createdByUserId: 'captain', createdAt: now,
          matchResultStatus: MatchResultStatus.disputed,
          pendingOutcome: MatchOutcome.awayWin,
        );
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) => Scaffold(
            body: Column(children: [
              ChallengeResultActions.buildChallengeStatusBadge(
                context, booking: booking, myTeamId: team),
              ChallengeResultActions(booking: booking, myTeamId: team),
            ]),
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text(language == 'ar'
            ? 'النتيجتان مختلفتان' : 'Results do not match'), findsOneWidget);
        expect(find.text(language == 'ar'
            ? 'النتيجتان مختلفتان. لن تُضاف نقاط حتى يتفق قائدا الفريقين.'
            : 'The two results differ. No points are added until both captains agree.'), findsOneWidget);
        expect(find.text(language == 'ar' ? 'تسجيل نتيجتي' : 'Record my result'), findsOneWidget);
        expect(find.text('Standings'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
