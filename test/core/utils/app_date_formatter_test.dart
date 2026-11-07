import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/app_date_formatter.dart';

void main() {
  group('Booking time parsing', () {
    test('Arabic-Indic and Persian digits use the same clock', () {
      expect(AppDateFormatter.tryParseTimeToMinutes('٠٤:٣٠ م'), 990);
      expect(AppDateFormatter.tryParseTimeToMinutes('۰۴:۳۰ PM'), 990);
      expect(AppDateFormatter.tryParseTimeToMinutes('١٢:٠٠ ص'), 0);
    });
    test('12 AM and 12 PM are distinct', () {
      expect(AppDateFormatter.tryParseTimeToMinutes('12:00 AM'), 0);
      expect(AppDateFormatter.tryParseTimeToMinutes('12:00 PM'), 720);
      expect(AppDateFormatter.tryParseTimeToMinutes('23:59'), 1439);
    });
    test('invalid values are rejected without accepting prefixes', () {
      for (final input in ['25:00', '12:60', '0 PM', '13 PM', '4 PM garbage', '4:99', '']) {
        expect(AppDateFormatter.tryParseTimeToMinutes(input), isNull, reason: input);
      }
    });
    test('legacy hour parser preserves fallback on invalid input', () {
      expect(AppDateFormatter.parseTimeToHour('invalid', defaultHour: 16), 16);
      expect(AppDateFormatter.parseTimeToHour('12:00 AM'), 0);
      expect(AppDateFormatter.parseTimeToHour('12:00 PM'), 12);
    });
  });
}
