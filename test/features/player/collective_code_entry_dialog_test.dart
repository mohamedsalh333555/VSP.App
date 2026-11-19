import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/collective_code_entry_dialog.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget buildHost({
  required void Function(String? code) onResult,
  String language = 'en',
}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final code = await CollectiveCodeEntryDialog.show(context);
          onResult(code);
        },
        child: const Text('Open code dialog'),
      ),
    ),
  ),
);

void main() {
  testWidgets('collective code returns trimmed uppercase after closing',
      (tester) async {
    String? result;
    await tester.pumpWidget(buildHost(onResult: (value) => result = value));
    await tester.tap(find.text('Open code dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Collective match code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' ab12cd34 ');
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();

    expect(result, 'AB12CD34');
    expect(find.byType(CollectiveCodeEntryDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel returns null and leaves the previous screen intact',
      (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(buildHost(onResult: (value) => result = value));
    await tester.tap(find.text('Open code dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'PRIVATE123');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Open code dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back closes modal without using disposed controller',
      (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(buildHost(onResult: (value) => result = value));
    await tester.tap(find.text('Open code dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BACKTEST');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Open code dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic dialog labels and cancellation are preserved', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(buildHost(
      onResult: (value) => result = value, language: 'ar',
    ));
    await tester.tap(find.text('Open code dialog'));
    await tester.pumpAndSettle();
    expect(find.text('كود التجميعية'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  test('global search no longer owns a controller used by a closing dialog', () {
    final screen = File(
      'lib/features/player/screens/global_search_screen.dart',
    ).readAsStringSync();
    expect(screen, contains('CollectiveCodeEntryDialog.show(context)'));
    final start = screen.indexOf('Future<void> _openCollectiveInviteCode()');
    final end = screen.indexOf('Future<void>', start + 20);
    final body = end == -1 ? screen.substring(start) :
        screen.substring(start, end);
    expect(body, isNot(contains('final controller = TextEditingController()')));
    expect(body, isNot(contains('controller.dispose()')));
  });
}
