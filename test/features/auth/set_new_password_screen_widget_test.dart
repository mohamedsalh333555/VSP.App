import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/auth/screens/set_new_password_screen.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

User _user(String id) => User(
  id: id, appMetadata: const {}, userMetadata: const {},
  aud: 'authenticated', createdAt: '2026-11-19T00:00:00Z',
);

class _FakeAuth extends ChangeNotifier implements AuthProvider {
  User? active = _user('owner');
  int updateCalls = 0;
  int signOutCalls = 0;
  String? lastPassword;
  bool updateResult = true;
  bool throwsOnUpdate = false;
  Completer<bool>? pending;

  @override
  User? get currentUser => active;
  @override
  Future<bool> updatePassword(String password) async {
    updateCalls++;
    lastPassword = password;
    if (throwsOnUpdate) throw StateError('PRIVATE_AUTH_PROVIDER_DIAGNOSTIC');
    if (pending != null) return pending!.future;
    return updateResult;
  }
  @override
  Future<void> signOut() async {
    signOutCalls++;
    active = null;
    notifyListeners();
  }
  void useAccount(String? userId) {
    active = userId == null ? null : _user(userId);
    notifyListeners();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_FakeAuth fake, {String language = 'en'}) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: fake,
      child: MaterialApp(
        locale: Locale(language),
        home: const SetNewPasswordScreen(),
      ),
    );

Future<void> _fillValidForm(WidgetTester tester, {String newPassword = 'Password123!'}) async {
  await tester.enterText(find.byType(TextFormField).at(0), newPassword);
  await tester.enterText(find.byType(TextFormField).at(1), newPassword);
  await tester.ensureVisible(find.byType(PrimaryButton));
  await tester.tap(find.byType(PrimaryButton));
  await tester.pump();
}

void main() {
  testWidgets('password form rejects short password before auth request', (tester) async {
    final fake = _FakeAuth();
    await tester.pumpWidget(_host(fake));
    await _fillValidForm(tester, newPassword: 'abc');
    expect(fake.updateCalls, 0);
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form rejects mismatched confirmation before auth request', (tester) async {
    final fake = _FakeAuth();
    await tester.pumpWidget(_host(fake));
    await tester.enterText(find.byType(TextFormField).at(0), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'different123!');
    await tester.ensureVisible(find.byType(PrimaryButton));
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(fake.updateCalls, 0);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('successful recovery updates password then signs out original user', (tester) async {
    final fake = _FakeAuth();
    await tester.pumpWidget(_host(fake));
    await _fillValidForm(tester);
    expect(fake.updateCalls, 1);
    expect(fake.lastPassword, 'Password123!');
    expect(fake.signOutCalls, 0);
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump();
    expect(fake.signOutCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new account during update never gets recovery success or signout', (tester) async {
    final fake = _FakeAuth()..pending = Completer<bool>();
    await tester.pumpWidget(_host(fake));
    await _fillValidForm(tester);
    fake.useAccount('another-user');
    fake.pending!.complete(true);
    await tester.pump();
    expect(fake.signOutCalls, 0);
    expect(find.textContaining('The account changed during recovery'), findsOneWidget);
    expect(find.textContaining('updated successfully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new account during confirmation delay is never signed out', (tester) async {
    final fake = _FakeAuth();
    await tester.pumpWidget(_host(fake));
    await _fillValidForm(tester);
    expect(fake.signOutCalls, 0);
    fake.useAccount('another-user');
    await tester.pump(const Duration(milliseconds: 1250));
    await tester.pump();
    expect(fake.signOutCalls, 0);
    expect(find.textContaining('The account changed during recovery'), findsOneWidget);
    expect(find.textContaining('updated successfully'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider exception is generic and does not expose diagnostics in Arabic', (tester) async {
    final fake = _FakeAuth()..throwsOnUpdate = true;
    await tester.pumpWidget(_host(fake, language: 'ar'));
    await _fillValidForm(tester);
    expect(fake.updateCalls, 1);
    expect(find.textContaining('PRIVATE_AUTH_PROVIDER_DIAGNOSTIC'), findsNothing);
    expect(find.textContaining('رابط الاستعادة غير صالح'), findsOneWidget);
    expect(fake.signOutCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
