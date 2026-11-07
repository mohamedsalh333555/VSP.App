import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard exposes recipient invitation inbox', () {
    final dashboard = File(
      'lib/features/player/screens/team_dashboard_screen.dart',
    ).readAsStringSync();
    expect(dashboard, contains('TeamInvitationsSheet(userId: _activeUserTeamScope!)'));
  });

  test('inbox offers accept decline and retry without optimistic membership', () {
    final source = File(
      'lib/features/player/widgets/team_invitations_sheet.dart',
    ).readAsStringSync();
    expect(source, contains('respondToTeamInvitation(id, accept: accept)'));
    expect(source, contains('_respond(id, false)'));
    expect(source, contains('_respond(id, true)'));
    expect(source, contains('snapshot.hasError'));
    expect(source, contains('setState(_refresh)'));
  });
}
