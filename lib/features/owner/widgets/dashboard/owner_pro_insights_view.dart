import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/owner_financial_calculator.dart';
import '../../../../data/models.dart';
import '../../screens/owner_bookings_screen.dart';
import '../radial_tick_gauge_painter.dart';

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
          _buildProInsightsFiltersRow(stadiums: stadiums, isArabic: isArabic),
          const SizedBox(height: 14),
          _buildInsightsEmptyState(context, isArabic),
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
        _buildProInsightsFiltersRow(
          stadiums: stadiums,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 1. HERO CARD (إطار مستطيل فاخر لمقياس المؤشرات الشعاعية)
        _buildRadialHeroCard(
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

        // 2. REVENUE SOURCES CARD (إطار مستطيل لطرق التحصيل: رقمي وكاش)
        _buildRevenueSourcesCard(
          digitalRevenue: digitalRevenue,
          digitalPct: digitalPct,
          cashRevenue: cashRevenue,
          cashPct: cashPct,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 3. 2x2 STRATEGIC KPI SQUARES (4 مربعات بإطارات رمادية وأيقونات أنيقة)
        _buildStrategicKpiGridCards(
          context: context,
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

        // 4. BOOKING TYPES CARD (إطار مستطيل لأنواع الحجوزات من إجمالي كل الحجوزات)
        _buildBookingTypesCard(
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

  // ──────────────────────────────────────────────────────────────────────────
  // 0. PRO INSIGHTS TOP FILTERS ROW: زر الملاعب وزر الأيام متقابلين (نص وسهم فقط)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildProInsightsFiltersRow({
    required List<Stadium> stadiums,
    required bool isArabic,
  }) {
    final periodOptions = [
      {'key': 'today', 'label': isArabic ? 'اليوم' : 'Today'},
      {'key': 'yesterday', 'label': isArabic ? 'أمس' : 'Yesterday'},
      {'key': 'week', 'label': isArabic ? 'الأسبوع' : 'This Week'},
      {'key': 'month', 'label': isArabic ? 'الشهر' : 'This Month'},
      {'key': 'all', 'label': isArabic ? 'الكل' : 'All Time'},
    ];

    return Row(
      children: [
        // 1. زر فلتر الملاعب (Stadium Filter Dropdown)
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
                        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...stadiums.map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    )),
                  ];
                  return items.map((item) => Align(alignment: Alignment.centerRight, child: item.child)).toList();
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

        // 2. زر فلتر الأيام / الفترة الزمنية (Time Period Dropdown)
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
                        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
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

  // ──────────────────────────────────────────────────────────────────────────
  // 1. HERO CARD: مستطيل بإطار رمادي فاخر لمقياس المؤشرات الشعاعية
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRadialHeroCard({
    required double currentRevenue,
    required double previousRevenue,
    required double revenueChange,
    required double ringProgress,
    required double maxCapacityRevenue,
    required String periodLabel,
    required String comparisonLabel,
    required bool isArabic,
  }) {
    final bool isPositive = revenueChange > 0;
    final bool isNegative = revenueChange < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        children: [
          // Radial Tick Dial Gauge (مقياس المؤشرات الشعاعية)
          SizedBox(
            width: 172,
            height: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Radial Ticks Painter
                CustomPaint(
                  size: const Size(172, 172),
                  painter: RadialTickGaugePainter(
                    progress: ringProgress.clamp(0.0, 1.0),
                    activeColor: VSPColors.accent,
                    inactiveColor: const Color(0xFF27272A),
                    totalTicks: 52,
                    tickLength: 13.5,
                    strokeWidth: 2.3,
                  ),
                ),
                // Center Stats
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currentRevenue.toStringAsFixed(0),
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'جنيه $periodLabel' : 'EGP $periodLabel',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Balanced 2-Column Micro-Stats Strip (مقارنة الفترة + الطاقة القصوى)
          Row(
            children: [
              // 1. مقارنة بالفترة السابقة
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Iconsax.trend_up_copy
                            : (isNegative ? Iconsax.trend_down_copy : Iconsax.minus_copy),
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPositive
                                  ? '+${revenueChange.toStringAsFixed(1)}% ${isArabic ? "نمو" : "Growth"}'
                                  : (isNegative
                                      ? '-${revenueChange.abs().toStringAsFixed(1)}% ${isArabic ? "تراجع" : "Drop"}'
                                      : (isArabic ? 'أداء مستقر' : 'Stable')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} ج.م'
                                  : '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. الطاقة القصوى للفترة
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.flash_1_copy,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? '${(ringProgress * 100).toInt()}% إشغال'
                                  : '${(ringProgress * 100).toInt()}% Occupancy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? 'القصوى: ${maxCapacityRevenue.toStringAsFixed(0)} ج.م'
                                  : 'Max: ${maxCapacityRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. REVENUE SOURCES CARD: مستطيل بإطار لطرق التحصيل (رقمي / كاش)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRevenueSourcesCard({
    required double digitalRevenue,
    required double digitalPct,
    required double cashRevenue,
    required double cashPct,
    required bool isArabic,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.wallet_3_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'طرق التحصيل والإيراد' : 'COLLECTION & PAYMENT METHODS',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFramedRevenueItem(
            title: isArabic ? 'دفع إلكتروني ورقمي' : 'Digital & Online',
            amount: digitalRevenue,
            percentage: digitalPct,
            color: VSPColors.accent,
            isArabic: isArabic,
          ),
          const SizedBox(height: 14),

          _buildFramedRevenueItem(
            title: isArabic ? 'تحصيل كاش ونقدي' : 'Cash on Arrival',
            amount: cashRevenue,
            percentage: cashPct,
            color: Colors.white70,
            isArabic: isArabic,
          ),
        ],
      ),
    );
  }

  Widget _buildFramedRevenueItem({
    required String title,
    required double amount,
    required double percentage,
    required Color color,
    required bool isArabic,
    String? unit,
  }) {
    final displayUnit = unit ?? (isArabic ? 'ج.م' : 'EGP');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '(${percentage.toStringAsFixed(0)}%)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${amount.toStringAsFixed(0)} $displayUnit',
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFF27272A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. 2x2 KPI GRID CARDS: 4 مربعات قابلة للنقر مع شروحات بوب اب
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStrategicKpiGridCards({
    required BuildContext context,
    required int totalBookingsToday,
    required int onlinePaidCount,
    required double lostRevenue,
    required double unbookedHours,
    required double occupancyRate,
    required double totalHoursBookedToday,
    required double totalAvailableHours,
    required double averageBookingPrice,
    required bool isArabic,
  }) {
    return Column(
      children: [
        // Row 1: حجوزات اليوم + الإيراد غير المستغل
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.calendar_1_copy,
                value: '$totalBookingsToday',
                label: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                subtext: isArabic
                    ? '$onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش'
                    : '$onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash',
                onTap: () => _showKpiExplanationSheet(context, 
                  title: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                  value: isArabic
                      ? '$totalBookingsToday حجز ($onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش)'
                      : '$totalBookingsToday bookings ($onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash)',
                  icon: Iconsax.calendar_1_copy,
                  explanation: isArabic
                      ? 'يمثل إجمالي عدد الحجوزات المؤكدة لملعبك خلال ساعات اليوم، مع تصنيف فوري للحجوزات المدفوعة إلكترونياً (أونلاين) والحجوزات النقدية (كاش) لتسهيل مراجعة الخزينة.'
                      : 'Represents the total confirmed bookings for your venue today, with a breakdown between digital online payments and cash collections.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.moneys_copy,
                value: '${lostRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential',
                subtext: isArabic
                    ? '${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة'
                    : '${unbookedHours.toStringAsFixed(1)} unbooked hrs',
                onTap: () => _showKpiExplanationSheet(context, 
                  title: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential Revenue',
                  value: isArabic
                      ? '${lostRevenue.toStringAsFixed(0)} ج.م (${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة اليوم)'
                      : '${lostRevenue.toStringAsFixed(0)} EGP (${unbookedHours.toStringAsFixed(1)} unbooked hrs today)',
                  icon: Iconsax.moneys_copy,
                  explanation: isArabic
                      ? 'القيمة المالية التقديرية للساعات الشاغرة التي لم تُحجز اليوم حتى الآن بناءً على سعر الساعة للملعب. يوضح لك هذا الرقم الإيراد المفقود الذي كان بإمكانك تحقيقه إذا عمل الملعب بكامل طاقته.'
                      : 'The estimated financial value of unbooked hours today based on your hourly pitch rate. Shows the missed revenue opportunity.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: نسبة الإشغال الفعلية + متوسط سعر الحجز
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.chart_square_copy,
                value: '${occupancyRate.toStringAsFixed(0)}%',
                label: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy',
                subtext: isArabic
                    ? '${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة'
                    : '${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} hrs',
                onTap: () => _showKpiExplanationSheet(context, 
                  title: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy Rate',
                  value: isArabic
                      ? '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة متاحة)'
                      : '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} available hrs)',
                  icon: Iconsax.chart_square_copy,
                  explanation: isArabic
                      ? 'النسبة المئوية لعدد الساعات المحجوزة بالفعل اليوم مقارنة بإجمالي عدد الساعات التشغيلية المتاحة في الملعب خلال 24 ساعة.'
                      : 'The percentage of operational hours actually booked today compared to the total available hours.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.ticket_copy,
                value: '${averageBookingPrice.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'متوسط سعر الحجز' : 'Avg. Ticket Price',
                subtext: isArabic ? 'لكل حجز مسجل اليوم' : 'per registered booking',
                onTap: () => _showKpiExplanationSheet(context, 
                  title: isArabic ? 'متوسط سعر الحجز' : 'Average Booking Price',
                  value: isArabic
                      ? '${averageBookingPrice.toStringAsFixed(0)} ج.م لكل حجز مسجل'
                      : '${averageBookingPrice.toStringAsFixed(0)} EGP per registered booking',
                  icon: Iconsax.ticket_copy,
                  explanation: isArabic
                      ? 'متوسط الإيراد الناتج عن كل حجز تم تسجيله اليوم، ويتم حسابه بقسمة إجمالي إيرادات اليوم على عدد الحجوزات.'
                      : 'The average revenue generated per booking today, calculated by dividing total daily revenue by total bookings count.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFramedKpiCard({
    required IconData icon,
    required String value,
    required String label,
    required String subtext,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(VSPRadius.md),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141417),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Icon(icon, size: 16, color: Colors.white70),
                  ),
                  const Icon(
                    Iconsax.info_circle_copy,
                    size: 13,
                    color: Colors.white30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEET: شرح بسيط وهادئ للمؤشر (POPUP EXPLANATION)
  // ──────────────────────────────────────────────────────────────────────────
  void _showKpiExplanationSheet(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required String explanation,
    required bool isArabic,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141417),
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF27272A), width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grabber Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Icon + Title + Value
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Iconsax.info_circle_copy, size: 20, color: VSPColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Explanation Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(
                    explanation,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. BOOKING TYPES CARD: مستطيل بإطار لأنواع الحجوزات من إجمالي كل الحجوزات
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBookingTypesCard({
    required int totalBookings,
    required int personalCount,
    required double personalPct,
    required int challengeCount,
    required double challengePct,
    required int openJoinCount,
    required double openJoinPct,
    required bool isArabic,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.category_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'أنواع الحجوزات' : 'BOOKING TYPES',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                isArabic ? 'إجمالي $totalBookings حجز' : '$totalBookings total',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (totalBookings == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isArabic ? 'لا توجد حجوزات مسجلة بعد.' : 'No bookings registered yet.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else ...[
            _buildFramedRevenueItem(
              title: isArabic ? 'حجوزات عادية ومباشرة' : 'Direct & Standard',
              amount: personalCount.toDouble(),
              percentage: personalPct,
              color: VSPColors.accent,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),
            const SizedBox(height: 14),

            _buildFramedRevenueItem(
              title: isArabic ? 'تحديات ومباريات فرق' : 'Team Challenges',
              amount: challengeCount.toDouble(),
              percentage: challengePct,
              color: Colors.white70,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),

            if (openJoinCount > 0) ...[
              const SizedBox(height: 14),
              _buildFramedRevenueItem(
                title: isArabic ? 'مباريات انضمام وتجميع' : 'Open-Join Matches',
                amount: openJoinCount.toDouble(),
                percentage: openJoinPct,
                color: Colors.white38,
                isArabic: isArabic,
                unit: isArabic ? 'حجز' : 'bookings',
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// ودجت حالة الفراغ للتحليلات (Threshold Empty State)
  Widget _buildInsightsEmptyState(BuildContext context, bool isArabic) {
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
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
                style: const TextStyle(color: Colors.black, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
