import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils Tests', () {
    test('Normalizes standard Egyptian 11-digit numbers', () {
      expect(PhoneUtils.normalize('01012345678'), equals('01012345678'));
      expect(PhoneUtils.normalize('01112345678'), equals('01112345678'));
      expect(PhoneUtils.normalize('01212345678'), equals('01212345678'));
      expect(PhoneUtils.normalize('01512345678'), equals('01512345678'));
    });

    test('Converts Eastern Arabic numerals to standard Western numerals', () {
      expect(PhoneUtils.normalize('٠١٠١٢٣٤٥٦٧٨'), equals('01012345678'));
      expect(PhoneUtils.normalize('٠١١٩٨٧٦٥٤٣٢'), equals('01198765432'));
    });

    test('Normalizes international +20 prefix to standard local national format', () {
      expect(PhoneUtils.normalize('+201012345678'), equals('01012345678'));
      expect(PhoneUtils.normalize('00201012345678'), equals('01012345678'));
    });

    test('Handles formatted strings with spaces and hyphens', () {
      expect(PhoneUtils.normalize('010-1234-5678'), equals('01012345678'));
      expect(PhoneUtils.normalize('010 1234 5678'), equals('01012345678'));
    });

    test('toE164 converts to official international standard', () {
      expect(PhoneUtils.toE164('01012345678'), equals('+201012345678'));
    });

    test('compare matches local and international representation', () {
      expect(PhoneUtils.compare('01012345678', '+201012345678'), isTrue);
      expect(PhoneUtils.compare('٠١٠١٢٣٤٥٦٧٨', '01012345678'), isTrue);
    });

    test('Null and empty inputs return null', () {
      expect(PhoneUtils.normalize(null), isNull);
      expect(PhoneUtils.normalize(''), isNull);
      expect(PhoneUtils.normalize('   '), isNull);
    });
  });
}
