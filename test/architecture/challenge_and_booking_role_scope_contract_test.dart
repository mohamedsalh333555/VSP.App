import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role switch invalidates in-flight captain challenge context', () {
    final source = File(
      'lib/features/player/screens/challenge_select_team_screen.dart',
    ).readAsStringSync();
    expect(source, contains('final userId = auth.isOwner ? null : auth.currentUser?.id;'));
    expect(source, contains('final uid = auth.isOwner ? null : (expectedUserId ?? auth.currentUser?.id);'));
    expect(source, contains('final uid = auth.isOwner ? null : auth.currentUser?.id;'));
    expect(source, contains('final lookupUserId = lookupAuth.isOwner ? null : lookupAuth.currentUser?.id;'));
  });

  test('booking preflight rejects owners even on same-user role changes',
      () {
    final source = File(
      'lib/features/player/widgets/booking/booking_confirmation_handler.dart',
    ).readAsStringSync();
    expect(source, contains('currentUserModel.uid != userId || !currentUserModel.isPlayer'));
    expect(source, contains('authProvider.isOwner'));
    expect(source, contains('active.userModel?.isPlayer == true && !active.isOwner'));
    expect(source, contains('bool isSameUser() {'));
  });
}
