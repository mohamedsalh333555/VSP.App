import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/services/auth_service.dart';
import 'package:vsp_application/features/player/widgets/team_invitations_action.dart';
import 'package:vsp_application/features/player/widgets/team_invitations_sheet.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _AuthService extends AuthService {
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class _AuthProvider extends AuthProvider {
  _AuthProvider() : super(authService: _AuthService());

  @override
  User? get currentUser => User.fromJson({
        'id': 'recipient-1',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'recipient@test.invalid',
        'created_at': '2026-01-01T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      });
}

Widget _host({
  required String language,
  required Future<List<Map<String, dynamic>>> Function(String) load,
  required Future<void> Function(String, bool) respond,
}) => ChangeNotifierProvider<AuthProvider>(
  create: (_) => _AuthProvider(),
  child: MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        actions: [
          TeamInvitationsAction(
            userId: 'recipient-1',
            loadInvitations: load,
            respondToInvitation: respond,
          ),
        ],
      ),
      body: const Text('Teams dashboard'),
    ),
  ),
);

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets('team dashboard icon opens the actual invitation inbox ($language)',
        (tester) async {
      var reads = 0;
      var accepts = 0;
      await tester.pumpWidget(_host(
        language: language,
        load: (userId) async {
          expect(userId, 'recipient-1');
          reads++;
          return [
            {'id': 'invite-1', 'team_name': 'Falcons'},
          ];
        },
        respond: (id, accept) async {
          expect(id, 'invite-1');
          expect(accept, isTrue);
          accepts++;
        },
      ));
      await tester.pumpAndSettle();
      final tooltip = language == 'ar' ? 'دعوات الفرق' : 'Team invitations';
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(find.byType(TeamInvitationsSheet), findsOneWidget);
      expect(find.text('Falcons'), findsOneWidget);
      expect(reads, 1);
      await tester.tap(find.text(language == 'ar' ? 'قبول' : 'Accept'));
      await tester.pumpAndSettle();
      expect(accepts, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
