import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mark-all action keeps the initiating user identity across await', () {
    final source = File(
      'lib/features/player/screens/notifications_center_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf('final requestUserId = _userId;');
    final guard = source.indexOf('if (requestUserId.isEmpty) return;', start);
    final request = source.indexOf('markAllAsRead(requestUserId)', start);
    final accountCheck = source.indexOf('_userId != requestUserId', request);
    expect(start, greaterThanOrEqualTo(0));
    expect(guard, greaterThan(start));
    expect(request, greaterThan(guard));
    expect(accountCheck, greaterThan(request));
  });
}
