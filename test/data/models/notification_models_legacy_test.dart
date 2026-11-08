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
