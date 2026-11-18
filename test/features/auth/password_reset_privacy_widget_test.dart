import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/services/password_reset_privacy_message.dart';
import 'package:vsp_application/features/auth/widgets/forgot_password_dialog.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class FakePasswordAuth extends ChangeNotifier implements AuthProvider {
  FakePasswordAuth(this.behavior);

  final String behavior;
  int calls = 0;
  String? lastEmail;

  @override
  Future<bool> resetPassword(String email) async {
    calls++;
    lastEmail = email;
    if (behavior == 'throws') {
      throw StateError('Backend details must not be shown');
    }
    return behavior == 'success';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget recoveryHost(FakePasswordAuth auth, {String language = 'en'}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ForgotPasswordDialog.show(context),
              child: const Text('Open recovery'),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final behavior in ['success', 'unknown', 'throws']) {
    testWidgets('recovery hides account existence for $behavior response',
        (tester) async {
      final auth = FakePasswordAuth(behavior);
      await tester.pumpWidget(recoveryHost(auth));
      await tester.tap(find.text('Open recovery'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first, '  person@example.com  ',
      );
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(auth.calls, 1);
      expect(auth.lastEmail, 'person@example.com');
      expect(find.text(PasswordResetPrivacyMessage.acknowledgement(
        isArabic: false,
      )), findsOneWidget);
      expect(find.textContaining('Backend details must not be shown'),
          findsNothing);
      // VSPFeedback owns an expected 3-second auto-dismiss timer.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });
  }

  testWidgets('neutral recovery text also appears in Arabic', (tester) async {
    final auth = FakePasswordAuth('unknown');
    await tester.pumpWidget(recoveryHost(auth, language: 'ar'));
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text(PasswordResetPrivacyMessage.acknowledgement(
      isArabic: true,
    )), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('invalid email is rejected before a recovery request', (tester) async {
    final auth = FakePasswordAuth('success');
    await tester.pumpWidget(recoveryHost(auth));
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    expect(auth.calls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
  });

  testWidgets('cancel and Android back leave password recovery unsubmitted',
      (tester) async {
    final auth = FakePasswordAuth('success');
    await tester.pumpWidget(recoveryHost(auth));
    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(find.text('Open recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'b@example.com');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(find.text('Open recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('acknowledgements never include provider responses or account status', () {
    final en = PasswordResetPrivacyMessage.acknowledgement(isArabic: false);
    final ar = PasswordResetPrivacyMessage.acknowledgement(isArabic: true);
    expect(en, contains('If the email is registered'));
    expect(ar, contains('لو البريد مسجل'));
    expect(en, isNot(contains('not found')));
    expect(en, isNot(contains('exists')));
    expect(en, isNot(contains('successfully sent')));
  });
}
