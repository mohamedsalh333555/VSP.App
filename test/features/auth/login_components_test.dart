import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/auth/widgets/forgot_password_dialog.dart';
import 'package:vsp_application/features/auth/widgets/login_footer.dart';
import 'package:vsp_application/features/auth/widgets/login_social_auth_row.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Login Components Widget Tests', () {
    testWidgets('LoginFooter renders properly', (tester) async {
      await tester.pumpWidget(buildTestApp(const LoginFooter()));

      expect(find.byType(LoginFooter), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
    });

    testWidgets('ForgotPasswordDialog opens and displays email field and buttons', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ForgotPasswordDialog.show(context),
              child: const Text('Forgot Password'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Forgot Password'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('LoginSocialAuthRow renders continue with Google button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          LoginSocialAuthRow(
            isLoading: false,
            onLoadingChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(LoginSocialAuthRow), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
