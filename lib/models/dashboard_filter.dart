// lib/models/dashboard_filter.dart

enum DateFilterType {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

class DashboardFilter {
  final DateFilterType type;
  final DateTime startDate;
  final DateTime endDate;
  final String? courtId; // null = جميع الملاعب

  const DashboardFilter({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.courtId,
  });

  /// UTC ISO strings for Supabase query alignment
  String get startIsoUtc => startDate.toUtc().toIso8601String();
  String get endIsoUtc => endDate.toUtc().toIso8601String();

  /// خيارات الفلاتر الزمنية الموحدة للمشروع بالكامل
  static List<Map<String, String>> get filterOptions => const [
    {'key': 'today', 'ar': 'اليوم', 'en': 'Today'},
    {'key': 'yesterday', 'ar': 'أمس', 'en': 'Yesterday'},
    {'key': 'week', 'ar': 'هذا الأسبوع', 'en': 'This Week'},
    {'key': 'month', 'ar': 'هذا الشهر', 'en': 'This Month'},
    {'key': 'year', 'ar': 'هذا العام', 'en': 'This Year'},
    {'key': 'custom', 'ar': 'تاريخ مخصص...', 'en': 'Custom...'},
  ];

  /// استرجاع الخيارات مع التسميات المناسبة للغة الحالية
  static List<Map<String, String>> getOptionsForLanguage(bool isArabic) {
    return filterOptions.map((opt) => {
      'key': opt['key']!,
      'label': isArabic ? opt['ar']! : opt['en']!,
      'labelAr': opt['ar']!,
      'labelEn': opt['en']!,
    }).toList();
  }

  // الـ label الديناميكي اللي هيظهر في الكروت
  String get periodLabel {
    switch (type) {
      case DateFilterType.today:
        return 'اليوم';
      case DateFilterType.yesterday:
        return 'أمس';
      case DateFilterType.thisWeek:
        return 'هذا الأسبوع';
      case DateFilterType.thisMonth:
        return 'هذا الشهر';
      case DateFilterType.thisYear:
        return 'هذا العام';
      case DateFilterType.custom:
        return 'من ${_fmt(startDate)} إلى ${_fmt(endDate)}';
    }
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  // factory constructors جاهزة
  factory DashboardFilter.today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return DashboardFilter(
      type: DateFilterType.today,
      startDate: start,
      endDate: start.add(const Duration(days: 1)),
    );
  }

  factory DashboardFilter.yesterday() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return DashboardFilter(
      type: DateFilterType.yesterday,
      startDate: start,
      endDate: DateTime(now.year, now.month, now.day),
    );
  }

  factory DashboardFilter.thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final s = DateTime(start.year, start.month, start.day);
    return DashboardFilter(
      type: DateFilterType.thisWeek,
      startDate: s,
      endDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );
  }

  factory DashboardFilter.thisMonth() {
    final now = DateTime.now();
    return DashboardFilter(
      type: DateFilterType.thisMonth,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 1),
    );
  }

  factory DashboardFilter.thisYear() {
    final now = DateTime.now();
    return DashboardFilter(
      type: DateFilterType.thisYear,
      startDate: DateTime(now.year, 1, 1),
      endDate: DateTime(now.year + 1, 1, 1),
    );
  }

  factory DashboardFilter.custom(DateTime start, DateTime end) {
    return DashboardFilter(
      type: DateFilterType.custom,
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day).add(const Duration(days: 1)),
    );
  }

  DashboardFilter copyWith({String? courtId}) => DashboardFilter(
        type: type,
        startDate: startDate,
        endDate: endDate,
        courtId: courtId ?? this.courtId,
      );
}
