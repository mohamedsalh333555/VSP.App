import 'package:flutter/material.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/owner_financial_calculator.dart';
import '../../../../data/models.dart';
import '../../../../models/dashboard_analytics.dart';
import '../../../../models/dashboard_filter.dart';
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
  final void Function(DateTime start, DateTime end)? onCustomRangeSelected;
  final DashboardAnalytics? analytics;
  final DashboardFilter? dashboardFilter;
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
    this.onCustomRangeSelected,
    this.analytics,
    this.dashboardFilter,
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

    // التحليلات المالية/التشغيلية المعروضة في Pro يجب أن تأتي من مصدر التحليلات الرسمي في Supabase.
    // لا نستخدم إعادة حساب محلية كبديل لأن ذلك قد ينتج أرقاماً مختلفة عن الـSSOT.
    if (analytics == null) {
      return Column(
        children: [
          const SizedBox(height: 6),
          InsightsTopFiltersRow(
            selectedStadiumFilter: selectedStadiumFilter,
            selectedTimePeriod: selectedTimePeriod,
            stadiums: stadiums,
            onStadiumFilterChanged: onStadiumFilterChanged,
            onTimePeriodChanged: onTimePeriodChanged,
            onCustomRangeSelected: onCustomRangeSelected,
            isArabic: isArabic,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isArabic ? 'بيانات التحليلات غير متاحة حالياً.' : 'Analytics data is currently unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      );
    }

    // حالة الفراغ عند عدم وجود أي حجوزات
    final bool hasServerData = analytics!.bookings.totalCount > 0 || analytics!.capacity.bookedHours > 0;
    if (validBookings.isEmpty && !hasServerData) {
      return Column(
        children: [
          const SizedBox(height: 6),
          InsightsTopFiltersRow(
            selectedStadiumFilter: selectedStadiumFilter,
            selectedTimePeriod: selectedTimePeriod,
            stadiums: stadiums,
            onStadiumFilterChanged: onStadiumFilterChanged,
            onTimePeriodChanged: onTimePeriodChanged,
            onCustomRangeSelected: onCustomRangeSelected,
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
    String periodLabel = dashboardFilter?.periodLabel ?? (isArabic ? 'اليوم' : 'Today');
    String comparisonLabel = isArabic ? 'أمس' : 'Yesterday';
    double totalAvailableHoursFactor = 1.0;

    switch (selectedTimePeriod) {
      case 'yesterday':
        if (dashboardFilter == null) periodLabel = isArabic ? 'أمس' : 'Yesterday';
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
      case 'thisWeek':
        if (dashboardFilter == null) periodLabel = isArabic ? 'هذا الأسبوع' : 'This Week';
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
      case 'thisMonth':
        if (dashboardFilter == null) periodLabel = isArabic ? 'هذا الشهر' : 'This Month';
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

      case 'year':
      case 'thisYear':
        if (dashboardFilter == null) periodLabel = isArabic ? 'هذا العام' : 'This Year';
        comparisonLabel = isArabic ? 'العام السابق' : 'Last Year';
        final thisYearStart = DateTime(now.year, 1, 1);
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(thisYearStart.subtract(const Duration(seconds: 1)));
        }).toList();
        final lastYearStart = DateTime(now.year - 1, 1, 1);
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(lastYearStart.subtract(const Duration(seconds: 1))) && d.isBefore(thisYearStart);
        }).toList();
        totalAvailableHoursFactor = 365.0;
        break;

      case 'custom':
        if (dashboardFilter != null) {
          periodLabel = dashboardFilter!.periodLabel;
          periodBookings = validBookings.where((b) {
            final d = (b.operationalDate ?? b.startTime).toLocal();
            return d.isAfter(dashboardFilter!.startDate.subtract(const Duration(seconds: 1))) &&
                d.isBefore(dashboardFilter!.endDate);
          }).toList();
          totalAvailableHoursFactor = dashboardFilter!.endDate.difference(dashboardFilter!.startDate).inDays.toDouble().clamp(1.0, 365.0);
        } else {
          periodBookings = validBookings;
        }
        comparisonBookings = [];
        break;

      case 'all':
        if (dashboardFilter == null) periodLabel = isArabic ? 'الكل' : 'All-Time';
        comparisonLabel = isArabic ? 'إجمالي' : 'Overall';
        periodBookings = validBookings;
        comparisonBookings = [];
        totalAvailableHoursFactor = 30.0;
        break;

      case 'today':
      default:
        if (dashboardFilter == null) periodLabel = isArabic ? 'اليوم' : 'Today';
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
    final double effectiveRevenue = analytics != null ? analytics!.revenue.total : periodRevenue;
    final double revenueChange = previousRevenue > 0
        ? ((effectiveRevenue - previousRevenue) / previousRevenue) * 100
        : (effectiveRevenue > 0 ? 100.0 : 0.0);

    // حساب الطاقة الاستيعابية القصوى للملعب للفترة المحددة
    final List<Stadium> targetStadiums = selectedStadiumFilter != 'all'
        ? stadiums.where((s) => s.id == selectedStadiumFilter).toList()
        : stadiums;
    final int operationalPitchCount = targetStadiums.where((s) => !s.isUnderMaintenance).length;
    final int activePitchCount = targetStadiums.isEmpty ? 1 : operationalPitchCount;

    // حساب ساعات التشغيل اليومية الحقيقية من مواعيد الفتح والإغلاق
    double calculateOperatingHours(Stadium s) {
      final openH = AppDateFormatter.parseTimeToHour(s.openingTime, defaultHour: 16);
      final closeH = AppDateFormatter.parseTimeToHour(s.closingTime, defaultHour: 2);
      final hours = closeH >= openH ? (closeH - openH) : (24 - openH + closeH);
      return hours > 0 ? hours.toDouble() : 0.0;
    }

    final double operatingHours = targetStadiums.isNotEmpty
        ? calculateOperatingHours(targetStadiums.first)
        : 0.0;

    // ساعات التشغيل مسترجعة من جدول court_operating_hours عبر analytics أو من مواعيد الملعب المسجلة
    final double totalAvailableHours = analytics != null && analytics!.capacity.totalOperatingHours > 0
        ? analytics!.capacity.totalOperatingHours
        : (activePitchCount * operatingHours * totalAvailableHoursFactor);

    final double pitchHourlyRate = targetStadiums.isNotEmpty && targetStadiums.first.pricePerHour > 0
        ? targetStadiums.first.pricePerHour
        : (stadiums.isNotEmpty && stadiums.first.pricePerHour > 0
            ? stadiums.first.pricePerHour
            : (effectiveRevenue > 0 && periodBookings.isNotEmpty ? (effectiveRevenue / periodBookings.length) : 0.0));

    final double maxCapacityRevenue = totalAvailableHours * pitchHourlyRate;
    final double ringProgress = maxCapacityRevenue > 0
        ? (effectiveRevenue / maxCapacityRevenue).clamp(0.0, 1.0)
        : 0.0;

    // =========================================================================
    // METRIC 2: REVENUE BREAKDOWN (تقسيم الإيراد: دفع رقمي vs كاش)
    // =========================================================================
    double digitalRevenue = 0.0;
    double cashRevenue = 0.0;
    for (final b in periodBookings) {
      digitalRevenue += b.digitalAmountPaid;
      cashRevenue += b.pitchCashCollected;
    }
    final double effectiveDigitalRevenue = analytics != null ? analytics!.revenue.online : digitalRevenue;
    final double effectiveCashRevenue = analytics != null ? analytics!.revenue.cash : cashRevenue;
    final double digitalPct = analytics != null
        ? analytics!.revenue.onlinePercentage
        : (effectiveRevenue > 0 ? (effectiveDigitalRevenue / effectiveRevenue * 100) : 0.0);
    final double cashPct = analytics != null
        ? analytics!.revenue.cashPercentage
        : (effectiveRevenue > 0 ? (effectiveCashRevenue / effectiveRevenue * 100) : 0.0);

    // =========================================================================
    // METRIC 3: STRATEGIC BUSINESS METRICS (الإشغال الفعلي + الإيراد الضائع)
    // =========================================================================
    final int totalBookingsPeriod = analytics != null ? analytics!.bookings.totalCount : periodBookings.length;
    final int onlinePaidCount = analytics != null ? analytics!.bookings.onlineCount : periodBookings.where((b) => b.isPaid).length;
    final double averageBookingPrice = (analytics != null && analytics!.bookings.averagePrice > 0)
        ? analytics!.bookings.averagePrice
        : (totalBookingsPeriod > 0 ? (effectiveRevenue / totalBookingsPeriod) : 0.0);

    double totalHoursBookedPeriod = 0.0;
    for (final b in periodBookings) {
      final diffMins = b.endTime.difference(b.startTime).inMinutes;
      totalHoursBookedPeriod += diffMins > 0 ? (diffMins / 60.0) : 1.0;
    }
    final double effectiveBookedHours = analytics != null ? analytics!.capacity.bookedHours : totalHoursBookedPeriod;
    final double occupancyRate = analytics != null
        ? analytics!.capacity.occupancyRate
        : (totalAvailableHours > 0 ? ((effectiveBookedHours / totalAvailableHours) * 100).clamp(0.0, 100.0) : 0.0);

    final double unbookedHours = analytics != null
        ? analytics!.capacity.unbookedHours
        : (totalAvailableHours - effectiveBookedHours).clamp(0.0, totalAvailableHours);
    final double lostRevenue = analytics != null
        ? analytics!.revenue.unrealized
        : (unbookedHours * pitchHourlyRate);

    // =========================================================================
    // METRIC 4: BOOKING TYPES BREAKDOWN (أنواع الحجوزات من إجمالي حجوزات الفترة المحددة)
    // =========================================================================
    int personalCount = 0;
    int challengeCount = 0;
    int openJoinCount = 0;

    for (final b in periodBookings) {
      if (b.bookingType == BookingType.challenge || b.bookingType == BookingType.team) {
        challengeCount++;
      } else if (b.bookingType == BookingType.openJoin) {
        openJoinCount++;
      } else {
        personalCount++;
      }
    }

    final int totalPeriodBookings = periodBookings.length;
    final double personalPct = totalPeriodBookings > 0 ? (personalCount / totalPeriodBookings * 100) : 0.0;
    final double challengePct = totalPeriodBookings > 0 ? (challengeCount / totalPeriodBookings * 100) : 0.0;
    final double openJoinPct = totalPeriodBookings > 0 ? (openJoinCount / totalPeriodBookings * 100) : 0.0;

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
          onCustomRangeSelected: onCustomRangeSelected,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 1. HERO CARD (مقياس المؤشرات الشعاعية)
        InsightsRadialHeroCard(
          currentRevenue: effectiveRevenue,
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
          digitalRevenue: effectiveDigitalRevenue,
          digitalPct: digitalPct,
          cashRevenue: effectiveCashRevenue,
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
          totalHoursBookedToday: effectiveBookedHours,
          totalAvailableHours: totalAvailableHours,
          averageBookingPrice: averageBookingPrice,
          periodLabel: periodLabel,
          occupancyDisplay: analytics?.capacity.occupancyDisplay,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 4. BOOKING TYPES CARD (أنواع الحجوزات من إجمالي حجوزات الفترة المحددة)
        InsightsBookingTypesCard(
          totalBookings: totalPeriodBookings,
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
