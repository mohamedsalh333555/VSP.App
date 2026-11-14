import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils Egyptian phone normalization', () {
    test('Arabic-Indic digits normalize to local Egyptian format', () {
      expect(PhoneUtils.normalize('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
    });
    test('Persian digits normalize to local Egyptian format', () {
      expect(PhoneUtils.normalize('۰۱۰۱۲۳۴۵۶۷۸'), '01012345678');
    });
    test('Egyptian international and national representations compare equal', () {
      expect(PhoneUtils.compare('+201012345678', '01012345678'), isTrue);
      expect(PhoneUtils.compare('٠١٠١٢٣٤٥٦٧٨', '+201012345678'), isTrue);
    });
    test('E164 supports Arabic-Indic and Persian numerals', () {
      expect(PhoneUtils.toE164('٠١٠١٢٣٤٥٦٧٨'), '+201012345678');
      expect(PhoneUtils.toE164('۰۱۰۱۲۳۴۵۶۷۸'), '+201012345678');
    });
    test('international 0020 prefix is not duplicated', () {
      expect(PhoneUtils.toE164('00201012345678'), '+201012345678');
      expect(PhoneUtils.compare('00201012345678', '01012345678'), isTrue);
    });
    test('blank or nonnumeric phone values are not comparable', () {
      expect(PhoneUtils.normalize(' -- '), isNull);
      expect(PhoneUtils.compare('', '+201012345678'), isFalse);
    });
  });
}
