import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/vsp_money_formatter.dart';

void main() {
  test('preserves meaningful monetary decimals without trailing zero noise', () {
    expect(VSPMoneyFormatter.amount(150), '150');
    expect(VSPMoneyFormatter.amount(150.5), '150.5');
    expect(VSPMoneyFormatter.amount(150.75), '150.75');
  });

  test('does not render non-finite monetary values as a price', () {
    expect(VSPMoneyFormatter.amount(double.nan), '—');
    expect(VSPMoneyFormatter.amount(double.infinity), '—');
  });
}
