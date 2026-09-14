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
    final yesterday = now.subtract(const Duration(days: 1));

    final List<Booking> filteredBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (stadiumFilter != 'all' && b.stadiumId != stadiumFilter) return false;

      final bStartLocal = b.startTime.toLocal();
      final bDate = b.operationalDate ?? bStartLocal;

      if (timePeriod == 'today') {
        return bDate.year == now.year && bDate.month == now.month && bDate.day == now.day;
      } else if (timePeriod == 'yesterday') {
        return bDate.year == yesterday.year && bDate.month == yesterday.month && bDate.day == yesterday.day;
      } else if (timePeriod == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return bDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && bDate.isBefore(endOfWeek);
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
      final double totalPrice = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      digitalVspBalance += b.digitalAmountPaid;
      pitchCashRevenue += b.pitchCashCollected;
      pendingReceivables += b.pendingReceivable;
      totalPipeline += totalPrice;

      final diffMinutes = b.endTime.difference(b.startTime).inMinutes;
      totalHours += diffMinutes > 0 ? (diffMinutes / 60.0) : 1.0;
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
    if (m.contains('cash') || m.contains('كاش')) return 'cash';
    if (m.contains('paymob') || m.contains('card') || m.contains('online')) return 'paymob';
    if (m.contains('instapay')) return 'instapay';
    if (m.contains('vodafone')) return 'vodafone_cash';
    return 'pending';
  }
}
