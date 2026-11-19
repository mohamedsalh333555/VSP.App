import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';

class FakeLoginAuth extends ChangeNotifier implements AuthProvider {
  int calls = 0;
  String? submittedEmail;
  String? submittedPassword;
  bool throwNext = false;

  @override
  String? get errorMessage => null;

  @override
  Future<bool> signIn({required String email, required String password}) async {
    calls++;
    submittedEmail = email;
    submittedPassword = password;
    if (throwNext) {
      throwNext = false;
      throw StateError('Sensitive internal provider message');
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget loginHost(FakeLoginAuth auth) => ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(),
      ),
    );

void main() {
  testWidgets('invalid login email never contacts the auth provider',
      (tester) async {
    final auth = FakeLoginAuth();
    await tester.pumpWidget(loginHost(auth));
    await tester.enterText(find.byType(TextFormField).at(0), 'bad@host.c');
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.ensureVisible(find.byType(VSPAnimatedButton));
    await tester.tap(find.byType(VSPAnimatedButton));
    await tester.pump();
    expect(auth.calls, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login recovers from a thrown auth request and permits retry',
      (tester) async {
    final auth = FakeLoginAuth()..throwNext = true;
    await tester.pumpWidget(loginHost(auth));
    await tester.enterText(
      find.byType(TextFormField).at(0), ' CAPTAIN@EXAMPLE.COM ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
    await tester.ensureVisible(find.byType(VSPAnimatedButton));
    await tester.tap(find.byType(VSPAnimatedButton));
    await tester.pump();
    expect(auth.calls, 1);
    expect(auth.submittedEmail, 'captain@example.com');
    expect(find.textContaining('Sensitive internal provider message'),
        findsNothing);
    // The button has a deliberate 2-second tap cooldown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.tap(find.byType(VSPAnimatedButton));
    await tester.pump();
    expect(auth.calls, 2);
    expect(auth.submittedPassword, 'Password123!');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
