import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';
import '../../../screens/owner_bookings_screen.dart';

/// Top filters row for Pro Insights: Venue Dropdown and Time Period Dropdown side-by-side.
class InsightsTopFiltersRow extends StatelessWidget {
  final String selectedStadiumFilter;
  final String selectedTimePeriod;
  final List<Stadium> stadiums;
  final ValueChanged<String> onStadiumFilterChanged;
  final ValueChanged<String> onTimePeriodChanged;
  final bool isArabic;

  const InsightsTopFiltersRow({
    super.key,
    required this.selectedStadiumFilter,
    required this.selectedTimePeriod,
    required this.stadiums,
    required this.onStadiumFilterChanged,
    required this.onTimePeriodChanged,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final periodOptions = [
      {'key': 'today', 'label': isArabic ? 'اليوم' : 'Today'},
      {'key': 'yesterday', 'label': isArabic ? 'أمس' : 'Yesterday'},
      {'key': 'week', 'label': isArabic ? 'الأسبوع' : 'This Week'},
      {'key': 'month', 'label': isArabic ? 'الشهر' : 'This Month'},
      {'key': 'all', 'label': isArabic ? 'الكل' : 'All Time'},
    ];

    return Row(
      children: [
        // 1. Stadium Filter Dropdown
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141417),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStadiumFilter,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 12),
                selectedItemBuilder: (context) {
                  final items = [
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text(
                        isArabic ? 'جميع الملاعب' : 'All Pitches',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ...stadiums.map((s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )),
                  ];
                  return items
                      .map((item) => Align(alignment: Alignment.centerRight, child: item.child))
                      .toList();
                },
                items: [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text(
                      isArabic ? 'جميع الملاعب' : 'All Pitches',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: selectedStadiumFilter == 'all' ? VSPColors.accent : VSPColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: selectedStadiumFilter == 'all' ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  ...stadiums.map((s) => DropdownMenuItem<String>(
                        value: s.id,
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: selectedStadiumFilter == s.id ? VSPColors.accent : VSPColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: selectedStadiumFilter == s.id ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      )),
                ],
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    onStadiumFilterChanged(val);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 2. Time Period Dropdown
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141417),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedTimePeriod,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 12),
                selectedItemBuilder: (context) {
                  return periodOptions.map((p) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        p['label']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: periodOptions.map((p) {
                  final isCurrent = selectedTimePeriod == p['key'];
                  return DropdownMenuItem<String>(
                    value: p['key'],
                    child: Text(
                      p['label']!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: isCurrent ? VSPColors.accent : VSPColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    onTimePeriodChanged(val);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Empty state when no bookings exist yet for the selected filter or venue.
class InsightsEmptyState extends StatelessWidget {
  final Function(int)? onNavigateTab;
  final bool isArabic;

  const InsightsEmptyState({
    super.key,
    this.onNavigateTab,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.chart_21_copy, size: 28, color: Colors.white54),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'التحليلات في انتظار أول حجز' : 'Awaiting Your First Booking',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'ستظهر الرسوم البيانية ومؤشرات الأداء تلقائياً بمجرد تسجيل أول حجز.'
                : 'Charts and performance metrics will appear after your first booking.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (onNavigateTab != null) {
                onNavigateTab!(3);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Text(
                isArabic ? 'إدارة الحجوزات' : 'Go to Bookings',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
