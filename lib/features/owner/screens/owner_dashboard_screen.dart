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
  String _selectedStadiumFilter = 'all';
  final String _selectedTimePeriod = 'today';
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
    final double cashThisMonth = (_financialSummary?['cash_revenue'] as num?)?.toDouble() ??
        metrics.pitchCashRevenue;
    final double onlineThisMonth = (_financialSummary?['online_net_revenue'] as num?)?.toDouble() ??
        (_financialSummary?['total_online_gross'] as num?)?.toDouble() ??
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

                // 3. المحتوى التشغيلي الموحد للباقتين (Operational Dashboard)
                // شريط فلاتر الملاعب (يظهر لأصحاب باقة Pro أو عند امتلاك أكثر من ملعب)
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

                // أ. كارت المالية والتشغيل الموحد (نفس موقع زر السحب للباقتين)
                OwnerOperationalFinanceCard(
                  availableBalance: availableBalance,
                  cashThisMonth: cashThisMonth,
                  onlineThisMonth: onlineThisMonth,
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

                // ب. كارت جدول مواعيد اليوم بالنقط الملونة (ملعبك النهارده)
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

                // ج. البطولة القادمة: لا تظهر للمالك إلا بعد اعتماد الإدارة.
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
