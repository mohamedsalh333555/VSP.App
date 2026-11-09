import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsp_application/core/services/notification/notification_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationFilterService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getPrefKeyForType maps known notification types correctly', () {
      expect(NotificationFilterService.getPrefKeyForType('chat'), equals('notif_chat'));
      expect(NotificationFilterService.getPrefKeyForType('booking_new'), equals('notif_cash_bookings'));
      expect(NotificationFilterService.getPrefKeyForType('booking_confirmed'), equals('notif_cash_bookings'));
      expect(NotificationFilterService.getPrefKeyForType('team_transfer'), equals('notif_team_transfers'));
      expect(NotificationFilterService.getPrefKeyForType('match_reminder'), equals('notif_match_reminders'));
      expect(NotificationFilterService.getPrefKeyForType('challenge'), equals('notif_challenge_results'));
      expect(NotificationFilterService.getPrefKeyForType('unknown_custom_type'), isNull);
      expect(NotificationFilterService.getPrefKeyForType(null), isNull);
    });

    test('notification category lookup handles case and surrounding spaces', () {
      expect(NotificationFilterService.getPrefKeyForType('  CHAT  '), 'notif_chat');
      expect(NotificationFilterService.getPrefKeyForType(' BOOKING_NEW ', isOwner: true),
          'notif_owner_new_bookings');
      expect(NotificationFilterService.getPrefKeyForType('  '), isNull);
    });

    test('legacy notification type spelling maps to the same preferences', () {
      expect(NotificationFilterService.getPrefKeyForType('BOOKING-REMINDER'),
          'notif_cash_bookings');
      expect(NotificationFilterService.getPrefKeyForType(
        'booking reminder', isOwner: true,
      ), 'notif_owner_new_bookings');
      expect(NotificationFilterService.getPrefKeyForType('MATCH START REMINDER'),
          'notif_match_reminders');
      expect(NotificationFilterService.getPrefKeyForType('challenge-result'),
          'notif_challenge_results');
    });

    test('shouldShowNotification respects general master toggle', () async {
      SharedPreferences.setMockInitialValues({
        'notif_general': false,
        'notif_chat': true,
      });

      final prefs = await SharedPreferences.getInstance();
      final shouldShow = await NotificationFilterService.shouldShowNotification('chat', prefs: prefs);
      expect(shouldShow, isFalse);
    });

    test('shouldShowNotification checks specific category toggle', () async {
      SharedPreferences.setMockInitialValues({
        'notif_general': true,
        'notif_chat': false,
        'notif_cash_bookings': true,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(await NotificationFilterService.shouldShowNotification('chat', prefs: prefs), isFalse);
      expect(await NotificationFilterService.shouldShowNotification('booking_confirmed', prefs: prefs), isTrue);
    });

    test('notification preferences respect owner-specific opt-out', () async {
      SharedPreferences.setMockInitialValues({
        'notif_general': true,
        'notif_owner_new_bookings': false,
        'notif_cash_bookings': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await NotificationFilterService.shouldShowNotification(
        'BOOKING_NEW', prefs: prefs, isOwner: true,
      ), isFalse);
      expect(await NotificationFilterService.shouldShowNotification(
        'BOOKING_NEW', prefs: prefs,
      ), isTrue);
    });

    test('deep links accept legacy snake-case IDs and trim whitespace', () {
      expect(
        NotificationFilterService.resolveDeepLinkRoute({'booking_id': '  b-123  '}),
        '/match/b-123',
      );
      expect(
        NotificationFilterService.resolveDeepLinkRoute({'team_id': 't_456'}),
        '/team/t_456',
      );
    });

    test('malformed modern ID does not hide a valid legacy ID', () {
      expect(
        NotificationFilterService.resolveDeepLinkRoute({
          'bookingId': '../admin',
          'booking_id': 'valid-booking',
        }),
        '/match/valid-booking',
      );
      expect(
        NotificationFilterService.resolveDeepLinkRoute({
          'teamId': 42,
          'team_id': 'valid-team',
        }),
        '/team/valid-team',
      );
    });

    test('deep links reject route injection, empty IDs and malformed types', () {
      for (final unsafe in <dynamic>[
        '../admin',
        '/admin',
        'a/b',
        'a%2Fb',
        'id?next=admin',
        'id#fragment',
        'a b',
        '  ',
        'x' * 129,
        123,
      ]) {
        expect(
          NotificationFilterService.resolveDeepLinkRoute({'bookingId': unsafe}),
          '/notifications',
          reason: 'Unsafe booking ID: $unsafe',
        );
      }
      expect(
        NotificationFilterService.resolveDeepLinkRoute({
          'bookingId': '../admin',
          'team_id': 'safe_team',
        }),
        '/team/safe_team',
      );
    });

    test('unsafe legacy IDs do not override safe modern IDs', () {
      expect(NotificationFilterService.resolveDeepLinkRoute({
        'bookingId': 'valid_booking',
        'booking_id': '../admin',
      }), '/match/valid_booking');
      expect(NotificationFilterService.resolveDeepLinkRoute({
        'teamId': 'safe-team',
        'team_id': 'bad?redirect',
      }), '/team/safe-team');
    });

    test('resolveDeepLinkRoute returns booking, team, or notification center route', () {
      expect(
        NotificationFilterService.resolveDeepLinkRoute({'bookingId': 'b-123'}),
        equals('/match/b-123'),
      );
      expect(
        NotificationFilterService.resolveDeepLinkRoute({'teamId': 't-456'}),
        equals('/team/t-456'),
      );
      expect(
        NotificationFilterService.resolveDeepLinkRoute({}),
        equals('/notifications'),
      );
    });
  });
}
