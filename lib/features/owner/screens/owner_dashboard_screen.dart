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
import 'add_stadium_wizard.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/dashboard_analytics.dart';
import '../../../models/dashboard_filter.dart';
export '../../../core/utils/owner_financial_calculator.dart';
import '../../../core/utils/owner_financial_calculator.dart';
import '../../../core/repositories/owner_repository.dart';
import '../widgets/ledger/owner_payout_dialog.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../widgets/dashboard/owner_pro_insights_view.dart';
import '../widgets/dashboard/owner_verification_banner.dart';
import '../widgets/dashboard/insights/insights_top_filters_row.dart';
import '../widgets/dashboard/owner_dashboard_header.dart';
import '../widgets/dashboard/owner_operational_finance_card.dart';
import '../widgets/dashboard/owner_today_pitch_schedule_card.dart';
import '../widgets/dashboard/owner_pending_actions_bar.dart';

/// لوحة تحكم المالك المتجاوبة مع باقات الاشتراك (Basic vs Pro)
class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  final bool isHomeVisible;
  const OwnerDashboardScreen({super.key, this.onNavigateTab, this.isHomeVisible = true});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  int _selectedDashboardTab = 0; // 0 = التشغيل اليومي, 1 = التحليلات (Insights)
  String _selectedStadiumFilter = 'all';
  String _selectedTimePeriod = 'today';
  StreamSubscription? _champSubscription;
  List<Championship> _ownerChampionships = [];
  final Map<String, DateTime> _approvalNoticeSeenUntil = {};

  String? _lastMetricsKey;
  OwnerFinancialMetrics? _cachedMetrics;

  OwnerFinancialMetrics _getOrCalculateMetrics(List<Booking> allBookings) {
    final key = _generateMetricsCacheKey(allBookings);
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

  String _generateMetricsCacheKey(List<Booking> bookings) {
    final buffer = StringBuffer('$_selectedTimePeriod:$_selectedStadiumFilter:');
    for (final b in bookings.take(50)) {
      buffer.write(
        '${b.id}:'
        '${b.effectivePaymentState}:'
        '${b.totalPrice}:'
        '${b.depositPaid}|',
      );
    }
    return buffer.toString().hashCode.toString();
  }


  Map<String, dynamic>? _financialSummary;

  Future<void> _fetchFinancialSummary(String uid) async {
    try {
      final summary = await OwnerRepository().getOwnerFinancialSummary(uid);
      if (mounted) {
        setState(() {
          _financialSummary = summary;
        });
      }
    } catch (e) {
      VSPLogger.w('Failed to load owner financial summary for dashboard: $e');
    }
  }

  Future<void> _fetchOwnerChampionships(String uid) async {
    try {
      final champs = await TournamentRepository()
          .getChampionships(isOwner: true, ownerId: uid);
      if (mounted) {
        setState(() {
          _ownerChampionships = champs;
        });
        _claimApprovedChampionshipHomeNotices(champs);
      }
    } catch (e) {
      VSPLogger.w('Failed to refresh owner championships for dashboard: $e');
    }
  }

  Future<void> _claimApprovedChampionshipHomeNotices(List<Championship> champs) async {
    final repo = TournamentRepository();
    final now = DateTime.now().toUtc();
    for (final championship in champs) {
      if (!championship.isApproved) continue;
      try {
        final response = await repo.claimOwnerChampionshipApprovalHomeNotice(championship.id);
        if (response['success'] == true && response['seen_until'] != null) {
          final seenUntil = DateTime.tryParse(response['seen_until'].toString());
          if (seenUntil != null && seenUntil.isAfter(now) && mounted) {
            setState(() {
              _approvalNoticeSeenUntil[championship.id] = seenUntil;
            });
          }
        }
      } catch (e) {
        VSPLogger.w('Failed to claim championship approval Home notice: $e');
      }
    }
  }

  DashboardFilter _currentFilter = DashboardFilter.today();
  DashboardAnalytics _dashboardAnalytics = const DashboardAnalytics();
  bool _isLoadingAnalytics = false;
  String? _analyticsError;

  Future<void> _loadDashboardAnalytics({String? ownerId, DashboardFilter? filter}) async {
    final uid = ownerId ?? Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) return;
    final activeFilter = filter ?? _currentFilter;

    if (mounted) {
      setState(() {
        _isLoadingAnalytics = true;
        _analyticsError = null;
      });
    }

    try {
      final response = await Supabase.instance.client.rpc(
        'get_owner_dashboard_analytics',
        params: {
          'p_owner_id': uid,
          'p_start_date': activeFilter.startIsoUtc,
          'p_end_date': activeFilter.endIsoUtc,
          'p_court_id': activeFilter.courtId,
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

      if (mounted) {
        setState(() {
          _dashboardAnalytics = analytics;
          _currentFilter = activeFilter;
          _isLoadingAnalytics = false;
        });
      }
    } catch (e) {
      VSPLogger.w('Failed to load dashboard analytics: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
          _analyticsError = 'تعذر تحميل البيانات، تحقق من الاتصال وحاول مجدداً';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.id;
      if (uid != null) {
        _fetchFinancialSummary(uid);
        _loadDashboardAnalytics(ownerId: uid);
        _fetchOwnerChampionships(uid);
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

  Future<void> onHomeBecameVisible() async {
    final uid = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) return;
    await _fetchOwnerChampionships(uid);
  }

  @override
  void didUpdateWidget(covariant OwnerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isHomeVisible && widget.isHomeVisible) {
      onHomeBecameVisible();
    }
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

    final double availableBalance = (_financialSummary?['success'] == true)
        ? ((_financialSummary?['available_balance'] as num?)?.toDouble() ?? 0.0)
        : 0.0;

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: VSPColors.accent,
          backgroundColor: VSPColors.surface,
          onRefresh: () async {
            final uid = auth.currentUser?.id;
            if (uid == null) return;
            if (context.mounted) {
              Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
            }
            await Future.wait([
              _fetchFinancialSummary(uid),
              _loadDashboardAnalytics(ownerId: uid, filter: _currentFilter),
              _fetchOwnerChampionships(uid),
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
                if (_isLoadingAnalytics) ...[
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(VSPColors.accent),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_analyticsError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: VSPColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _analyticsError!,
                            style: const TextStyle(color: VSPColors.error, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

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

                // 2.2 تنبيه مهلة السماح (3 أيام بعد انتهاء السنة المجانية أو الاشتراك)
                if (userModel != null && userModel.isInGracePeriod)
                  OwnerGracePeriodAlert(
                    remainingHours: userModel.remainingGraceHours,
                    isArabic: isArabic,
                    onRenew: () => _showProUpgradeSheet(context),
                  ),

                // 2.3 تنبيه انتهاء الاشتراك بعد استنفاد مهلة السماح
                if (userModel != null && isExpired)
                  OwnerSubscriptionExpiredAlert(
                    isArabic: isArabic,
                    onRenew: () => _showProUpgradeSheet(context),
                  ),

                // 3. شريط التبديل بين [ التشغيل اليومي ] و [ التحليلات والقرارات ]
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDashboardTab = 0);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedDashboardTab == 0 ? VSPColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isArabic ? 'التشغيل اليومي' : 'Operations',
                              style: TextStyle(
                                color: _selectedDashboardTab == 0 ? Colors.black : VSPColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDashboardTab = 1);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedDashboardTab == 1 ? VSPColors.proAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isArabic ? 'التحليلات الذكية' : 'Insights',
                                  style: TextStyle(
                                    color: _selectedDashboardTab == 1 ? Colors.black : VSPColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (!isProOwner) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_rounded, size: 13, color: VSPColors.textSecondary),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── TAB 0: التشغيل اليومي الموحد (مفتوح للباقتين لإدارة الملاعب) ──
                if (_selectedDashboardTab == 0) ...[
                  // نفس فلاتر Insights — حالة واحدة مشتركة بين التبويبين.
                  InsightsTopFiltersRow(
                    stadiums: stadiums,
                    selectedStadiumFilter: _selectedStadiumFilter,
                    selectedTimePeriod: _selectedTimePeriod,
                    isArabic: isArabic,
                    onStadiumFilterChanged: (id) {
                      final filter = _currentFilter.copyWith(
                        courtId: id != 'all' ? id : null,
                      );
                      setState(() {
                        _selectedStadiumFilter = id;
                        _currentFilter = filter;
                        _cachedMetrics = null;
                      });
                      _loadDashboardAnalytics(filter: filter);
                    },
                    onTimePeriodChanged: (period) {
                      DashboardFilter filter;
                      if (period == 'yesterday') {
                        filter = DashboardFilter.yesterday();
                      } else if (period == 'week' || period == 'thisWeek') {
                        filter = DashboardFilter.thisWeek();
                      } else if (period == 'month' || period == 'thisMonth') {
                        filter = DashboardFilter.thisMonth();
                      } else if (period == 'year' || period == 'thisYear') {
                        filter = DashboardFilter.thisYear();
                      } else {
                        filter = DashboardFilter.today();
                      }
                      filter = filter.copyWith(
                        courtId: _selectedStadiumFilter != 'all' ? _selectedStadiumFilter : null,
                      );
                      setState(() {
                        _selectedTimePeriod = period;
                        _currentFilter = filter;
                        _cachedMetrics = null;
                      });
                      _loadDashboardAnalytics(filter: filter);
                    },
                    onCustomRangeSelected: (start, end) {
                      final filter = DashboardFilter.custom(start, end).copyWith(
                        courtId: _selectedStadiumFilter != 'all' ? _selectedStadiumFilter : null,
                      );
                      setState(() {
                        _selectedTimePeriod = 'custom';
                        _currentFilter = filter;
                        _cachedMetrics = null;
                      });
                      _loadDashboardAnalytics(filter: filter);
                    },
                  ),
                  const SizedBox(height: 12),

                  // أ. كارت المالية والتشغيل الموحد (نفس موقع زر السحب للباقتين)
                  OwnerOperationalFinanceCard(
                    availableBalance: availableBalance,
                    cashThisMonth: _dashboardAnalytics.revenue.cashCollected,
                    onlineThisMonth: _dashboardAnalytics.revenue.onlineCollected,
                    cashUncollected: _dashboardAnalytics.revenue.cashUncollected,
                    onlineUnavailable: _dashboardAnalytics.revenue.onlineUnavailable,
                    showProFinancialDetail: isProOwner,
                    upcomingValue: _dashboardAnalytics.revenue.upcomingConfirmedValue,
                    timePeriod: _selectedTimePeriod,
                    periodLabel: _currentFilter.periodLabel,
                    onOpenLedger: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()),
                      );
                    },
                    onRequestPayout: () {
                      OwnerPayoutDialog.show(context, availableBalance, isArabic);
                    },
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 16),

                  // ب. كارت جدول مواعيد اليوم بالنقط الملونة أو دعوة لإضافة الملعب الأول
                  if (stadiums.isEmpty)
                    _buildNoStadiumsPrompt(context, isArabic)
                  else
                    OwnerTodayPitchScheduleCard(
                      allBookings: allBookings,
                      stadiums: stadiums,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      isArabic: isArabic,
                      onNavigateToBookings: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(3);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()),
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 16),

                  // ج. تنبيه البطولة: انتظار الاعتماد ثم إشعار اعتماد لمدة 24 ساعة من أول زيارة Home.
                  Builder(
                    builder: (context) {
                      final nowUtc = DateTime.now().toUtc();
                      final pending = _ownerChampionships
                          .where((c) =>
                              !c.isApproved &&
                              c.creationFeePaid &&
                              c.status.toLowerCase() != 'cancelled' &&
                              c.status.toLowerCase() != 'completed')
                          .toList()
                        ..sort((a, b) => b.startDate.compareTo(a.startDate));

                      final approvedVisible = _ownerChampionships.where((c) {
                        final until = _approvalNoticeSeenUntil[c.id];
                        return c.isApproved &&
                            c.status.toLowerCase() != 'cancelled' &&
                            c.status.toLowerCase() != 'completed' &&
                            until != null &&
                            until.isAfter(nowUtc);
                      }).toList()
                        ..sort((a, b) => b.startDate.compareTo(a.startDate));

                      final Championship? championship =
                          pending.isNotEmpty ? pending.first :
                          (approvedVisible.isNotEmpty ? approvedVisible.first : null);
                      if (championship == null) return const SizedBox.shrink();

                      final isPending = !championship.isApproved;
                      final title = isPending
                          ? (isArabic ? 'في انتظار اعتماد البطولة' : 'Tournament awaiting approval')
                          : (isArabic ? 'تم اعتماد البطولة' : 'Tournament approved');
                      final badge = isPending
                          ? (isArabic ? 'قيد المراجعة' : 'Pending')
                          : (isArabic ? 'معتمدة' : 'Approved');

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.card),
                          border: Border.all(
                            color: isPending
                                ? VSPColors.divider
                                : VSPColors.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isPending
                                      ? Icons.hourglass_top_rounded
                                      : Icons.verified_rounded,
                                  color: isPending
                                      ? VSPColors.textSecondary
                                      : VSPColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: VSPColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  badge,
                                  style: TextStyle(
                                    color: isPending
                                        ? VSPColors.textSecondary
                                        : VSPColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              championship.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VSPColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isPending
                                  ? (isArabic
                                      ? 'ستظل ظاهرة حتى اعتماد الأدمن.'
                                      : 'This notice stays until admin approval.')
                                  : (isArabic
                                      ? 'سيظل التنبيه ظاهرًا لمدة 24 ساعة من أول زيارة للرئيسية.'
                                      : 'Shown for 24 hours from your first Home visit.'),
                              style: const TextStyle(
                                color: VSPColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // د. شريط الإجراء التشغيلي الفوري للحجوزات المعلقة
                  OwnerPendingActionsBar(
                    allBookings: allBookings,
                    selectedStadiumFilter: _selectedStadiumFilter,
                    isArabic: isArabic,
                    onActionTap: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(3);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(height: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
                ]
                // ── TAB 1: التحليلات والقرارات الذكية (Insights) ──
                else ...[
                  if (isProOwner)
                    OwnerProInsightsView(
                      allBookings: allBookings,
                      metrics: metrics,
                      stadiums: stadiums,
                      selectedTimePeriod: _selectedTimePeriod,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      analytics: _dashboardAnalytics,
                      dashboardFilter: _currentFilter,
                      onCustomRangeSelected: (start, end) {
                        final filter = DashboardFilter.custom(start, end).copyWith(
                          courtId: _selectedStadiumFilter != 'all' ? _selectedStadiumFilter : null,
                        );
                        setState(() {
                          _selectedTimePeriod = 'custom';
                          _currentFilter = filter;
                          _cachedMetrics = null;
                        });
                        _loadDashboardAnalytics(filter: filter);
                      },
                      onTimePeriodChanged: (period) {
                        DashboardFilter filter;
                        if (period == 'yesterday') {
                          filter = DashboardFilter.yesterday();
                        } else if (period == 'week' || period == 'thisWeek') {
                          filter = DashboardFilter.thisWeek();
                        } else if (period == 'month' || period == 'thisMonth') {
                          filter = DashboardFilter.thisMonth();
                        } else if (period == 'year' || period == 'thisYear') {
                          filter = DashboardFilter.thisYear();
                        } else {
                          filter = DashboardFilter.today();
                        }
                        filter = filter.copyWith(
                          courtId: _selectedStadiumFilter != 'all' ? _selectedStadiumFilter : null,
                        );
                        setState(() {
                          _selectedTimePeriod = period;
                          _currentFilter = filter;
                          _cachedMetrics = null;
                        });
                        _loadDashboardAnalytics(filter: filter);
                      },
                      onStadiumFilterChanged: (id) {
                        setState(() {
                          _selectedStadiumFilter = id;
                          _cachedMetrics = null;
                          _currentFilter = _currentFilter.copyWith(courtId: id != 'all' ? id : null);
                        });
                        _loadDashboardAnalytics(filter: _currentFilter);
                      },
                      onNavigateTab: widget.onNavigateTab,
                      isArabic: isArabic,
                    )
                  else
                    _buildProInsightsLockedTeaser(context, isArabic),
                  SizedBox(height: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProInsightsLockedTeaser(BuildContext context, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: VSPColors.accent.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSPColors.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: VSPColors.accent.withValues(alpha: 0.28),
                  width: 1,
                ),
              ),
              child: const Icon(
                Iconsax.chart_2_copy,
                color: VSPColors.accent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isArabic ? 'تحليلات وقرارات الملاعب الذكية' : 'Smart Pitch Insights',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'أدوات احترافية تساعدك على فهم تشغيل ملعبك وزيادة الاستفادة منه.'
                : 'Professional tools to understand your pitch operation and improve utilization.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          _buildTeaserFeatureRow(
            icon: Iconsax.status_up_copy,
            title: isArabic ? 'معدل الإشغال الفعلي' : 'Actual Occupancy Rate',
            subtitle: isArabic
                ? 'اعرف نسبة استغلال ساعات ملعبك بدقة.'
                : 'See how much of your available pitch time is actually used.',
          ),
          const SizedBox(height: 8),
          _buildTeaserFeatureRow(
            icon: Iconsax.money_remove_copy,
            title: isArabic ? 'الإيراد الضائع' : 'Lost Revenue',
            subtitle: isArabic
                ? 'اكتشف قيمة الساعات الفارغة التي كان يمكن استغلالها.'
                : 'Identify revenue opportunities from idle hours.',
          ),
          const SizedBox(height: 8),
          _buildTeaserFeatureRow(
            icon: Iconsax.card_pos_copy,
            title: isArabic ? 'تفصيل الدخل' : 'Revenue Breakdown',
            subtitle: isArabic
                ? 'تابع الكاش والدفع الرقمي وأنواع الحجوزات الأكثر طلباً.'
                : 'Understand cash, digital payments, and your most requested booking types.',
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _showProUpgradeSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
              ),
              child: Text(
                isArabic
                    ? 'الترقية للباقة الاحترافية — 1,000 ج.م/شهر'
                    : 'Upgrade to Pro — 1,000 EGP/month',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeaserFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.borderLight),
      ),
      child: Row(
        children: [
          Icon(icon, color: VSPColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStadiumsPrompt(BuildContext context, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.building_3_copy,
              size: 32,
              color: VSPColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isArabic ? 'ابدأ بتسجيل ملعبك الأول' : 'Add Your First Stadium',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'أضف بيانات الملعب ومواعيد العمل لتتمكن من استقبال الحجوزات وإدارتها بكل سهولة.'
                : 'Add stadium details and operating hours to start receiving and managing bookings.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VSPColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStadiumWizard()),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                isArabic ? 'إضافة ملعب الآن' : 'Add Stadium Now',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
