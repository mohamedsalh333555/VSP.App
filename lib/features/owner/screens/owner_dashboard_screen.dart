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
import '../../../core/repositories/owner_repository.dart';
import '../widgets/ledger/owner_payout_dialog.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../widgets/dashboard/owner_pro_insights_view.dart';
import '../widgets/dashboard/owner_verification_banner.dart';
import '../widgets/dashboard/owner_venue_filter_chips.dart';
import '../widgets/dashboard/owner_dashboard_header.dart';
import '../widgets/dashboard/owner_operational_finance_card.dart';
import '../widgets/dashboard/owner_today_pitch_schedule_card.dart';
import '../widgets/dashboard/owner_pending_actions_bar.dart';

/// لوحة تحكم المالك المتجاوبة مع باقات الاشتراك (Basic vs Pro)
class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const OwnerDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  int _selectedDashboardTab = 0; // 0 = التشغيل اليومي, 1 = التحليلات (Insights)
  String _selectedStadiumFilter = 'all';
  String _selectedTimePeriod = 'today';
  StreamSubscription? _champSubscription;
  List<Championship> _ownerChampionships = [];

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
      }
    } catch (e) {
      VSPLogger.w('Failed to refresh owner championships for dashboard: $e');
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

    final double availableBalance = (_financialSummary?['available_balance'] as num?)?.toDouble() ??
        metrics.digitalVspBalance;

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

                const SizedBox(height: 12),

                // 3. شريط التبديل بين [ التشغيل اليومي ⚡ ] و [ التحليلات والقرارات 📊 ]
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
                              isArabic ? 'التشغيل اليومي ⚡' : 'Operations ⚡',
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
                                  isArabic ? 'التحليلات الذكية 📊' : 'Insights 📊',
                                  style: TextStyle(
                                    color: _selectedDashboardTab == 1 ? Colors.black : VSPColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                if (!isProOwner) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_rounded, size: 13, color: Colors.amber),
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
                  // شريط فلاتر الملاعب (يظهر لأصحاب باقة Pro عند امتلاك أكثر من ملعب)
                  if (isProOwner && stadiums.length > 1) ...[
                    OwnerVenueFilterChips(
                      stadiums: stadiums,
                      selectedStadiumId: _selectedStadiumFilter,
                      onStadiumSelected: (id) => setState(() {
                        _selectedStadiumFilter = id;
                        _cachedMetrics = null;
                      }),
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // شريط الفلتر الزمني الواضح
                  _buildTimeFilterBar(isArabic),
                  const SizedBox(height: 12),

                  // أ. كارت المالية والتشغيل الموحد (نفس موقع زر السحب للباقتين)
                  OwnerOperationalFinanceCard(
                    availableBalance: availableBalance,
                    cashThisMonth: metrics.pitchCashRevenue,
                    onlineThisMonth: metrics.digitalVspBalance,
                    timePeriod: _selectedTimePeriod,
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

                  // ب. كارت جدول مواعيد اليوم بالنقط الملونة (ملعبك النهارده) - متاح للباقتين لتشغيل الملاعب
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

                  // ج. البطولة القادمة: تظهر عند وجود بطولة معتمدة
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final upcoming = _ownerChampionships
                          .where((c) =>
                              c.isApproved &&
                              c.status.toLowerCase() != 'completed' &&
                              (c.status.toLowerCase() == 'open' ||
                                  c.status.toLowerCase() == 'ongoing' ||
                                  c.endDate.isAfter(now)))
                          .toList()
                        ..sort((a, b) => a.startDate.compareTo(b.startDate));

                      if (upcoming.isEmpty) return const SizedBox.shrink();
                      final championship = upcoming.first;

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: VSPColors.surface,
                          borderRadius: BorderRadius.circular(VSPRadius.card),
                          border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.emoji_events_outlined, color: VSPColors.accent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isArabic ? 'البطولة القادمة' : 'Upcoming Tournament',
                                    style: const TextStyle(
                                      color: VSPColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  isArabic ? 'معتمدة' : 'Approved',
                                  style: const TextStyle(
                                    color: VSPColors.accent,
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
                              isArabic
                                  ? 'تبدأ ${championship.startDate.day}/${championship.startDate.month}/${championship.startDate.year} • ${championship.joinedTeams.length}/${championship.maxTeams} فريق'
                                  : 'Starts ${championship.startDate.day}/${championship.startDate.month}/${championship.startDate.year} • ${championship.joinedTeams.length}/${championship.maxTeams} teams',
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

                  // هـ. إجراءات تشغيلية سريعة تملأ المساحة وتوفر وصولاً سريعاً
                  _buildQuickOperationalActions(context, isArabic),
                  const SizedBox(height: 32),
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
                      onTimePeriodChanged: (period) => setState(() {
                        _selectedTimePeriod = period;
                        _cachedMetrics = null;
                      }),
                      onStadiumFilterChanged: (id) => setState(() {
                        _selectedStadiumFilter = id;
                        _cachedMetrics = null;
                      }),
                      onNavigateTab: widget.onNavigateTab,
                      isArabic: isArabic,
                    )
                  else
                    _buildProInsightsLockedTeaser(context, isArabic),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterBar(bool isArabic) {
    final periods = [
      {'key': 'today', 'labelAr': 'اليوم', 'labelEn': 'Today'},
      {'key': 'week', 'labelAr': 'هذا الأسبوع', 'labelEn': 'This Week'},
      {'key': 'month', 'labelAr': 'هذا الشهر', 'labelEn': 'This Month'},
      {'key': 'all', 'labelAr': 'الكل', 'labelEn': 'All Time'},
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = periods[index];
          final isSelected = _selectedTimePeriod == p['key'];
          final label = isArabic ? p['labelAr']! : p['labelEn']!;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedTimePeriod = p['key']!;
                _cachedMetrics = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? VSPColors.accent.withValues(alpha: 0.15)
                    : VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.full),
                border: Border.all(
                  color: isSelected
                      ? VSPColors.accent
                      : VSPColors.divider.withValues(alpha: 0.6),
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickOperationalActions(BuildContext context, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.card),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'إجراءات تشغيلية سريعة' : 'Quick Operations',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: isArabic ? 'كشف الحساب' : 'Ledger',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.calendar_month_outlined,
                  label: isArabic ? 'جدول الحجوزات' : 'Bookings',
                  onTap: () {
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
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.workspace_premium_outlined,
                  label: isArabic ? 'الباقات' : 'Plans',
                  onTap: () => _showProUpgradeSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: VSPColors.surfaceAlt,
          borderRadius: BorderRadius.circular(VSPRadius.sm),
          border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: VSPColors.accent),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProInsightsLockedTeaser(BuildContext context, bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.25),
                    Colors.amber.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: const Icon(Iconsax.chart_2_copy, color: Colors.amber, size: 32),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isArabic ? '📊 تحليلات وقرارات الملاعب الذكية' : 'Smart Pitch Insights & Decisions',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'ميزة حصرية لمشتركي الباقة الاحترافية (1000 ج.م شهرياً)'
                : 'Exclusive to 1000 EGP Pro Plan Subscribers',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 8),

          _buildTeaserFeatureRow(
            icon: Iconsax.status_up_copy,
            title: isArabic ? 'معدل إشغال الملعب الفعلي' : 'Pitch Occupancy Rate',
            subtitle: isArabic
                ? 'حساب نسبة استغلال ساعات الملعب مقارنة بالطاقة القصوى'
                : 'Compare booked hours vs maximum capacity',
          ),
          const SizedBox(height: 10),
          _buildTeaserFeatureRow(
            icon: Iconsax.money_remove_copy,
            title: isArabic ? 'مؤشر «الإيراد الضائع»' : 'Lost Revenue Indicator',
            subtitle: isArabic
                ? 'كشف قيمة المبالغ المهدرة من الساعات غير المحجوزة'
                : 'Track unearned money from idle pitch hours',
          ),
          const SizedBox(height: 10),
          _buildTeaserFeatureRow(
            icon: Iconsax.card_pos_copy,
            title: isArabic ? 'تحليل مصادر الدخل الرقمي والكاش' : 'Revenue Breakdown (Digital vs Cash)',
            subtitle: isArabic
                ? 'توزيع دقيق ومقارنات أسبوعية وشهرية للأرباح'
                : 'Detailed cash vs digital tracking and weekly growth',
          ),
          const SizedBox(height: 10),
          _buildTeaserFeatureRow(
            icon: Iconsax.ranking_copy,
            title: isArabic ? 'تفضيلات اللاعبين وأنواع الحجوزات' : 'Booking Types & Player Preferences',
            subtitle: isArabic
                ? 'معرفة الحصص الأكثر طلباً (تحديات، تجميع، شخصي)'
                : 'Identify top booking patterns and peak demands',
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showProUpgradeSheet(context),
            icon: const Icon(Icons.star_rounded, color: Colors.black, size: 20),
            label: Text(
              isArabic ? 'الترقية للباقة الاحترافية (1000 ج)' : 'Upgrade to Pro Plan (1000 EGP)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
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
          Icon(icon, color: Colors.amber, size: 20),
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
}
