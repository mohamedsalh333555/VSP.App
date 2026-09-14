import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/logger_service.dart';
import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_ledger_screen.dart';

export '../../../core/utils/owner_financial_calculator.dart';
import '../../../core/utils/owner_financial_calculator.dart';
import '../widgets/dashboard/owner_verification_banner.dart';
import '../widgets/dashboard/owner_venue_filter_chips.dart';
import '../widgets/dashboard/owner_pro_overview_card.dart';
import '../widgets/dashboard/owner_pro_insights_view.dart';
import '../widgets/dashboard/owner_basic_financial_glance.dart';
import '../widgets/dashboard/owner_glanceable_timeline.dart';
import '../widgets/dashboard/owner_dashboard_header.dart';
import '../widgets/dashboard/owner_pro_segmented_tabs.dart';
import '../widgets/dashboard/owner_quick_cash_card.dart';

/// لوحة تحكم المالك المتجاوبة مع باقات الاشتراك (Basic vs Pro)
class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const OwnerDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  String _selectedStadiumFilter = 'all';
  String _selectedTimePeriod = 'today';
  int _selectedProTabIndex = 0; // 0 = Overview (نظرة عامة), 1 = Insights (التحليلات)
  StreamSubscription? _champSubscription;
  List<Championship> _ownerChampionships = [];
  OwnerFinancialMetrics? _cachedMetrics;
  String? _lastMetricsKey;

  OwnerFinancialMetrics _getOrCalculateMetrics(List<Booking> allBookings) {
    final key = '${allBookings.length}_${_ownerChampionships.length}_${_selectedTimePeriod}_$_selectedStadiumFilter';
    if (_cachedMetrics != null && _lastMetricsKey == key) {
      return _cachedMetrics!;
    }
    _lastMetricsKey = key;
    _cachedMetrics = OwnerFinancialCalculator.calculate(
      allBookings: allBookings,
      ownerChampionships: _ownerChampionships,
      timePeriod: _selectedTimePeriod,
      stadiumFilter: _selectedStadiumFilter,
    );
    return _cachedMetrics!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
      if (uid != null) {
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
        _champSubscription = TournamentRepository()
            .getChampionshipsStream(isOwner: true, ownerId: uid)
            .listen(
          (champs) {
            if (!mounted) return;
            setState(() {
              _ownerChampionships = champs;
            });
          },
          onError: (e) {
            VSPLogger.w('Owner championships subscription notice (handled): $e');
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _champSubscription?.cancel();
    super.dispose();
  }

  void _showProUpgradeSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = auth.userModel;
    final isProOwner = userModel?.isProPlan == true;

    bool isExpired = false;
    int? remainingTrialDays;
    bool showTrialEndingSoon = false;

    if (userModel != null) {
      if (userModel.trialEndsAt == null && userModel.subscriptionExpiresAt == null) {
        isExpired = false;
      } else {
        isExpired = userModel.isPlanExpired;
      }

      final trialEnds = userModel.effectiveTrialEndsAt;
      if (trialEnds != null && userModel.isInActiveTrial) {
        remainingTrialDays = trialEnds.difference(DateTime.now()).inDays;
        // يظهر فقط في آخر 10 أيام من التجربة المجانية (اليوم 51 إلى 60)
        showTrialEndingSoon = remainingTrialDays <= 10 && remainingTrialDays >= 0 && !isExpired;
      }
    }

    final bookingProvider = Provider.of<BookingProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final allBookings = bookingProvider.userBookings;
    final stadiums = stadiumProvider.stadiums;

    final metrics = _getOrCalculateMetrics(allBookings);

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: VSPColors.accent,
          backgroundColor: VSPColors.surface,
          onRefresh: () async {
            final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
            if (uid == null) return;
            if (context.mounted) {
              Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
            }
            await Future.wait([
              if (context.mounted)
                Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid, forceRefresh: true),
              auth.refreshProfile(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. الهيدر الموحد وشارة الباقة
                OwnerDashboardHeader(
                  auth: auth,
                  isProOwner: isProOwner,
                  isArabic: isArabic,
                  onUpgrade: () => _showProUpgradeSheet(context),
                ),
                const SizedBox(height: 14),

                // 2. كارت التوثيق التفاعلي الذكي لحالة المنشأة
                if (userModel != null)
                  OwnerVerificationBanner(userModel: userModel, isArabic: isArabic),

                // 2.1 تنبيه اقتراب انتهاء التجربة المجانية (اليوم 51-60 فقط)
                if (showTrialEndingSoon && remainingTrialDays != null)
                  OwnerTrialEndingSoonAlert(
                    remainingDays: remainingTrialDays,
                    isArabic: isArabic,
                    onUpgrade: () => _showProUpgradeSheet(context),
                  ),

                // 2.2 تنبيه انتهاء الاشتراك إن وجد (بعد اليوم 60)
                if (userModel != null && isExpired)
                  OwnerSubscriptionExpiredAlert(
                    isArabic: isArabic,
                    onRenew: () => _showProUpgradeSheet(context),
                  ),

                // 3. المحتوى المتفرع حسب الباقة (Basic vs Pro)
                if (isProOwner) ...[
                  // شريط التبويب المقسم (Pill Segmented Switcher)
                  OwnerProSegmentedTabs(
                    selectedIndex: _selectedProTabIndex,
                    onTabSelected: (index) => setState(() => _selectedProTabIndex = index),
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 12),

                  // شريط فلاتر الملاعب الأفقي (يظهر فقط إذا كان المالك يمتلك أكثر من ملعب)
                  if (stadiums.length > 1) ...[
                    OwnerVenueFilterChips(
                      stadiums: stadiums,
                      selectedStadiumId: _selectedStadiumFilter,
                      onStadiumSelected: (id) => setState(() => _selectedStadiumFilter = id),
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_selectedProTabIndex == 0) ...[
                    // تاب نظرة عامة (Overview)
                    OwnerProOverviewCard(
                      metrics: metrics,
                      selectedTimePeriod: _selectedTimePeriod,
                      onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                      onSettleDues: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerLedgerScreen())),
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),
                    OwnerQuickCashCard(
                      allBookings: allBookings,
                      stadiums: stadiums,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      isArabic: isArabic,
                    ),
                    OwnerGlanceableTimeline(
                      allBookings: allBookings,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      isArabic: isArabic,
                      onNavigateToBookings: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(3);
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
                        }
                      },
                    ),
                  ] else ...[
                    // تاب التحليلات العميقة (Insights)
                    OwnerProInsightsView(
                      allBookings: allBookings,
                      metrics: metrics,
                      stadiums: stadiums,
                      selectedTimePeriod: _selectedTimePeriod,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                      onStadiumFilterChanged: (id) => setState(() => _selectedStadiumFilter = id),
                      onNavigateTab: widget.onNavigateTab,
                      isArabic: isArabic,
                    ),
                  ],
                ] else ...[
                  // واجهة الباقة الأساسية (Overview Only)
                  OwnerBasicFinancialGlance(
                    metrics: metrics,
                    selectedTimePeriod: _selectedTimePeriod,
                    onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 16),
                  OwnerQuickCashCard(
                    allBookings: allBookings,
                    stadiums: stadiums,
                    selectedStadiumFilter: _selectedStadiumFilter,
                    isArabic: isArabic,
                  ),
                  OwnerGlanceableTimeline(
                    allBookings: allBookings,
                    selectedStadiumFilter: _selectedStadiumFilter,
                    isArabic: isArabic,
                    onNavigateToBookings: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(3);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
                      }
                    },
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
