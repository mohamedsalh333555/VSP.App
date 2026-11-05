import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/features/auth/screens/welcome_screen.dart';
import 'package:vsp_application/features/auth/widgets/welcome/welcome_language_button.dart';
import 'package:vsp_application/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android cold start supports Arabic, English, onboarding, and login',
    (tester) async {
      // Bootstrap uses real asynchronous platform/network operations.
      // runAsync keeps those operations on the real event loop rather than
      // trapping their timers inside the widget test's fake async zone.
      // CI diagnostics: distinguish bootstrap hangs from navigation failures.
      // ignore: avoid_print
      print('VSP_E2E: starting app bootstrap');
      await tester.runAsync(
        () => app.main().timeout(const Duration(seconds: 30)),
      );

      // ignore: avoid_print
      print('VSP_E2E: app bootstrap returned');

      // Supabase/Firebase/remote-config initialization and the splash route are
      // real in this test. Pump in bounded increments rather than waiting on
      // decorative animations that may never fully settle.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byType(WelcomeScreen).evaluate().isNotEmpty) break;
      }

      // ignore: avoid_print
      print('VSP_E2E: welcome screen found=${find.byType(WelcomeScreen).evaluate().isNotEmpty}');
      expect(find.byType(WelcomeScreen), findsOneWidget);
      // Device locale or persisted preference may start in Arabic or English.
      // Verify the language control actually changes the visible skip label,
      // then normalize to English for the remaining navigation assertions.
      expect(find.byType(WelcomeLanguageButton), findsOneWidget);
      final initialLanguage = Localizations.localeOf(
        tester.element(find.byType(WelcomeScreen)),
      ).languageCode;
      expect(find.text(initialLanguage == 'ar' ? 'تخطي' : 'Skip'), findsOneWidget);

      await tester.tap(find.byType(WelcomeLanguageButton));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(initialLanguage == 'ar' ? 'Skip' : 'تخطي'), findsOneWidget);

      if (initialLanguage == 'ar') {
        // The first switch already moved the app into English.
      } else {
        await tester.tap(find.byType(WelcomeLanguageButton));
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Player'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      await tester.tap(find.text('Login'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
      // Email/password are hintText on custom input fields, not Text widgets.
      // Verify the actual editable controls instead of matching hint labels.
      expect(find.byType(EditableText), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
