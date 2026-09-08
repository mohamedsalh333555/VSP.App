/// Pure domain calculator and data provider for VSP date picker dialogs.
class VspDatePickerCalculator {
  const VspDatePickerCalculator._();

  /// Comprehensive list of 12 months with numbers and bilingual names.
  static const List<Map<String, dynamic>> months = [
    {'number': 1, 'nameAr': 'يناير', 'nameEn': 'January'},
    {'number': 2, 'nameAr': 'فبراير', 'nameEn': 'February'},
    {'number': 3, 'nameAr': 'مارس', 'nameEn': 'March'},
    {'number': 4, 'nameAr': 'أبريل', 'nameEn': 'April'},
    {'number': 5, 'nameAr': 'مايو', 'nameEn': 'May'},
    {'number': 6, 'nameAr': 'يونيو', 'nameEn': 'June'},
    {'number': 7, 'nameAr': 'يوليو', 'nameEn': 'July'},
    {'number': 8, 'nameAr': 'أغسطس', 'nameEn': 'August'},
    {'number': 9, 'nameAr': 'سبتمبر', 'nameEn': 'September'},
    {'number': 10, 'nameAr': 'أكتوبر', 'nameEn': 'October'},
    {'number': 11, 'nameAr': 'نوفمبر', 'nameEn': 'November'},
    {'number': 12, 'nameAr': 'ديسمبر', 'nameEn': 'December'},
  ];

  /// Calculates total days in a month safely accounting for leap years.
  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) return 30;
    return DateTime(year, month + 1, 0).day;
  }

  /// Generates a descending list of years from [maxYear] down to [minYear].
  static List<int> generateYears({required int minYear, required int maxYear}) {
    if (minYear > maxYear) return [];
    return List.generate(
      maxYear - minYear + 1,
      (index) => maxYear - index,
    );
  }

  /// Returns the localized name of the month (1-indexed).
  static String getMonthName(int monthNumber, {required bool isArabic}) {
    if (monthNumber < 1 || monthNumber > 12) return '$monthNumber';
    final month = months[monthNumber - 1];
    return isArabic ? (month['nameAr'] as String) : (month['nameEn'] as String);
  }

  /// Verifies whether the user is allowed to tap/navigate directly to a given step.
  static bool canNavigateToStep({
    required int targetStep,
    int? selectedYear,
    int? selectedMonth,
  }) {
    if (targetStep == 0) return true;
    if (targetStep == 1 && selectedYear != null) return true;
    if (targetStep == 2 && selectedMonth != null) return true;
    return false;
  }
}
