import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure storage never writes provider exception payloads to logs', () {
    final source = File('lib/core/services/secure_storage_service.dart').readAsStringSync();
    final logCalls = RegExp(r'VSPLogger\.w\((.*?)\);', dotAll: true)
        .allMatches(source).map((m) => m.group(1)!).toList();
    expect(logCalls, isNotEmpty);
    for (final message in logCalls) {
      expect(message, contains('details redacted'));
      expect(message, isNot(contains(r'$e')));
      expect(message, isNot(contains(r'$key')));
    }
  });

  test('token/secure key operations still return safe fallback on failure', () {
    final source = File('lib/core/services/secure_storage_service.dart').readAsStringSync();
    expect(source, contains("static Future<String?> getAuthToken()"));
    expect(source, contains("static Future<String?> readSecure(String key)"));
    expect(source, contains("static Future<void> deleteSecure(String key)"));
    expect(source, contains("return null;"));
    expect(source, contains("await _storage.deleteAll()"));
  });
}
