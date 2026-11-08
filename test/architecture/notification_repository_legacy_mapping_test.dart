import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository forwards both body and legacy message to notification model', () {
    final repository = File(
      'lib/core/repositories/notification_repository.dart',
    ).readAsStringSync();
    final model = File(
      'lib/data/models/notification_models.dart',
    ).readAsStringSync();
    expect(repository, contains("'body': data['body']"));
    expect(repository, contains("'message': data['message']"));
    expect(repository, contains('AppNotification.fromFirestore(_mapToCamelCase(data)'));
    expect(model, contains("data['message']"));
  });
}
