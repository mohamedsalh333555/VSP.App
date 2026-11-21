import '../../../../../core/ui/components/vsp_filter_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../../data/models.dart';
import '../../../../../models/dashboard_filter.dart';
import '../../../screens/owner_bookings_screen.dart';

/// Top filters row for Pro Insights: Venue Dropdown and Time Period Dropdown side-by-side.
class InsightsTopFiltersRow extends StatelessWidget {
  final String selectedStadiumFilter;
  final String selectedTimePeriod;
  final List<Stadium> stadiums;
  final ValueChanged<String> onStadiumFilterChanged;
  final ValueChanged<String> onTimePeriodChanged;
  final void Function(DateTime start, DateTime end)? onCustomRangeSelected;
  final bool isArabic;

  const InsightsTopFiltersRow({
    super.key,
    required this.selectedStadiumFilter,
    required this.selectedTimePeriod,
    required this.stadiums,
    required this.onStadiumFilterChanged,
    required this.onTimePeriodChanged,
    this.onCustomRangeSelected,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final periodOptions = DashboardFilter.getOptionsForLanguage(isArabic);

    return Row(
      children: [
        // 1. Stadium Filter Dropdown — shared compact charcoal style.
        Expanded(
          child: VSPFilterDropdown<String>(
            value: selectedStadiumFilter,
            items: ['all', ...stadiums.map((stadium) => stadium.id)],
            labelFor: (id) => id == 'all'
                ? (isArabic ? 'جميع الملاعب' : 'All Pitches')
                : stadiums.firstWhere((stadium) => stadium.id == id).name,
            onChanged: (val) {
              if (val == null) return;
              HapticFeedback.selectionClick();
              onStadiumFilterChanged(val);
            },
          ),
        ),
        const SizedBox(width: 10),

        // 2. Time Period Dropdown — preserve custom range behavior.
        Expanded(
          child: VSPFilterDropdown<String>(
            value: selectedTimePeriod,
            items: periodOptions.map((p) => p['key']!).toList(),
            labelFor: (key) => periodOptions
                .firstWhere((p) => p['key'] == key)['label']!,
            onChanged: (val) async {
              if (val == null) return;
              HapticFeedback.selectionClick();
              if (val == 'custom') {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: isArabic ? const Locale('ar') : const Locale('en'),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: VSPColors.textPrimary,
                        onPrimary: VSPColors.black,
                        surface: VSPColors.surface,
                        onSurface: VSPColors.textPrimary,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  if (onCustomRangeSelected != null) {
                    onCustomRangeSelected!(picked.start, picked.end);
                  } else {
                    onTimePeriodChanged('custom');
                  }
                }
              } else {
                onTimePeriodChanged(val);
              }
            },
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
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.chart_21_copy, size: 28, color: VSPColors.textMuted),
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
              color: VSPColors.textSecondary,
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
                color: VSPColors.textSecondary,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Text(
                isArabic ? 'إدارة الحجوزات' : 'Go to Bookings',
                style: const TextStyle(
                  color: VSPColors.black,
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
