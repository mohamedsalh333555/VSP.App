import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/vsp_ui.dart';
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
import '../widgets/dashboard/owner_operational_finance_card.dart';
import '../widgets/dashboard/owner_today_pitch_schedule_card.dart';
import '../widgets/dashboard/owner_pending_actions_bar.dart';
import '../widgets/dashboard/owner_dashboard_header.dart';

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
  bool _hasChampionshipStreamError = false;
  final Map<String, DateTime> _approvalNoticeSeenUntil = {};
  String? _activeOwnerScope;
  bool _hasObservedOwnerScope = false;
  int _ownerScopeGeneration = 0;
  int _championshipFetchGeneration = 0;

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
    final buffer = StringBuffer('$_selectedTimePeriod:$_selectedStadiumFilter:${bookings.length}:');
    // Every loaded booking contributes to the cache key; truncating at 50 can
    // leave owner totals stale when records outside the first page change.
    for (final b in bookings) {
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
  int _financialSummaryRequestGeneration = 0;

  Future<void> _fetchFinancialSummary(String uid) async {
    final requestGeneration = ++_financialSummaryRequestGeneration;
    if (mounted) {
      // Do not keep presenting a previously verified balance as current while
      // a new server snapshot is being requested.
      setState(() => _financialSummary = null);
    }
    try {
      final summary = await OwnerRepository().getOwnerFinancialSummary(uid);
      if (!mounted ||
          requestGeneration != _financialSummaryRequestGeneration ||
          context.read<AuthProvider>().currentUser?.id != uid) {
        return;
      }
      setState(() {
        _financialSummary = summary;
      });
    } catch (e) {
      VSPLogger.w('Failed to load owner financial summary for dashboard: $e');
      if (mounted &&
          requestGeneration == _financialSummaryRequestGeneration &&
          context.read<AuthProvider>().currentUser?.id == uid) {
        setState(() => _financialSummary = null);
      }
    }
  }

  Future<void> _fetchOwnerChampionships(String uid) async {
    final requestGeneration = ++_championshipFetchGeneration;
    try {
      final champs = await TournamentRepository()
          .getChampionships(isOwner: true, ownerId: uid);
      if (!mounted ||
          requestGeneration != _championshipFetchGeneration ||
          context.read<AuthProvider>().currentUser?.id != uid) {
        return;
      }
      setState(() {
        _ownerChampionships = champs;
        _hasChampionshipStreamError = false;
      });
      _claimApprovedChampionshipHomeNotices(uid, champs);
    } catch (e) {
      VSPLogger.w('Failed to refresh owner championships for dashboard: $e');
      if (mounted &&
          requestGeneration == _championshipFetchGeneration &&
          context.read<AuthProvider>().currentUser?.id == uid) {
        setState(() => _hasChampionshipStreamError = true);
      }
    }
  }

  Future<void> _claimApprovedChampionshipHomeNotices(
    String ownerId,
    List<Championship> champs,
  ) async {
    final repo = TournamentRepository();
    final now = DateTime.now().toUtc();
    final ownerScopeGeneration = _ownerScopeGeneration;

    for (final championship in champs) {
      if (!championship.isApproved) continue;
      if (!mounted ||
          ownerScopeGeneration != _ownerScopeGeneration ||
          context.read<AuthProvider>().currentUser?.id != ownerId) {
        return;
      }

      try {
        final response = await repo.claimOwnerChampionshipApprovalHomeNotice(championship.id);

        // A response from the previous owner must never repopulate the new
        // account's notice state after an account switch or dashboard rebuild.
        if (!mounted ||
            ownerScopeGeneration != _ownerScopeGeneration ||
            context.read<AuthProvider>().currentUser?.id != ownerId) {
          return;
        }

        if (response['success'] == true && response['seen_until'] != null) {
          final seenUntil = DateTime.tryParse(response['seen_until'].toString());
          if (seenUntil != null && seenUntil.isAfter(now)) {
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
  int _analyticsRequestGeneration = 0;

  Future<void> _loadDashboardAnalytics({String? ownerId, DashboardFilter? filter}) async {
    final uid = ownerId ?? Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    if (uid == null) return;
    final activeFilter = filter ?? _currentFilter;
    final requestGeneration = ++_analyticsRequestGeneration;

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

      if (!mounted || requestGeneration != _analyticsRequestGeneration ||
          context.read<AuthProvider>().currentUser?.id != uid) {
        return;
      }

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
      if (mounted && requestGeneration == _analyticsRequestGeneration &&
          context.read<AuthProvider>().currentUser?.id == uid) {
        setState(() {
          _isLoadingAnalytics = false;
          _analyticsError = 'failed';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final ownerId = auth.isOwner ? auth.currentUser?.id : null;
    if (_hasObservedOwnerScope && ownerId == _activeOwnerScope) return;

    _hasObservedOwnerScope = true;
    _activeOwnerScope = ownerId;
    final generation = ++_ownerScopeGeneration;

    _champSubscription?.cancel();
    _champSubscription = null;
    _financialSummaryRequestGeneration++;
    _analyticsRequestGeneration++;
    _championshipFetchGeneration++;
    _financialSummary = null;
    _ownerChampionships = [];
    _hasChampionshipStreamError = false;
    _dashboardAnalytics = const DashboardAnalytics();
    _currentFilter = DashboardFilter.today();
    _selectedStadiumFilter = 'all';
    _selectedTimePeriod = 'today';
    _cachedMetrics = null;
    _lastMetricsKey = null;
    _selectedDashboardTab = 0;
    _analyticsError = null;
    _isLoadingAnalytics = false;
    _approvalNoticeSeenUntil.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _ownerScopeGeneration ||
          context.read<AuthProvider>().currentUser?.id != ownerId) {
        return;
      }
      if (ownerId == null) return;

      _fetchFinancialSummary(ownerId);
      _loadDashboardAnalytics(ownerId: ownerId);
      _fetchOwnerChampionships(ownerId);
      context.read<BookingProvider>().loadOwnerBookings(ownerId);
      context.read<StadiumProvider>().listenToOwnerStadiums(ownerId);

      _champSubscription = TournamentRepository()
          .getChampionshipsStream(isOwner: true, ownerId: ownerId)
          .listen(
        (champs) {
          if (!mounted ||
              generation != _ownerScopeGeneration ||
              context.read<AuthProvider>().currentUser?.id != ownerId) {
            return;
          }
          setState(() {
            _ownerChampionships = champs;
            _hasChampionshipStreamError = false;
          });
        },
        onError: (e) {
          VSPLogger.w('Owner championships subscription notice (handled): $e');
          if (mounted &&
              generation == _ownerScopeGeneration &&
              context.read<AuthProvider>().currentUser?.id == ownerId) {
            setState(() => _hasChampionshipStreamError = true);
          }
        },
      );
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

    final bookingProvider = Provider.of<BookingProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final allBookings = bookingProvider.userBookings;
    final stadiums = stadiumProvider.stadiums;

    final metrics = _getOrCalculateMetrics(allBookings);

    final rawAvailableBalance = _financialSummary?['available_balance'];
    final parsedAvailableBalance = rawAvailableBalance is num
        ? rawAvailableBalance.toDouble()
        : double.tryParse(rawAvailableBalance?.toString() ?? '');
    final bool balanceVerified = _financialSummary?['success'] == true && parsedAvailableBalance != null;
    final double availableBalance = parsedAvailableBalance ?? 0.0;

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        top: false,
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
                if (_hasChampionshipStreamError) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                      border: Border.all(color: VSPColors.warning.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.warning_2_copy, size: 15, color: VSPColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabic
                                ? 'تعذر تحديث بيانات البطولات. نعرض آخر بيانات تم تحميلها.'
                                : 'Could not refresh tournament data. Showing the last loaded information.',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final uid = auth.currentUser?.id;
                            if (uid != null) _fetchOwnerChampionships(uid);
                          },
                          child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
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
                            isArabic
                                ? 'تعذر تحميل التحليلات. تحقق من الاتصال وحاول مرة أخرى.'
                                : 'Could not load analytics. Check your connection and retry.',
                            style: const TextStyle(color: VSPColors.error, fontSize: 11.5),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoadingAnalytics ? null : () => _loadDashboardAnalytics(),
                          child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                ],

                // Header الأساسي للمالك: الصورة + الاسم + الإشعارات + VSP Copilot.
                OwnerDashboardHeader(
                  auth: auth,
                  isProOwner: isProOwner,
                  isArabic: isArabic,
                  onUpgrade: () => _showProUpgradeSheet(context),
                ),
                const SizedBox(height: 14),

                // 3. شريط التبديل بين [ التشغيل اليومي ] و [ التحليلات والقرارات ]
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: _selectedDashboardTab == 0,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(21),
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
                      ),
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: _selectedDashboardTab == 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(21),
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
                              child: Text(
                                isArabic ? 'التحليلات الذكية' : 'Insights',
                                style: TextStyle(
                                  color: _selectedDashboardTab == 1 ? Colors.black : VSPColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
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
                // المالية أولاً: إجمالي المال المحقق ثم الكاش والأونلاين ثم الرصيد الجاهز للسحب.
                OwnerOperationalFinanceCard(
                  collectedCash: _dashboardAnalytics.revenue.cashCollected,
                  collectedOnline: _dashboardAnalytics.revenue.onlineCollected,
                  cashDue: _dashboardAnalytics.revenue.cashUncollected,
                  onlinePending: _dashboardAnalytics.revenue.onlinePending,
                  onlineHeld: _dashboardAnalytics.revenue.onlineUnavailable,
                  availableBalance: availableBalance,
                  balanceVerified: balanceVerified,
                  upcomingValue: _dashboardAnalytics.revenue.upcomingConfirmedValue,
                  isProOwner: isProOwner,
                  onUpgrade: () => _showProUpgradeSheet(context),
                  onOpenLedger: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()),
                    );
                  },
                  onRequestPayout: () {
                    OwnerPayoutDialog.show(context, availableBalance, isArabic);
                  },
                  onOpenPayoutHistory: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OwnerLedgerScreen(payoutOnly: true),
                      ),
                    );
                  },
                  isArabic: isArabic,
                ),
                const SizedBox(height: 14),


                  // جدول حجوزات اليوم — يأتي مباشرة بعد الكارت المالي.
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
                isArabic ? 'الترقية للباقة الاحترافية' : 'Upgrade to Pro',
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
