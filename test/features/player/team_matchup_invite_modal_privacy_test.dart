import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/features/player/widgets/team_profile/team_matchup_invite_modal.dart';

void main() {
  testWidgets('previous captain code disappears if account changes while sheet is open',
      (tester) async {
    final changes = ValueNotifier<int>(0);
    addTearDown(changes.dispose);
    var authorized = true;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showTeamMatchupInviteModal(
            context,
            '12345678',
            canReveal: () => authorized,
            authorizationChanges: changes,
          ),
          child: const Text('Open invite'),
        )),
      ),
    ));
    await tester.tap(find.text('Open invite'));
    await tester.pumpAndSettle();
    expect(find.text('12345678'), findsOneWidget);
    expect(find.byTooltip('Copy code'), findsOneWidget);

    authorized = false;
    changes.value++;
    await tester.pumpAndSettle();
    expect(find.text('12345678'), findsNothing);
    expect(find.byTooltip('Copy code'), findsNothing);
    expect(find.text('Invite code unavailable'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Invite code unavailable'), findsNothing);
  });

  testWidgets('copy action denies a revoked captain before change notification',
      (tester) async {
    var authorized = true;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showTeamMatchupInviteModal(
            context,
            '87654321',
            canReveal: () => authorized,
          ),
          child: const Text('Open invite'),
        )),
      ),
    ));
    await tester.tap(find.text('Open invite'));
    await tester.pumpAndSettle();
    expect(find.text('87654321'), findsOneWidget);
    authorized = false;
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(find.text('87654321'), findsNothing);
    expect(find.text('Open invite'), findsOneWidget);
  });
  testWidgets('failed clipboard copy leaves code available and offers Arabic retry feedback',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showTeamMatchupInviteModal(
            context,
            '12345678',
            canReveal: () => true,
          ),
          child: const Text('Open invite'),
        )),
      ),
    ));
    await tester.tap(find.text('Open invite'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('نسخ الكود'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('12345678'), findsOneWidget);
    expect(find.text('تعذر نسخ الكود. حاول مرة أخرى.'), findsOneWidget);
  });

  testWidgets('copy completion after captain revocation never announces success',
      (tester) async {
    final changes = ValueNotifier<int>(0);
    addTearDown(changes.dispose);
    final clipboardPending = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          await clipboardPending.future;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    var authorized = true;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showTeamMatchupInviteModal(
            context,
            '87654321',
            canReveal: () => authorized,
            authorizationChanges: changes,
          ),
          child: const Text('Open invite'),
        )),
      ),
    ));
    await tester.tap(find.text('Open invite'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pump();
    authorized = false;
    changes.value++;
    await tester.pump();
    expect(find.text('87654321'), findsNothing);
    clipboardPending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Matchup code copied'), findsNothing);
    expect(find.text('87654321'), findsNothing);
  });

}
