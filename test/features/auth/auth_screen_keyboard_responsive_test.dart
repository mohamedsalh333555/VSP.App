import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/create_account_screen.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/l10n/app_localizations_ar.dart';
import 'package:vsp_application/l10n/app_localizations_en.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';

class FakeEntryAuth extends ChangeNotifier implements AuthProvider {
  String? lastRole;

  @override
  void setUserType(String type) {
    lastRole = type;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget host(FakeEntryAuth auth, Widget child,
    {required String locale, required bool keyboardVisible}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: const TextScaler.linear(1.6),
            disableAnimations: true,
            viewInsets: EdgeInsets.only(bottom: keyboardVisible ? 260 : 0),
          ),
          child: child,
        ),
      ),
    );

void setSmallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('login fields and submit stay reachable above a small phone keyboard in $lang',
        (tester) async {
      setSmallScreen(tester);
      final auth = FakeEntryAuth();
      await tester.pumpWidget(host(auth, const LoginScreen(),
          locale: lang, keyboardVisible: true));
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).first, 'player@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'Password123!');
      await tester.ensureVisible(find.byType(VSPAnimatedButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // This is a UI reachability check, not a live sign-in request.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final owner in [false, true]) {
      testWidgets('create account $owner role fits large text on 320dp in $lang',
          (tester) async {
        setSmallScreen(tester);
        final auth = FakeEntryAuth();
        await tester.pumpWidget(host(
          auth,
          CreateAccountScreen(isOwner: owner),
          locale: lang,
          keyboardVisible: false,
        ));
        await tester.pump();
        expect(auth.lastRole, owner ? 'owner' : 'player');
        final loginLabel = lang == 'ar'
            ? AppLocalizationsAr().login
            : AppLocalizationsEn().login;
        // The text of the link and localized auth copy remain visible in the tree.
        expect(find.text(loginLabel), findsWidgets);
        await tester.ensureVisible(find.text(loginLabel).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
