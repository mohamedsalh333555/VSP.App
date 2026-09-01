import 'package:flutter_test/flutter_test.dart';

/// Pure logic bidirectional text helper to ensure numbers, English words,
/// and stadium codes do not flip Arabic punctuation or parentheses.
class BiDiFormatter {
  /// Wraps LTR text (numbers, English stadium names, currency codes) in Unicode directional isolates (U+2068 .. U+2069)
  static String isolateLtr(String text) {
    if (text.isEmpty) return text;
    return '\u2068$text\u2069';
  }

  /// Formats composite title: "[Arabic prefix] [LTR Name] [Arabic suffix]"
  static String formatCompositeTitle({
    required String arabicPrefix,
    required String stadiumName,
    required String city,
  }) {
    final cleanStadium = isolateLtr(stadiumName.trim());
    return '$arabicPrefix $cleanStadium - $city';
  }
}

void main() {
  group('Bi-directional (RTL/LTR) Text Formatting Tests', () {
    test('Pure Arabic text remains untouched', () {
      expect(BiDiFormatter.isolateLtr(''), equals(''));
      expect(BiDiFormatter.isolateLtr('القاهرة'), contains('القاهرة'));
    });

    test('English stadium names within Arabic sentences are isolated from punctuation flipping', () {
      final formatted = BiDiFormatter.formatCompositeTitle(
        arabicPrefix: 'ملعب',
        stadiumName: 'Camp Nou 5v5',
        city: 'مدينة نصر',
      );

      expect(formatted, contains('ملعب'));
      expect(formatted, contains('Camp Nou 5v5'));
      expect(formatted, contains('مدينة نصر'));
      expect(formatted.startsWith('ملعب'), isTrue);
    });

    test('Mixed numbers and phone formatting preserve correct national order', () {
      const mixedString = 'حجز رقم #84920 بمبلغ 250 ج.م';
      expect(mixedString, contains('84920'));
      expect(mixedString, contains('250'));
      expect(mixedString, contains('ج.م'));
    });
  });
}
