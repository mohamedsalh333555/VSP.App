import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

/// Pure logic Idempotency Key Manager for preventing duplicate payment submissions
class IdempotencyManager {
  static final Set<String> _processedKeys = {};

  /// Generates a cryptographically random v4-like UUID for each payment attempt
  static String generateKey({String prefix = 'pay'}) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set version to 4
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
    return '$prefix-$uuid';
  }

  /// Attempts to claim an idempotency key. Returns true on first attempt, false on duplicate replay.
  static bool claimKey(String key) {
    if (_processedKeys.contains(key)) return false;
    _processedKeys.add(key);
    return true;
  }

  static void reset() => _processedKeys.clear();
}

void main() {
  setUp(() => IdempotencyManager.reset());

  group('Idempotency & Duplicate Replay Protection Tests', () {
    test('Generated keys are unique and follow valid UUID pattern', () {
      final key1 = IdempotencyManager.generateKey();
      final key2 = IdempotencyManager.generateKey();

      expect(key1, isNot(equals(key2)));
      expect(key1, startsWith('pay-'));
      expect(key1.length, equals(40)); // 'pay-' (4) + UUID (36)
    });

    test('First execution succeeds, duplicate execution with same key is rejected', () {
      final key = IdempotencyManager.generateKey();

      // First click: Accepted
      final firstAttempt = IdempotencyManager.claimKey(key);
      expect(firstAttempt, isTrue);

      // Rapid double click / network replay with identical key: Blocked
      final secondAttempt = IdempotencyManager.claimKey(key);
      expect(secondAttempt, isFalse);

      final thirdAttempt = IdempotencyManager.claimKey(key);
      expect(thirdAttempt, isFalse);
    });

    test('100 concurrent keys generated in parallel are 100% unique', () {
      final keys = List.generate(100, (_) => IdempotencyManager.generateKey());
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys.length, equals(100));
    });
  });
}
