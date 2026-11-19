import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/notification_models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8).toIso8601String();
  test('accepts snake-case notification rows without repository mapping', () {
    final notification = AppNotification.fromMap({
      'id': 'snake-1', 'title': 'Booking',
      'message': 'Old message', 'is_read': true,
      'created_at': now, 'booking_id': 'booking-1',
    });
    expect(notification.body, 'Old message');
    expect(notification.isRead, isTrue);
    expect(notification.bookingId, 'booking-1');
    expect(notification.createdAt, DateTime.parse(now));
  });
  test('legacy Unix timestamps retain chronological ordering', () {
    const seconds = 1794096000;
    const milliseconds = seconds * 1000;
    for (final timestamp in <Object>[
      seconds,
      milliseconds,
      '$seconds',
      '$milliseconds',
    ]) {
      final notification = AppNotification.fromMap({
        'id': 'unix-time',
        'created_at': timestamp,
      });
      expect(
        notification.createdAt.millisecondsSinceEpoch,
        milliseconds,
        reason: 'timestamp=$timestamp',
      );
    }
  });
  test('out-of-range numeric timestamps do not crash inbox parsing', () {
    for (final timestamp in <Object>[
      8640000000000001,
      -8640000000000001,
      1e30,
      -1e30,
      double.infinity,
      double.nan,
      '1e30',
    ]) {
      final notification = AppNotification.fromMap({
        'id': 'invalid-date',
        'created_at': timestamp,
      });
      expect(
        notification.createdAt.millisecondsSinceEpoch,
        0,
        reason: 'timestamp=$timestamp',
      );
    }
  });
  test('malformed legacy timestamp does not crash notification list', () {
    final notification = AppNotification.fromMap({
      'id': 'broken-1', 'created_at': 'not-a-date',
      'is_read': 'true',
    });
    expect(notification.createdAt.millisecondsSinceEpoch, 0);
    expect(notification.isRead, isTrue);
  });
  test('missing timestamp has stable epoch fallback, not the current clock', () {
    final notification = AppNotification.fromMap({'id': 'missing-date'});
    expect(notification.createdAt.millisecondsSinceEpoch, 0);
    expect(notification.isRead, isFalse);
  });
  test('malformed metadata keys do not break the notification inbox', () {
    final notification = AppNotification.fromMap({
      'id': 'metadata-1',
      'metadata': {1: 'bad key', 'booking_id': 'b-1'},
    });
    expect(notification.metadata, {'booking_id': 'b-1'});
  });
  test('legacy string fields and boolean read flag remain usable', () {
    final notification = AppNotification.fromMap({
      'id': 'types-1', 'title': 123, 'type': 42,
      'body': 100, 'isRead': 1, 'createdAt': now,
    });
    expect(notification.title, '123');
    expect(notification.type, '42');
    expect(notification.body, '100');
    expect(notification.isRead, isTrue);
  });
  test('legacy string numeric read flags are parsed safely', () {
    expect(AppNotification.fromMap({'id': 'read', 'is_read': ' 1 '}).isRead, isTrue);
    expect(AppNotification.fromMap({'id': 'unread', 'is_read': '0'}).isRead, isFalse);
    expect(AppNotification.fromMap({'id': 'unknown', 'is_read': 'maybe'}).isRead, isFalse);
  });
  test('reads legacy message when body is absent', () {
    final notification = AppNotification.fromMap({
      'id': 'legacy-1', 'title': 'Match', 'message': 'Old message',
      'createdAt': now,
    });
    expect(notification.body, 'Old message');
  });
  test('prefers canonical body over legacy message', () {
    final notification = AppNotification.fromMap({
      'id': 'modern-1', 'title': 'Match', 'body': 'New body',
      'message': 'Old message', 'createdAt': now,
    });
    expect(notification.body, 'New body');
  });
  test('falls back for whitespace-only canonical body', () {
    final notification = AppNotification.fromMap({
      'id': 'legacy-2', 'title': 'Match', 'body': '   ',
      'message': 'Visible message', 'createdAt': now,
    });
    expect(notification.body, 'Visible message');
  });
}
