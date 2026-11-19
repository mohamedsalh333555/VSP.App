import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/app_error_handler.dart';

void main() {
  test('server price mismatch is explained without exposing the raw RPC code', () {
    final arabic = AppErrorHandler.formatError(
      Exception('PRICE_MISMATCH'),
      isArabic: true,
    );
    final english = AppErrorHandler.formatError(
      Exception('PRICE_MISMATCH'),
      isArabic: false,
    );
    expect(arabic, contains('سعر الملعب'));
    expect(english, contains('price changed'));
    expect(arabic, isNot(contains('PRICE_MISMATCH')));
  });
}
