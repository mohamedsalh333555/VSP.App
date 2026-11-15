import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_result_actions.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  for (final language in ['ar', 'en']) {
    for (final team in ['home', 'away']) {
      testWidgets('opponent choice is hidden for $team in $language', (tester) async {
        List<String>? firstTexts;
        for (final outcome in MatchOutcome.values) {
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
            matchResultStatus: MatchResultStatus.waitingOpponent,
            resultSubmittedByTeamId: team == 'home' ? 'away' : 'home',
            pendingOutcome: outcome,
          );
          await tester.pumpWidget(MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ChallengeResultActions(booking: booking, myTeamId: team)),
          ));
          await tester.pumpAndSettle();
          final texts = tester.widgetList<Text>(find.byType(Text))
              .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
              .toList();
          // All three possible opponent outcomes must render exactly alike.
          if (firstTexts != null) expect(texts, firstTexts);
          firstTexts ??= texts;
          expect(find.text(language == 'ar'
              ? 'الفريق المنافس سجّل نتيجته. سجّل نتيجتك بشكل مستقل.'
              : 'Opponent submitted. Record your result independently.'), findsOneWidget);
          expect(find.text(language == 'ar' ? 'تسجيل نتيجتي' : 'Record my result'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
