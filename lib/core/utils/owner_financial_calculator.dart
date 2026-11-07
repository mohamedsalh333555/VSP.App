import '../../data/models.dart';

/// كائن البيانات المالية المجمعة للوحة تحكم المالك
class OwnerFinancialMetrics {
  final double pitchCashRevenue;
  final double digitalVspBalance;
  final double pendingReceivables;
  final double totalPipeline;
  final double totalHours;
  final int activeBookingsCount;
  final List<Booking> periodBookings;

  const OwnerFinancialMetrics({
    required this.pitchCashRevenue,
    required this.digitalVspBalance,
    required this.pendingReceivables,
    required this.totalPipeline,
    required this.totalHours,
    required this.activeBookingsCount,
    required this.periodBookings,
  });

  /// كاش الملعب المستلم فعلياً
  double get cashCollected => pitchCashRevenue;

  /// رصيد المحفظة الإلكترونية أونلاين
  double get digitalBalance => digitalVspBalance;

  /// المبالغ المعلقة المتبقية على العملاء
  double get pendingAmount => pendingReceivables;
}

/// محرك الحسابات المالية المفصول عن واجهة المستخدم (Pure Domain Financial Calculator)
class OwnerFinancialCalculator {
  static OwnerFinancialMetrics calculate({
    required List<Booking> allBookings,
    required List<Championship> ownerChampionships,
    required String timePeriod,
    required String stadiumFilter,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = DateTime(now.year, now.month, now.day - 1);
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final nextWeekStart = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

    final List<Booking> filteredBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (stadiumFilter != 'all' && b.stadiumId != stadiumFilter) return false;

      final bStartLocal = b.startTime.toLocal();
      final bDate = b.operationalDate ?? bStartLocal;

      if (timePeriod == 'today') {
        return bDate.year == todayStart.year && bDate.month == todayStart.month && bDate.day == todayStart.day;
      } else if (timePeriod == 'yesterday') {
        return bDate.year == yesterdayStart.year && bDate.month == yesterdayStart.month && bDate.day == yesterdayStart.day;
      } else if (timePeriod == 'week') {
        return !bDate.isBefore(weekStart) && bDate.isBefore(nextWeekStart);
      } else if (timePeriod == 'month') {
        return bDate.year == now.year && bDate.month == now.month;
      }
      return true;
    }).toList();

    double pitchCashRevenue = 0.0;
    double digitalVspBalance = 0.0;
    double pendingReceivables = 0.0;
    double totalPipeline = 0.0;
    double totalHours = 0.0;

    for (final b in filteredBookings) {
      final double totalPrice = b.totalPrice.isFinite && b.totalPrice > 0
          ? b.totalPrice
          : (b.depositPaid.isFinite && b.depositPaid > 0 ? b.depositPaid : 0.0);
      // Bad upstream numeric values must not corrupt dashboard totals.
      final digital = b.digitalAmountPaid;
      final cash = b.pitchCashCollected;
      final pending = b.pendingReceivable;
      if (digital.isFinite && digital > 0) digitalVspBalance += digital;
      if (cash.isFinite && cash > 0) pitchCashRevenue += cash;
      if (pending.isFinite && pending > 0) pendingReceivables += pending;
      totalPipeline += totalPrice;

      final diffMinutes = b.endTime.difference(b.startTime).inMinutes;
      // Invalid or zero-length bookings must never inflate occupancy hours.
      if (diffMinutes > 0) totalHours += diffMinutes / 60.0;
    }

    return OwnerFinancialMetrics(
      pitchCashRevenue: pitchCashRevenue,
      digitalVspBalance: digitalVspBalance,
      pendingReceivables: pendingReceivables,
      totalPipeline: totalPipeline,
      totalHours: totalHours,
      activeBookingsCount: filteredBookings.length,
      periodBookings: filteredBookings,
    );
  }

  /// استنتاج مصدر الدفع من وسيلة الدفع (Fallback Helper)
  static String inferSourceFromMethod(String method) {
    final m = method.toLowerCase().trim();
    if (m.contains('vodafone') || m.contains('فودافون')) return 'vodafone_cash';
    if (m.contains('instapay') || m.contains('انستاباي')) return 'instapay';
    if (m.contains('paymob') || m.contains('card') || m.contains('online')) return 'paymob';
    if (m.contains('cash') || m.contains('كاش')) return 'cash';
    return 'pending';
  }
}
