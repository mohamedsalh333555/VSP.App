import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/booking/challenge_non_played_report_repository.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_result_actions.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_non_played_appeal_dialog.dart';
import 'package:vsp_application/features/player/widgets/user_bookings/challenge_non_played_report_status.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Booking _fixture() {
  final now = DateTime.now();
  return Booking(
    id: 'challenge', stadiumId: 'venue', stadiumName: 'Venue',
    stadiumImageUrl: '', ownerId: 'owner',
    startTime: now.subtract(const Duration(hours: 3)),
    endTime: now.subtract(const Duration(hours: 2)),
    bookingType: BookingType.challenge,
    playerTeamId: 'home', opponentTeamId: 'away',
    isPrivate: true, rentBall: false,
    totalPrice: 250, paymentMethod: 'cash',
    status: BookingStatus.completed,
    createdByUserId: 'captain', createdAt: now,
    matchResultStatus: MatchResultStatus.confirmed,
    finalOutcome: MatchOutcome.homeWin,
  );
}

Widget _wrap(Widget content, {required String language}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: content)),
);

void main() {
  testWidgets('a failed appeal edit must never be acknowledged as saved',
      (tester) async {
    var submitted = 0;
    var refreshed = 0;
    const oldAppeal = ChallengeNonPlayedReportStatus(
      state: ChallengeNonPlayedReportState.excluded,
      myAppealSubmitted: true,
    );
    await tester.pumpWidget(_wrap(ChallengeResultActions(
      booking: _fixture(), myTeamId: 'home',
      reportStatus: oldAppeal,
      reportLookupRequired: true,
      allowAppeal: true,
      appealSubmitOverride: (reason) async {
        submitted++;
        return ChallengeReportCommandReceipt.rejected;
      },
      onReportChanged: () => refreshed++,
    ), language: 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update appeal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'I am supplying a revised, detailed explanation of this fixture.');
    await tester.tap(find.text('Submit appeal'));
    await tester.pumpAndSettle();
    expect(submitted, 1);
    expect(refreshed, 0);
    expect(tester.takeException(), isNull);
    // VSPFeedback overlay toasts self-dismiss after three seconds. Drain
    // that timer in the widget test instead of leaking it at teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  for (final language in ['ar','en']) {
    testWidgets('captain can submit an appeal after exclusion: ' + language,
        (tester) async {
      var invoked = 0;
      var refreshed = 0;
      String? submittedReason;
      const status = ChallengeNonPlayedReportStatus(
        state: ChallengeNonPlayedReportState.excluded,
        underReview: false,
        myAppealSubmitted: false,
      );
      await tester.pumpWidget(_wrap(ChallengeResultActions(
        booking: _fixture(), myTeamId: 'home', reportStatus: status,
        reportLookupRequired: true, allowAppeal: true,
        appealSubmitOverride: (reason) async {
          invoked++;
          submittedReason = reason;
          return const ChallengeReportCommandReceipt(
            accepted: true, state: 'under_review',
          );
        },
        onReportChanged: () => refreshed++,
      ), language: language));
      await tester.pumpAndSettle();
      expect(find.text(language == 'ar'
          ? 'اعتراض قائد الفريق' : 'Captain appeal'), findsOneWidget);
      await tester.tap(find.text(language == 'ar'
          ? 'اعتراض قائد الفريق' : 'Captain appeal'));
      await tester.pumpAndSettle();
      expect(find.byType(ChallengeNonPlayedAppealDialog), findsOneWidget);
      await tester.tap(find.text(language == 'ar'
          ? 'إرسال الاعتراض' : 'Submit appeal'));
      await tester.pumpAndSettle();
      expect(invoked, 0);
      expect(find.text(language == 'ar'
          ? 'اكتب سببًا من 8 إلى 500 حرف.'
          : 'Enter a reason between 8 and 500 characters.'), findsOneWidget);
      await tester.enterText(find.byType(TextField),
          '  Team members played this fixture and have timestamped photos  ');
      await tester.tap(find.text(language == 'ar'
          ? 'إرسال الاعتراض' : 'Submit appeal'));
      await tester.pumpAndSettle();
      expect(invoked, 1);
      expect(refreshed, 1);
      expect(submittedReason,
          'Team members played this fixture and have timestamped photos');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('noncaptain is blocked but captain can update an existing appeal: ' +
        language, (tester) async {
      const pending = ChallengeNonPlayedReportStatus(
        state: ChallengeNonPlayedReportState.excluded,
        myAppealSubmitted: false,
      );
      await tester.pumpWidget(_wrap(ChallengeResultActions(
        booking: _fixture(), myTeamId: 'home',
        reportStatus: pending, allowAppeal: false,
      ), language: language));
      await tester.pumpAndSettle();
      expect(find.text(language == 'ar'
          ? 'اعتراض قائد الفريق' : 'Captain appeal'), findsNothing);
      const already = ChallengeNonPlayedReportStatus(
        state: ChallengeNonPlayedReportState.excluded,
        myAppealSubmitted: true,
      );
      await tester.pumpWidget(_wrap(ChallengeResultActions(
        booking: _fixture(), myTeamId: 'home',
        reportStatus: already, allowAppeal: true,
      ), language: language));
      await tester.pumpAndSettle();
      expect(find.text(language == 'ar'
          ? 'اعتراض قائد الفريق' : 'Captain appeal'), findsNothing);
      expect(find.text(language == 'ar'
          ? 'تحديث الاعتراض' : 'Update appeal'), findsOneWidget);
      expect(find.text(language == 'ar'
          ? 'تم تسجيل اعتراض فريقك.' : 'Your team appeal is recorded.'),
          findsOneWidget);
    });
  }
}
