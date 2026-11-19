import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/owner/widgets/booking_sheet/challenge_non_played_report_dialog.dart';

void main() {
  for (final arabic in [true, false]) {
    final label = arabic ? 'Arabic' : 'English';
    final action = arabic ? 'تسجيل البلاغ' : 'Submit report';
    testWidgets('requires a clear reason before submitting: ' + label,
        (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ChallengeNonPlayedReportDialog.show(
                context, isArabic: arabic,
              );
            },
            child: const Text('open'),
          ),
        )),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(arabic
          ? 'الإبلاغ أن المباراة لم تُلعب'
          : 'Report match not played'), findsOneWidget);
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(find.text(arabic
          ? 'اكتب سببًا واضحًا من 8 إلى 500 حرف.'
          : 'Enter a clear reason (8–500 characters).'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(find.byType(TextField),
          '  The stadium was empty when both teams were due to play.  ');
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(result, 'The stadium was empty when both teams were due to play.');
      expect(find.byType(ChallengeNonPlayedReportDialog), findsNothing);
    });

    testWidgets('cancel keeps report unsubmitted: ' + label, (tester) async {
      String? result = 'unchanged';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ChallengeNonPlayedReportDialog.show(
                context, isArabic: arabic,
              );
            },
            child: const Text('open'),
          ),
        )),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(arabic ? 'إلغاء' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(ChallengeNonPlayedReportDialog), findsNothing);
    });
  }
}
