import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository reports failed invitations without claiming they were sent', () {
    final source = File('lib/core/repositories/team_repository.dart').readAsStringSync();
    expect(source, contains('final List<String> failedInvitationUserIds'));
    expect(source, contains('failedInvitationUserIds.clear();'));
    expect(source, contains('failedInvitationUserIds.add(userId);'));
  });

  test('captain sees a partial-success warning after creating a team', () {
    final source = File(
      'lib/features/player/widgets/my_team/my_team_controller.dart',
    ).readAsStringSync();
    expect(source, contains('final repository = TeamRepository();'));
    expect(source, contains('final failedInvitations = repository.failedInvitationUserIds.length;'));
    expect(source, contains('failedInvitations > 0'));
    expect(source, contains('VSPColors.warning'));
  });
}
