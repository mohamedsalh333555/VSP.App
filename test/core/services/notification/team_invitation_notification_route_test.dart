import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/services/notification/team_invitation_notification_route.dart';

void main() {
  const invitedUser = '20000000-0000-0000-0000-000000000201';
  const inviteId = '60000000-0000-0000-0000-000000000101';
  const recipient = <String, dynamic>{
    'source': 'team_membership',
    'event': 'invitation_received',
    'invited_user_id': invitedUser,
    'invitation_id': inviteId,
  };

  test('invited player can open their own invitation inbox', () {
    expect(TeamInvitationNotificationRoute.opensCurrentPlayerInbox(
      recipient, invitedUser), isTrue);
  });

  test('foreign, anonymous and switched accounts cannot route', () {
    for (final user in <String?>[
      null, '', '   ', '30000000-0000-0000-0000-000000000301'
    ]) {
      expect(TeamInvitationNotificationRoute.opensCurrentPlayerInbox(
        recipient, user), isFalse);
    }
  });

  test('accepted/declined captain notices do not open player invite inbox', () {
    for (final event in ['invitation_accepted','invitation_declined',
      'booking_cancelled','unknown']) {
      expect(TeamInvitationNotificationRoute.opensCurrentPlayerInbox(
        {...recipient,'event':event}, invitedUser), isFalse);
    }
  });

  test('missing or spoofed event recipient and source are never routable', () {
    final rejected = <Map<String, dynamic>?>[
      null,
      {},
      {...recipient,'source':'booking'},
      {...recipient,'invited_user_id':'someone-else'},
      {...recipient}..remove('invited_user_id'),
      {...recipient}..remove('invitation_id'),
      {...recipient,'invitation_id':'  '},
      {...recipient,'invitation_id':7},
    ];
    for (final data in rejected) {
      expect(TeamInvitationNotificationRoute.opensCurrentPlayerInbox(
        data,invitedUser),isFalse);
    }
  });
}
