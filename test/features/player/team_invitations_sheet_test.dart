import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/services/auth_service.dart';
import 'package:vsp_application/features/player/widgets/team_invitations_sheet.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _AuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class _AuthProvider extends AuthProvider {
  _AuthProvider(this.userId) : super(authService: _AuthService());

  final String userId;

  @override
  User? get currentUser => User.fromJson({
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '$userId@test.invalid',
        'created_at': '2026-01-01T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      });

  @override
  bool get isOwner => false;

  @override
  bool get isPlayer => true;
}

Widget _app({
  required String activeUserId,
  required Future<List<Map<String, dynamic>>> Function(String) load,
  required Future<void> Function(String, bool) respond,
  Future<void> Function()? onMembershipChanged,
}) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: _AuthProvider(activeUserId),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TeamInvitationsSheet(
          userId: activeUserId,
          loadInvitations: load,
          respondToInvitation: respond,
          onMembershipChanged: onMembershipChanged,
        ),
      ),
    ),
  );
}

Map<String, dynamic> _invitation(String id, String teamName) => {
      'id': id,
      'team_name': teamName,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads the inbox and accepts an invitation once', (tester) async {
    var loadCount = 0;
    var responseCount = 0;
    var membershipRefreshCount = 0;

    await tester.pumpWidget(
      _app(
        activeUserId: 'player-1',
        load: (_) async => loadCount++ == 0
            ? [_invitation('invite-1', 'Aswan Stars')]
            : [],
        respond: (id, accept) async {
          expect(id, 'invite-1');
          expect(accept, isTrue);
          responseCount++;
        },
        onMembershipChanged: () async {
          membershipRefreshCount++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aswan Stars'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(responseCount, 1);
    expect(membershipRefreshCount, 1);
    expect(find.text('No pending invitations'), findsOneWidget);
    expect(find.text('Invitation accepted'), findsOneWidget);
  });

  testWidgets('declines an invitation without refreshing membership',
      (tester) async {
    var loadCount = 0;
    var responseCount = 0;
    var membershipRefreshCount = 0;

    await tester.pumpWidget(
      _app(
        activeUserId: 'player-1',
        load: (_) async => loadCount++ == 0
            ? [_invitation('invite-2', 'Nile Team')]
            : [],
        respond: (id, accept) async {
          expect(id, 'invite-2');
          expect(accept, isFalse);
          responseCount++;
        },
        onMembershipChanged: () async {
          membershipRefreshCount++;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(responseCount, 1);
    expect(membershipRefreshCount, 0);
    expect(find.text('No pending invitations'), findsOneWidget);
    expect(find.text('Invitation declined'), findsOneWidget);
  });

  testWidgets('blocks duplicate responses while the first action is pending',
      (tester) async {
    final pending = Completer<void>();
    var responseCount = 0;

    await tester.pumpWidget(
      _app(
        activeUserId: 'player-1',
        load: (_) async => [_invitation('invite-3', 'Upper Egypt FC')],
        respond: (_, __) {
          responseCount++;
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final accept = find.text('Accept');
    await tester.tap(accept);
    await tester.tap(accept);
    await tester.pump();
    expect(responseCount, 1);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows a retryable load failure and recovers', (tester) async {
    var loadCount = 0;

    await tester.pumpWidget(
      _app(
        activeUserId: 'player-1',
        load: (_) async {
          if (loadCount++ == 0) throw StateError('offline');
          return [_invitation('invite-4', 'Recovered Team')];
        },
        respond: (_, __) async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load invitations'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recovered Team'), findsOneWidget);
  });
}
