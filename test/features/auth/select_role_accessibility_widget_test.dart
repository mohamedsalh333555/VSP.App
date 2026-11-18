import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/select_role_screen.dart';

class RoleAuth extends ChangeNotifier implements AuthProvider {
  String? selected;
  @override
  void setUserType(String type) {
    selected = type;
    notifyListeners();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget host(RoleAuth auth, {String lang = 'en'}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const SelectRoleScreen(),
      ),
    );

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('role choices select distinct roles in $lang with accessible labels',
        (tester) async {
      final auth = RoleAuth();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(auth, lang: lang));
      final playerLabel = lang == 'ar' ? 'لاعب' : 'Player';
      final ownerLabel = lang == 'ar' ? 'صاحب ملعب' : 'Stadium owner';
      expect(find.text(playerLabel), findsOneWidget);
      expect(find.text(ownerLabel), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(lang == 'ar' ? r'^لاعب\.' : r'^Player\.')), findsOneWidget);
      await tester.tap(find.text(playerLabel));
      await tester.pump();
      expect(auth.selected, 'player');
      await tester.tap(find.text(ownerLabel));
      await tester.pump();
      expect(auth.selected, 'owner');
      semantics.dispose();
    });

    testWidgets('role cards and account switch fit a narrow enlarged screen in $lang',
        (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = RoleAuth();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(host(auth, lang: lang));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(lang == 'ar'
          ? 'تسجيل الدخول بحساب آخر'
          : 'Log in with another account'), findsOneWidget);
      final role = find.text(lang == 'ar' ? 'صاحب ملعب' : 'Stadium owner');
      await tester.ensureVisible(role);
      await tester.tap(role);
      await tester.pump();
      expect(auth.selected, 'owner');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
