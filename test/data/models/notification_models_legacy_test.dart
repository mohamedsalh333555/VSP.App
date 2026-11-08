import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/data/models/notification_models.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8).toIso8601String();
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
