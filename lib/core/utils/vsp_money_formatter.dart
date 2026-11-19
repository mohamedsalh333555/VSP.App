/// Formats persisted monetary values without silently truncating decimals.
class VSPMoneyFormatter {
  const VSPMoneyFormatter._();

  static String amount(num value) {
    final number = value.toDouble();
    if (!number.isFinite) return '—';
    final fixed = number.toStringAsFixed(2);
    return fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed.endsWith('0')
            ? fixed.substring(0, fixed.length - 1)
            : fixed;
  }
}
