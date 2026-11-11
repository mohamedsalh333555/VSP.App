import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/owner/widgets/account/owner_delete_account_card.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/dialogs/account_deletion_dialog.dart';

class DeletionIdentityAuth extends ChangeNotifier implements AuthProvider {
  String uid = 'owner-a';
  final verification = Completer<bool>();
  int verificationCalls = 0;
  int deletionCalls = 0;
  @override
  User get currentUser => User.fromJson({
    'id': uid, 'aud': 'authenticated', 'role': 'authenticated',
    'created_at': '2026-01-01T00:00:00Z', 'app_metadata': <String, dynamic>{}, 'user_metadata': <String, dynamic>{},
  });
  @override
  Future<bool> reauthenticateWithPassword(String password) { verificationCalls++; return verification.future; }
  @override
  Future<bool> deleteAccount() async { deletionCalls++; return false; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('owner account switch during password verification cannot delete the new account', (tester) async {
    final auth = DeletionIdentityAuth();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: OwnerDeleteAccountCard()),
      ),
    ));
    await tester.tap(find.text('Delete')); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'test-password');
    await tester.tap(find.descendant(of: find.byType(AccountDeletionDialog), matching: find.text('Delete')));
    await tester.pump();
    expect(auth.verificationCalls, 1);
    auth.uid = 'owner-b';
    auth.verification.complete(true);
    await tester.pumpAndSettle();
    expect(auth.deletionCalls, 0);
    expect(find.byType(AccountDeletionDialog), findsOneWidget);
    await tester.tap(find.text('Cancel')); await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
