import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/features/auth/screens/welcome_screen.dart';
import 'package:vsp_application/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android cold start supports Arabic, English, onboarding, and login',
    (tester) async {
      // Bootstrap uses real asynchronous platform/network operations.
      // runAsync keeps those operations on the real event loop rather than
      // trapping their timers inside the widget test's fake async zone.
      await tester.runAsync(
        () => app.main().timeout(const Duration(seconds: 30)),
      );

      // Supabase/Firebase/remote-config initialization and the splash route are
      // real in this test. Pump in bounded increments rather than waiting on
      // decorative animations that may never fully settle.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.byType(WelcomeScreen).evaluate().isNotEmpty) break;
      }

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('تخطي'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Player'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      await tester.tap(find.text('Login'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
