import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/create_account_screen.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';

class FakeLayoutAuth extends ChangeNotifier implements AuthProvider {
  String? type;
  @override
  void setUserType(String value) { type = value; notifyListeners(); }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget host(Widget page, FakeLayoutAuth auth, String language) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.4),
          ),
          child: page,
        ),
      ),
    );

void main() {
  const configs = [
    (name: 'large portrait', width: 430.0, height: 932.0, dpi: 1.0),
    (name: 'landscape narrow height', width: 700.0, height: 420.0, dpi: 1.0),
    (name: 'high-density', width: 1080.0, height: 2400.0, dpi: 3.0),
  ];
  for (final config in configs) {
    for (final language in ['ar', 'en']) {
      testWidgets('login has reachable fields and button: ${config.name} / $language',
          (tester) async {
        tester.view.physicalSize = Size(config.width, config.height);
        tester.view.devicePixelRatio = config.dpi;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeLayoutAuth();
        await tester.pumpWidget(host(const LoginScreen(), auth, language));
        expect(find.byType(TextFormField), findsNWidgets(2));
        await tester.ensureVisible(find.byType(VSPAnimatedButton));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('owner entry stays responsive: ${config.name} / $language',
          (tester) async {
        tester.view.physicalSize = Size(config.width, config.height);
        tester.view.devicePixelRatio = config.dpi;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = FakeLayoutAuth();
        await tester.pumpWidget(host(
          const CreateAccountScreen(isOwner: true),
          auth, language,
        ));
        await tester.pump();
        expect(auth.type, 'owner');
        final login = AppLocalizations.of(
          tester.element(find.byType(CreateAccountScreen)),
        )!.login;
        await tester.ensureVisible(find.text(login).last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
