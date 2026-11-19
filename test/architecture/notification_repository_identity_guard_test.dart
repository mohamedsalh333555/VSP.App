import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification writes and mutations reject missing identities', () {
    final source = File(
      'lib/core/repositories/notification_repository.dart',
    ).readAsStringSync();
    for (final method in [
      'sendNotification',
      'restoreNotification',
      'markNotificationAsRead',
      'markAllAsRead',
      'deleteNotification',
    ]) {
      final start = source.indexOf(' $method(');
      final guard = source.indexOf('userId.trim().isEmpty', start);
      final tryBlock = source.indexOf('try {', start);
      expect(start, greaterThanOrEqualTo(0), reason: method);
      expect(guard, greaterThan(start), reason: method);
      expect(guard, lessThan(tryBlock), reason: method);
    }
    expect(
      source,
      contains('userId.trim().isEmpty || notificationId.trim().isEmpty'),
    );
  });
}
