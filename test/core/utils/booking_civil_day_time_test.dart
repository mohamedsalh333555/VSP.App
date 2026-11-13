import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/app_date_formatter.dart';

void main() {
  test('civil days cross month and leap-year boundaries exactly once', () {
    final start = DateTime(2028, 2, 27);
    final days = List.generate(4, (i) => AppDateFormatter.addCivilDays(start, i));
    expect(days.map((d) => [d.year,d.month,d.day].join('-')).toList(), [
      '2028-2-27', '2028-2-28', '2028-2-29', '2028-3-1',
    ]);
    expect(days.every((date) => date.hour == 0 && date.minute == 0), isTrue);
  });

  test('Egyptian DST transition weeks yield 14 distinct consecutive civil dates', () {
    for (final start in [
      DateTime(2026, 4, 22),
      DateTime(2026, 10, 27),
    ]) {
      final days = List.generate(
        14, (i) => AppDateFormatter.addCivilDays(start, i),
      );
      expect(days.toSet().length, 14);
      for (var i = 1; i < days.length; i++) {
        final expected = DateTime(start.year, start.month, start.day + i);
        expect([days[i].year,days[i].month,days[i].day],
               [expected.year,expected.month,expected.day]);
        expect(days[i].hour, 0);
      }
    }
  });

  test('civil next date resets local time rather than adding 24 elapsed hours', () {
    final following = AppDateFormatter.addCivilDays(
      DateTime(2026, 10, 29, 16, 30), 1,
    );
    expect(following, DateTime(2026, 10, 30));
  });
}
