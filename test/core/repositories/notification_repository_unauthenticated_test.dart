import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/repositories/notification_repository.dart';
import 'package:vsp_application/data/models/notification_models.dart';

void main() {
  group('NotificationRepository unauthenticated guards', () {
    final repository = NotificationRepository();

    test('blank user ID returns empty notifications without Supabase', () async {
      expect(await repository.getUserNotifications('').first, isEmpty);
    });

    test('whitespace user ID returns empty notifications without Supabase', () async {
      expect(await repository.getUserNotifications('   ').first, isEmpty);
    });

    test('blank user ID returns zero unread notifications without Supabase', () async {
      expect(await repository.getUnreadNotificationCount('').first, 0);
    });

    test('blank recipient cannot mutate notifications', () async {
      expect(await repository.markAllAsRead('  '), isFalse);
      expect(await repository.markNotificationAsRead('', 'notification-1'), isFalse);
      expect(await repository.markNotificationAsRead('user-1', ''), isFalse);
      expect(await repository.deleteNotification('', 'notification-1'), isFalse);
      expect(
        await repository.restoreNotification(
          '', AppNotification(
            id: 'n1', title: 'Test', body: 'Body', type: 'info',
            createdAt: DateTime.utc(2026, 11, 8),
          ),
        ),
        isFalse,
      );
    });
  });
}
