import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/dialogs/account_deletion_dialog.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

void main() {
  for (final language in ['ar', 'en']) {
    final delete = language == 'ar' ? 'حذف' : 'Delete';
    final cancel = language == 'ar' ? 'إلغاء' : 'Cancel';

    Future<void> open(WidgetTester tester, {
      required Future<bool> Function(String?) onDelete,
      bool requirePassword = false,
      void Function(bool?)? onResult,
    }) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            final result = await showAccountDeletionDialog(context,
              onDelete: onDelete, requirePassword: requirePassword);
            onResult?.call(result);
          },
          child: const Text('open'),
        ))),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('$language: cancel does not submit a deletion', (tester) async {
      var calls = 0;
      bool? result;
      await open(tester, onDelete: (_) async { calls++; return true; }, onResult: (v) => result = v);
      await tester.tap(find.text(cancel));
      await tester.pumpAndSettle();
      expect(calls, 0); expect(result, isFalse);
    });

    testWidgets('$language: pending deletion prevents repeat, cancel, barrier and back', (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      bool? result;
      await open(tester, onDelete: (_) { calls++; return pending.future; }, onResult: (v) => result = v);
      final submit = tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).onPressed!;
      submit(); submit();
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton).first).onPressed, isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AccountDeletionDialog), findsOneWidget);
      expect(result, isNull);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(AccountDeletionDialog), findsNothing);
    });

    testWidgets('$language: failed deletion remains open and can be retried', (tester) async {
      var calls = 0;
      bool? result;
      await open(tester, onDelete: (_) async => ++calls > 1, onResult: (v) => result = v);
      await tester.tap(find.text(delete)); await tester.pumpAndSettle();
      expect(find.byType(AccountDeletionDialog), findsOneWidget);
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(delete)); await tester.pumpAndSettle();
      expect(calls, 2); expect(result, isTrue);
    });

    testWidgets('$language: exception is recoverable without leaking its text', (tester) async {
      await open(tester, onDelete: (_) async => throw StateError('sentinel-private-data'));
      await tester.tap(find.text(delete)); await tester.pumpAndSettle();
      expect(find.textContaining('sentinel-private-data'), findsNothing);
      expect(find.byType(AccountDeletionDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(cancel)); await tester.pumpAndSettle();
    });

    testWidgets('$language: password confirmation refuses empty password and obscures input', (tester) async {
      String? supplied;
      var calls = 0;
      await open(tester, requirePassword: true, onDelete: (password) async { calls++; supplied = password; return false; });
      expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
      await tester.tap(find.text(delete)); await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(TextField), ' test password ');
      await tester.tap(find.text(delete)); await tester.pumpAndSettle();
      expect(calls, 1); expect(supplied, ' test password ');
      await tester.tap(find.text(cancel)); await tester.pumpAndSettle();
    });

    testWidgets('$language: new dialog has fresh state after cancellation', (tester) async {
      await open(tester, requirePassword: true, onDelete: (_) async => false);
      await tester.enterText(find.byType(TextField), 'private password');
      await tester.tap(find.text(cancel)); await tester.pumpAndSettle();
      await tester.tap(find.text('open')); await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(cancel)); await tester.pumpAndSettle();
    });

    testWidgets('$language: narrow large-text confirmation does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, onDelete: (_) async => false);
      expect(tester.takeException(), isNull);
      expect(find.text(delete), findsOneWidget);
      await tester.tap(find.text(cancel)); await tester.pumpAndSettle();
    });
  }
}
