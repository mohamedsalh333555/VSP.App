// lib/models/dashboard_analytics.dart

class RevenueData {
  final double total;
  final double cash;
  final double online;
  final double cashPercentage;
  final double onlinePercentage;
  final double unrealized;
  final double realizedRevenue;
  final double realizedCash;
  final double realizedOnline;
  final double cashCollected;
  final double cashUncollected;
  final double onlineCollected;
  final double onlineUnavailable;
  final double upcomingConfirmedValue;
  final double upcomingCashValue;
  final double upcomingOnlineValue;

  const RevenueData({
    this.total = 0,
    this.cash = 0,
    this.online = 0,
    this.cashPercentage = 0,
    this.onlinePercentage = 0,
    this.unrealized = 0,
    this.realizedRevenue = 0,
    this.realizedCash = 0,
    this.realizedOnline = 0,
    this.cashCollected = 0,
    this.cashUncollected = 0,
    this.onlineCollected = 0,
    this.onlineUnavailable = 0,
    this.upcomingConfirmedValue = 0,
    this.upcomingCashValue = 0,
    this.upcomingOnlineValue = 0,
  });

  factory RevenueData.fromJson(Map<String, dynamic> j) => RevenueData(
        total:                  (j['total'] ?? 0).toDouble(),
        cash:                   (j['cash'] ?? 0).toDouble(),
        online:                 (j['online'] ?? 0).toDouble(),
        cashPercentage:         (j['cash_percentage'] ?? 0).toDouble(),
        onlinePercentage:       (j['online_percentage'] ?? 0).toDouble(),
        unrealized:             (j['unrealized'] ?? 0).toDouble(),
        realizedRevenue:        (j['realized_revenue'] ?? (j['realized'] ?? 0)).toDouble(),
        realizedCash:           (j['realized_cash'] ?? 0).toDouble(),
        realizedOnline:         (j['realized_online'] ?? 0).toDouble(),
        cashCollected:          (j['cash_collected'] ?? 0).toDouble(),
        cashUncollected:        (j['cash_uncollected'] ?? 0).toDouble(),
        onlineCollected:        (j['online_collected'] ?? 0).toDouble(),
        onlineUnavailable:      (j['online_unavailable'] ?? 0).toDouble(),
        upcomingConfirmedValue: (j['upcoming_confirmed_value'] ?? (j['upcoming'] ?? 0)).toDouble(),
        upcomingCashValue:      (j['upcoming_cash_value'] ?? 0).toDouble(),
        upcomingOnlineValue:    (j['upcoming_online_value'] ?? 0).toDouble(),
      );

  // تحقق: total == cash + online دايماً
  bool get isConsistent =>
      (total - (cash + online)).abs() < 0.01;
}

class BookingsData {
  final int totalCount;
  final int cashCount;
  final int onlineCount;
  final double averagePrice;

  const BookingsData({
    this.totalCount = 0,
    this.cashCount = 0,
    this.onlineCount = 0,
    this.averagePrice = 0,
  });

  factory BookingsData.fromJson(Map<String, dynamic> j) => BookingsData(
        totalCount:   (j['total_count'] ?? 0) is int ? (j['total_count'] ?? 0) : ((j['total_count'] as num?)?.toInt() ?? 0),
        cashCount:    (j['cash_count'] ?? 0) is int ? (j['cash_count'] ?? 0) : ((j['cash_count'] as num?)?.toInt() ?? 0),
        onlineCount:  (j['online_count'] ?? 0) is int ? (j['online_count'] ?? 0) : ((j['online_count'] as num?)?.toInt() ?? 0),
        averagePrice: (j['average_price'] ?? 0).toDouble(),
      );
}

class CapacityData {
  final double totalOperatingHours;
  final double bookedHours;
  final double unbookedHours;
  final double occupancyRate;

  const CapacityData({
    this.totalOperatingHours = 0,
    this.bookedHours = 0,
    this.unbookedHours = 0,
    this.occupancyRate = 0,
  });

  factory CapacityData.fromJson(Map<String, dynamic> j) => CapacityData(
        totalOperatingHours: (j['total_operating_hours'] ?? 0).toDouble(),
        bookedHours:         (j['booked_hours'] ?? 0).toDouble(),
        unbookedHours:       (j['unbooked_hours'] ?? 0).toDouble(),
        occupancyRate:       (j['occupancy_rate'] ?? 0).toDouble(),
      );

  // عرض النسبة بشكل صحيح — مش بيعرض صفر لو فيه حجز
  String get occupancyDisplay =>
      occupancyRate < 1 && occupancyRate > 0
          ? '${occupancyRate.toStringAsFixed(1)}%'
          : '${occupancyRate.toStringAsFixed(0)}%';
}

class DashboardAnalytics {
  final RevenueData revenue;
  final BookingsData bookings;
  final CapacityData capacity;

  const DashboardAnalytics({
    this.revenue = const RevenueData(),
    this.bookings = const BookingsData(),
    this.capacity = const CapacityData(),
  });

  factory DashboardAnalytics.fromJson(Map<String, dynamic> j) =>
      DashboardAnalytics(
        revenue:  RevenueData.fromJson(Map<String, dynamic>.from(j['revenue'] ?? {})),
        bookings: BookingsData.fromJson(Map<String, dynamic>.from(j['bookings'] ?? {})),
        capacity: CapacityData.fromJson(Map<String, dynamic>.from(j['capacity'] ?? {})),
      );

  factory DashboardAnalytics.empty() => const DashboardAnalytics();
}
