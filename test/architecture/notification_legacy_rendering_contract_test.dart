import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('actual notification center delegates displayed text to resolver', () {
    final screen = File(
      'lib/features/player/screens/notifications_center_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/core/repositories/notification_repository.dart',
    ).readAsStringSync();
    expect(screen, contains('NotificationDisplayTextResolver.resolve('));
    expect(
      screen,
      contains('_localizeNotificationText(context, notification, isTitle: false)'),
    );
    expect(repository, contains("'message': data['message']"));
    expect(repository, contains("'body': data['body']"));
  });
}
