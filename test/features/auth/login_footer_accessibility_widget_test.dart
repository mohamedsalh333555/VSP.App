import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/login_screen.dart';
import 'package:vsp_application/features/auth/widgets/login_footer.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/vsp_terms_checkbox.dart';

class FakeAuth extends ChangeNotifier implements AuthProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget sheetApp(String language) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) =>
          const Scaffold(body: Center(child: LoginFooter()))),
      GoRoute(path: '/create-account-player', builder: (_, __) =>
          const Scaffold(body: Center(child: Text('player destination')))),
      GoRoute(path: '/create-account-owner', builder: (_, __) =>
          const Scaffold(body: Center(child: Text('owner destination')))),
    ],
  );
  return MaterialApp.router(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  for (final language in ['ar', 'en']) {
    final player = language == 'ar' ? 'لاعب' : 'Player';
    final owner = language == 'ar' ? 'صاحب ملعب' : 'Stadium owner';
    final signup = language == 'ar'
        ? 'إنشاء حساب' : 'Sign up';

    testWidgets('$language: role sheet exposes distinct actions to a screen reader',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(sheetApp(language));
      await tester.tap(find.text(signup));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^$player\\.')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^$owner\\.')), findsOneWidget);
      await tester.tap(find.text(player));
      await tester.pumpAndSettle();
      expect(find.text('player destination'), findsOneWidget);
      expect(find.text('owner destination'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('$language: bottom sheet is dismissible without creating a role',
        (tester) async {
      await tester.pumpWidget(sheetApp(language));
      await tester.tap(find.text(signup));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('player destination'), findsNothing);
      expect(find.text('owner destination'), findsNothing);
      expect(find.byType(LoginFooter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language: owner role is selectable with 320dp and large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(sheetApp(language));
      await tester.tap(find.text(signup));
      await tester.pumpAndSettle();
      final target = find.text(owner);
      await tester.ensureVisible(target);
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('^$owner\\.')), findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('owner destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('$language: login keyboard Next moves focus from email to password',
        (tester) async {
      final auth = FakeAuth();
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ));
      final editables = find.byType(EditableText);
      await tester.ensureVisible(editables.first);
      await tester.showKeyboard(editables.first);
      await tester.pump();
      expect(tester.widget<EditableText>(editables.first).focusNode.hasFocus, true);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(tester.widget<EditableText>(editables.at(1)).focusNode.hasFocus, true);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$language: terms consent is an accessible checked action',
        (tester) async {
      final semantics = tester.ensureSemantics();
      bool accepted = false;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(builder: (context, setState) => Scaffold(
          body: VSPTermsCheckbox(
            value: accepted,
            onChanged: (value) => setState(() => accepted = value),
            onTermsTap: () {},
          ),
        )),
      ));
      final check = find.bySemanticsLabel(language == 'ar'
          ? 'الموافقة على الشروط والأحكام'
          : 'Agree to Terms and Conditions');
      expect(check, findsOneWidget);
      expect(tester.getSize(check).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(check).height, greaterThanOrEqualTo(48));
      await tester.tap(check);
      await tester.pump();
      expect(accepted, true);
      await tester.tap(check);
      await tester.pump();
      expect(accepted, false);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
