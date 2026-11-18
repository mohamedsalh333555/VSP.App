import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/select_role_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class FakeSwitchAuth extends ChangeNotifier implements AuthProvider {
  final Completer<void> logout = Completer<void>();
  int signOutCalls = 0;
  @override
  Future<void> signOut() {
    signOutCalls++;
    return logout.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildApp(FakeSwitchAuth auth, {String language = 'en'}) {
  final router = GoRouter(
    initialLocation: '/roles',
    routes: [
      GoRoute(path: '/roles', builder: (_, __) => const SelectRoleScreen()),
      GoRoute(path: '/login', builder: (_, __) =>
          const Scaffold(body: Text('New login destination'))),
    ],
  );
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp.router(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  for (final language in ['ar', 'en']) {
    final label = language == 'ar'
        ? 'تسجيل الدخول بحساب آخر' : 'Log in with another account';
    testWidgets('account switch awaits logout and never duplicates it in $language',
        (tester) async {
      final auth = FakeSwitchAuth();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildApp(auth, language: language));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      expect(auth.signOutCalls, 1);
      expect(find.text('New login destination'), findsNothing);

      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      expect(auth.signOutCalls, 1);
      expect(find.text('New login destination'), findsNothing);

      auth.logout.complete();
      await tester.pumpAndSettle();
      expect(find.text('New login destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('failed logout preserves current role screen in $language',
        (tester) async {
      final auth = FakeSwitchAuth();
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildApp(auth, language: language));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      auth.logout.completeError(StateError('private-signout-internals'));
      await tester.pump();
      expect(find.text('New login destination'), findsNothing);
      expect(find.textContaining('private-signout-internals'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
