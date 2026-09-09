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
