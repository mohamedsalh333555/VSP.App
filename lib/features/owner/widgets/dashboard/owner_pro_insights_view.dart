import 'package:flutter/material.dart';
import '../../../../core/utils/owner_financial_calculator.dart';
import '../../../../data/models.dart';
import 'insights/insights_booking_types_card.dart';
import 'insights/insights_radial_hero_card.dart';
import 'insights/insights_revenue_sources_card.dart';
import 'insights/insights_strategic_kpis_grid.dart';
import 'insights/insights_top_filters_row.dart';

/// قسم التحليلات والقرارات التشغيلية اليومية للمالك (Strategic Business Insights Tab)
class OwnerProInsightsView extends StatelessWidget {
  final List<Booking> allBookings;
  final OwnerFinancialMetrics metrics;
  final List<Stadium> stadiums;
  final String selectedTimePeriod;
  final String selectedStadiumFilter;
  final ValueChanged<String> onTimePeriodChanged;
  final ValueChanged<String> onStadiumFilterChanged;
  final Function(int)? onNavigateTab;
  final bool isArabic;

  const OwnerProInsightsView({
    super.key,
    required this.allBookings,
    required this.metrics,
    required this.stadiums,
    required this.selectedTimePeriod,
    required this.selectedStadiumFilter,
    required this.onTimePeriodChanged,
    required this.onStadiumFilterChanged,
    this.onNavigateTab,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    // ── تصفية الحجوزات الصالحة (غير الملغية وحسب الملعب المحدد) ──
    final validBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (selectedStadiumFilter != 'all' && b.stadiumId != selectedStadiumFilter) return false;
      return true;
    }).toList();

    // حالة الفراغ عند عدم وجود أي حجوزات
    if (validBookings.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 6),
          InsightsTopFiltersRow(
            selectedStadiumFilter: selectedStadiumFilter,
            selectedTimePeriod: selectedTimePeriod,
            stadiums: stadiums,
            onStadiumFilterChanged: onStadiumFilterChanged,
            onTimePeriodChanged: onTimePeriodChanged,
            isArabic: isArabic,
          ),
          const SizedBox(height: 14),
          InsightsEmptyState(
            onNavigateTab: onNavigateTab,
            isArabic: isArabic,
          ),
        ],
      );
    }

    // ── تصنيف الحجوزات حسب الفترة الزمنية المحددة ──
    List<Booking> periodBookings = [];
    List<Booking> comparisonBookings = [];
    String periodLabel = isArabic ? 'اليوم' : 'Today';
    String comparisonLabel = isArabic ? 'أمس' : 'Yesterday';
    double totalAvailableHoursFactor = 1.0;

    switch (selectedTimePeriod) {
      case 'yesterday':
        periodLabel = isArabic ? 'أمس' : 'Yesterday';
        comparisonLabel = isArabic ? 'اليوم السابق' : 'Prev Day';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayStart);
        }).toList();
        final dayBeforeYesterday = yesterdayStart.subtract(const Duration(days: 1));
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(dayBeforeYesterday.subtract(const Duration(seconds: 1))) && d.isBefore(yesterdayStart);
        }).toList();
        totalAvailableHoursFactor = 1.0;
        break;

      case 'week':
        periodLabel = isArabic ? 'الأسبوع' : 'This Week';
        comparisonLabel = isArabic ? 'الأسبوع السابق' : 'Last Week';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(thisWeekStart.subtract(const Duration(seconds: 1)));
        }).toList();
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) && d.isBefore(thisWeekStart);
        }).toList();
        totalAvailableHoursFactor = 7.0;
        break;

      case 'month':
        periodLabel = isArabic ? 'الشهر' : 'This Month';
        comparisonLabel = isArabic ? 'الشهر السابق' : 'Last Month';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(thisMonthStart.subtract(const Duration(seconds: 1)));
        }).toList();
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(lastMonthStart.subtract(const Duration(seconds: 1))) && d.isBefore(thisMonthStart);
        }).toList();
        totalAvailableHoursFactor = 30.0;
        break;

      case 'all':
        periodLabel = isArabic ? 'الكل' : 'All-Time';
        comparisonLabel = isArabic ? 'إجمالي' : 'Overall';
        periodBookings = validBookings;
        comparisonBookings = [];
        totalAvailableHoursFactor = 30.0;
        break;

      case 'today':
      default:
        periodLabel = isArabic ? 'اليوم' : 'Today';
        comparisonLabel = isArabic ? 'أمس' : 'Yesterday';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(todayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd);
        }).toList();
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayStart);
        }).toList();
        totalAvailableHoursFactor = 1.0;
        break;
    }

    // =========================================================================
    // METRIC 1: HERO METRIC (إجمالي إيراد الفترة مقارنة بالطاقة الاستيعابية)
    // =========================================================================
    final double periodRevenue = periodBookings.fold(0.0, (sum, b) => sum + (b.totalPrice > 0 ? b.totalPrice : b.depositPaid));
    final double previousRevenue = comparisonBookings.fold(0.0, (sum, b) => sum + (b.totalPrice > 0 ? b.totalPrice : b.depositPaid));
    final double revenueChange = previousRevenue > 0
        ? ((periodRevenue - previousRevenue) / previousRevenue) * 100
        : (periodRevenue > 0 ? 100.0 : 0.0);

    // حساب الطاقة الاستيعابية القصوى للملعب للفترة المحددة
    final int activePitchCount = selectedStadiumFilter != 'all' ? 1 : (stadiums.isNotEmpty ? stadiums.length : 1);
    final double totalAvailableHours = activePitchCount * 16.0 * totalAvailableHoursFactor;
    final double pitchHourlyRate = stadiums.isNotEmpty && stadiums.first.pricePerHour > 0
        ? stadiums.first.pricePerHour
        : (periodRevenue > 0 && periodBookings.isNotEmpty ? (periodRevenue / periodBookings.length) : 300.0);
    final double maxCapacityRevenue = totalAvailableHours * pitchHourlyRate;
    final double ringProgress = maxCapacityRevenue > 0
        ? (periodRevenue / maxCapacityRevenue).clamp(0.0, 1.0)
        : 0.0;

    // =========================================================================
    // METRIC 2: REVENUE BREAKDOWN (تقسيم الإيراد: دفع رقمي vs كاش)
    // =========================================================================
    double digitalRevenue = 0.0;
    double cashRevenue = 0.0;
    for (final b in periodBookings) {
      final price = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      final method = b.paymentMethod.toLowerCase().trim();
      final bool isDigital = b.isPaid ||
          b.isDepositPaid ||
          b.depositPaid > 0 ||
          (method.isNotEmpty && method != 'cash' && method != 'كاش' && method != 'نقدي');

      if (isDigital) {
        digitalRevenue += price;
      } else {
        cashRevenue += price;
      }
    }
    final double digitalPct = periodRevenue > 0 ? (digitalRevenue / periodRevenue * 100) : 0.0;
    final double cashPct = periodRevenue > 0 ? (cashRevenue / periodRevenue * 100) : 0.0;

    // =========================================================================
    // METRIC 3: STRATEGIC BUSINESS METRICS (الإشغال الفعلي + الإيراد الضائع)
    // =========================================================================
    final int totalBookingsPeriod = periodBookings.length;
    final int onlinePaidCount = periodBookings.where((b) => b.isPaid).length;
    final double averageBookingPrice = totalBookingsPeriod > 0 ? (periodRevenue / totalBookingsPeriod) : 0.0;

    double totalHoursBookedPeriod = 0.0;
    for (final b in periodBookings) {
      final diffMins = b.endTime.difference(b.startTime).inMinutes;
      totalHoursBookedPeriod += diffMins > 0 ? (diffMins / 60.0) : 1.0;
    }

    final double occupancyRate = totalAvailableHours > 0
        ? ((totalHoursBookedPeriod / totalAvailableHours) * 100).clamp(0.0, 100.0)
        : 0.0;

    final double unbookedHours = (totalAvailableHours - totalHoursBookedPeriod).clamp(0.0, totalAvailableHours);
    final double lostRevenue = unbookedHours * pitchHourlyRate;

    // =========================================================================
    // METRIC 4: BOOKING TYPES BREAKDOWN (أنواع الحجوزات من إجمالي كل الحجوزات)
    // =========================================================================
    int personalCount = 0;
    int challengeCount = 0;
    int openJoinCount = 0;

    for (final b in validBookings) {
      if (b.bookingType == BookingType.challenge || b.bookingType == BookingType.team) {
        challengeCount++;
      } else if (b.bookingType == BookingType.openJoin) {
        openJoinCount++;
      } else {
        personalCount++;
      }
    }

    final int totalAllBookings = validBookings.length;
    final double personalPct = totalAllBookings > 0 ? (personalCount / totalAllBookings * 100) : 0.0;
    final double challengePct = totalAllBookings > 0 ? (challengeCount / totalAllBookings * 100) : 0.0;
    final double openJoinPct = totalAllBookings > 0 ? (openJoinCount / totalAllBookings * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // 0. TOP FILTERS ROW (زر فلتر الملاعب + زر فلتر الأيام في صف متقابل)
        InsightsTopFiltersRow(
          selectedStadiumFilter: selectedStadiumFilter,
          selectedTimePeriod: selectedTimePeriod,
          stadiums: stadiums,
          onStadiumFilterChanged: onStadiumFilterChanged,
          onTimePeriodChanged: onTimePeriodChanged,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 1. HERO CARD (مقياس المؤشرات الشعاعية)
        InsightsRadialHeroCard(
          currentRevenue: periodRevenue,
          previousRevenue: previousRevenue,
          revenueChange: revenueChange,
          ringProgress: ringProgress,
          maxCapacityRevenue: maxCapacityRevenue,
          periodLabel: periodLabel,
          comparisonLabel: comparisonLabel,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 2. REVENUE SOURCES CARD (طرق التحصيل: رقمي وكاش)
        InsightsRevenueSourcesCard(
          digitalRevenue: digitalRevenue,
          digitalPct: digitalPct,
          cashRevenue: cashRevenue,
          cashPct: cashPct,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 3. 2x2 STRATEGIC KPI SQUARES (4 مربعات قابلة للنقر لشرح المؤشرات)
        InsightsStrategicKpisGrid(
          totalBookingsToday: totalBookingsPeriod,
          onlinePaidCount: onlinePaidCount,
          lostRevenue: lostRevenue,
          unbookedHours: unbookedHours,
          occupancyRate: occupancyRate,
          totalHoursBookedToday: totalHoursBookedPeriod,
          totalAvailableHours: totalAvailableHours,
          averageBookingPrice: averageBookingPrice,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 4. BOOKING TYPES CARD (أنواع الحجوزات من إجمالي كل الحجوزات)
        InsightsBookingTypesCard(
          totalBookings: totalAllBookings,
          personalCount: personalCount,
          personalPct: personalPct,
          challengeCount: challengeCount,
          challengePct: challengePct,
          openJoinCount: openJoinCount,
          openJoinPct: openJoinPct,
          isArabic: isArabic,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
