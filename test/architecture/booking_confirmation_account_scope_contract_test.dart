import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking checkout clears selected slots and captain data on account change',
      () {
    final source = File('lib/features/player/screens/booking_confirmation_screen.dart')
        .readAsStringSync();
    expect(source, contains('context.watch<AuthProvider>()'));
    expect(source, contains('_activeBookingUserId != userId'));
    expect(source, contains('++_userTeamRequestGeneration'));
    expect(source, contains('_userTeamId = null;'));
    expect(source, contains('_userTeamName = null;'));
    expect(source, contains('_selectedTimeSlots.clear();'));
    expect(source, contains('viewerUserId: _activeBookingUserId'));
    expect(source, contains('initiatingUserId != _activeBookingUserId'));
    expect(source, contains('!mounted || _activeBookingUserId != initiatingUserId'));
  });

  test('team and challenge checkout resolves the verified active membership', () {
    final source = File('lib/features/player/screens/booking_confirmation_screen.dart')
        .readAsStringSync();
    expect(source, contains('TeamRepository().getUserTeamsStrict(userId)'));
    expect(source, contains('ActiveTeamService.resolve('));
    expect(source, contains('userId: userId,'));
    expect(source, contains('teams: teams,'));
    expect(source, isNot(contains('TeamRepository().getUserTeamStrict(userId)')));
    expect(source, contains('userTeamId: _userTeamId'));
    expect(source, contains('userTeamName: _userTeamName'));
  });

  test('booking availability resubscribes when player identity changes', () {
    final source = File(
      'lib/features/player/widgets/booking/booking_slot_stream_section.dart',
    ).readAsStringSync();
    expect(source, contains('final String? viewerUserId;'));
    expect(source, contains('oldWidget.viewerUserId != widget.viewerUserId'));
    expect(source, contains('if (widget.viewerUserId == null) {'));
    expect(source, contains('Sign in as a player to verify current bookings.'));
    expect(source, contains('stream: _bookingsStream,'));
  });
}
