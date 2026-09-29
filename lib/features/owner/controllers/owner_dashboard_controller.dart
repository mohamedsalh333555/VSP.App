import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/dashboard_analytics.dart';
import '../../../models/dashboard_filter.dart';

class OwnerDashboardState {
  final bool isLoading;
  final String? error;
  final DashboardAnalytics analytics;
  final DashboardFilter currentFilter;

  const OwnerDashboardState({
    this.isLoading = false,
    this.error,
    this.analytics = const DashboardAnalytics(),
    required this.currentFilter,
  });

  OwnerDashboardState copyWith({
    bool? isLoading,
    String? error,
    DashboardAnalytics? analytics,
    DashboardFilter? currentFilter,
  }) {
    return OwnerDashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      analytics: analytics ?? this.analytics,
      currentFilter: currentFilter ?? this.currentFilter,
    );
  }
}

class OwnerDashboardController with ChangeNotifier {
  final SupabaseClient supabase;
  final String currentOwnerId;
  static const bool useRealData = true;

  OwnerDashboardState state;

  OwnerDashboardController({
    required this.supabase,
    required this.currentOwnerId,
    DashboardFilter? initialFilter,
  }) : state = OwnerDashboardState(
          currentFilter: initialFilter ?? DashboardFilter.today(),
        );

  Future<void> loadDashboardData(DashboardFilter filter) async {
    state = state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await supabase.rpc(
        'get_owner_dashboard_analytics',
        params: {
          'p_owner_id': currentOwnerId,
          'p_start_date': filter.startDate.toIso8601String(),
          'p_end_date': filter.endDate.toIso8601String(),
          'p_court_id': filter.courtId,
        },
      );

      final analytics = DashboardAnalytics.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      // تحقق من تطابق الأرقام في development mode
      assert(
        analytics.revenue.isConsistent,
        'Revenue inconsistency: total=${analytics.revenue.total}, '
        'cash=${analytics.revenue.cash}, online=${analytics.revenue.online}',
      );

      state = state.copyWith(
        analytics: analytics,
        currentFilter: filter,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'تعذر تحميل البيانات، تحقق من الاتصال وحاول مجدداً',
      );
      notifyListeners();
    }
  }
}
