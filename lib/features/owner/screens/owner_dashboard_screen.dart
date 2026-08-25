import 'dart:async';
import 'dart:ui';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../data/models.dart';
import '../../../features/player/screens/notifications_center_screen.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';
import 'create_tournament_wizard.dart';
import 'owner_ledger_screen.dart';
import '../../../core/utils/app_date_formatter.dart';

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
}

/// محرك الحسابات المالية المفصول عن واجهة المستخدم
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
      final bool isPaidInFull = b.isPaid || b.paymentStatus == 'paid' || (totalPrice > 0 && b.depositPaid >= totalPrice);
      final double paidAmount = isPaidInFull ? totalPrice : (b.depositPaid > 0 ? b.depositPaid : 0.0);
      final double remainingAmount = (totalPrice - paidAmount).clamp(0.0, 999999.0);

      pendingReceivables += remainingAmount;
      totalPipeline += totalPrice;

      final String method = b.paymentMethod.toLowerCase().trim();
      final bool isManual = (method == 'cash' || (b.paymentTransactionId?.startsWith('MANUAL') == true));

      final bool isOnlinePayment = !isManual && (
        method.contains('paymob') ||
        method.contains('card') ||
        method.contains('visa') ||
        method.contains('mastercard') ||
        method.contains('wallet') ||
        method.contains('online') ||
        method.contains('instapay') ||
        method.contains('vodafone') ||
        (b.paymentTransactionId?.startsWith('PAYMOB') == true) ||
        b.isPaid == true ||
        b.paymentStatus == 'paid'
      );

      if (isOnlinePayment) {
        final onlinePaid = (b.depositPaid > 0 ? b.depositPaid : paidAmount);
        digitalVspBalance += onlinePaid;
        pitchCashRevenue += (paidAmount - onlinePaid).clamp(0.0, 999999.0);
      } else {
        pitchCashRevenue += paidAmount;
      }

      final diffMinutes = b.endTime.difference(b.startTime).inMinutes;
      totalHours += (diffMinutes / 60.0);
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
}

/// لوحة تحكم المالك الفاخرة الموحدة لغوياً وبصرياً
class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const OwnerDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  String _selectedTimePeriod = 'today';
  String _selectedStadiumFilter = 'all';
  StreamSubscription<List<Championship>>? _champSubscription;
  List<Championship> _ownerChampionships = [];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated && auth.firebaseUser != null) {
        final uid = auth.firebaseUser!.uid;
        final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
        stadiumProvider.listenToOwnerStadiums(uid);

        if (!mounted) return;
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid, forceRefresh: true);

        _champSubscription?.cancel();
        _champSubscription = TournamentRepository()
            .getChampionshipsStream(isOwner: true, ownerId: uid)
            .listen((champs) {
          if (!mounted) return;
          setState(() {
            _ownerChampionships = champs;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _champSubscription?.cancel();
    super.dispose();
  }

  void _showProUpgradeSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()));
  }

  void _navigateToWalkInBooking(BuildContext context, bool isExpired) {
    HapticFeedback.mediumImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final status = auth.userModel?.verificationStatus;
    final isUnderReview = status == 'pending' || status == 'under_review';
    final isRejected = status == 'rejected';

    if (isUnderReview || isRejected) {
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'عذراً، حسابك قيد المراجعة والتوثيق من قِبل إدارة التطبيق.'
            : 'Account under review. Bookings disabled until approval.',
      );
      return;
    }

    if (isExpired) {
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'الاشتراك منتهي. يرجى التجديد لتفعيل الحجوزات.'
            : 'Subscription expired. Please renew to resume bookings.',
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final userModel = auth.userModel;
    final isProOwner = userModel?.isProPlan == true;

    bool isExpired = false;
    bool isUnderReview = false;
    if (userModel != null) {
      isUnderReview = userModel.verificationStatus == 'pending' || userModel.verificationStatus == 'under_review';
      if (userModel.trialEndsAt == null && userModel.subscriptionExpiresAt == null) {
        isExpired = false;
      } else {
        isExpired = userModel.isPlanExpired;
      }
    }

    final bookingProvider = Provider.of<BookingProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context);
    final allBookings = bookingProvider.userBookings;
    final stadiums = stadiumProvider.stadiums;

    final metrics = OwnerFinancialCalculator.calculate(
      allBookings: allBookings,
      ownerChampionships: _ownerChampionships,
      timePeriod: _selectedTimePeriod,
      stadiumFilter: _selectedStadiumFilter,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: RefreshIndicator(
          color: VSPColors.accent,
          backgroundColor: const Color(0xFF18181B),
          onRefresh: () async {
            await auth.refreshProfile();
            if (context.mounted) {
              final uid = auth.currentUser?.uid;
              if (uid != null) {
                await Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
              }
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. الهيدر الموحد
                _buildSleekHeader(auth, stadiums, isArabic),
                const SizedBox(height: 16),

                // 2. تنبيه الحساب الخفيف
                if (userModel != null && (isExpired || isUnderReview))
                  _buildSlimAlert(userModel, isArabic, isExpired, isUnderReview),

                // 3. النبض اللحظي للملعب
                _buildLiveHeroCockpit(context, allBookings, stadiums, isArabic, isExpired),
                const SizedBox(height: 16),

                // 4. كبسولة الأرباح والإشغال
                _buildFinancialGlance(metrics, isProOwner, isArabic),
                const SizedBox(height: 16),

                // 5. شريط الإجراءات السريعة
                _buildQuickActionDock(context, isArabic, isExpired),
                const SizedBox(height: 20),

                // 6. جدول حجوزات اليوم
                _buildGlanceableTimeline(context, allBookings, isArabic),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. الهيدر الموحد لغوياً
  Widget _buildSleekHeader(AuthProvider auth, List<Stadium> stadiums, bool isArabic) {
    final name = (auth.userModel?.name ?? (isArabic ? 'كابتن' : 'Captain')).split(' ').first;
    final isPro = auth.userModel?.isProPlan == true;
    final isTrial = auth.userModel?.isInActiveTrial == true;
    final isExpired = auth.userModel?.isPlanExpired == true;

    String statusLabel = isArabic ? 'مميز' : 'VIP';
    IconData statusIcon = Iconsax.crown_copy;

    if (isExpired) {
      statusLabel = isArabic ? 'منتهي' : 'Expired';
      statusIcon = Iconsax.warning_2_copy;
    } else if (isPro) {
      statusLabel = isArabic ? 'احترافي' : 'PRO';
      statusIcon = Iconsax.crown_copy;
    } else if (isTrial) {
      final days = auth.userModel?.effectiveTrialEndsAt != null
          ? auth.userModel!.effectiveTrialEndsAt!.difference(DateTime.now()).inDays
          : 60;
      statusLabel = isArabic ? 'تجريبي ($days يوم)' : 'Trial ($days d)';
      statusIcon = Iconsax.flash_1_copy;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isArabic ? 'أهلاً، $name' : 'Hi, $name',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showProUpgradeSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: Colors.white70, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              if (stadiums.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStadiumFilter,
                    dropdownColor: const Color(0xFF18181B),
                    icon: const Icon(Iconsax.arrow_down_1_copy, size: 13, color: Colors.white70),
                    isDense: true,
                    style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.w500),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(isArabic ? '🏟️ جميع الملاعب' : '🏟️ All Stadiums'),
                      ),
                      ...stadiums.map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('🏟️ ${s.name}'),
                          )),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStadiumFilter = val);
                      }
                    },
                  ),
                )
              else if (stadiums.isNotEmpty)
                Text(
                  '🏟️ ${stadiums.first.name}',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, fontWeight: FontWeight.w500),
                )
              else
                Text(
                  isArabic ? 'لوحة تحكم المنشأة' : 'Facility Dashboard',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
                ),
            ],
          ),
        ),
        StreamBuilder<int>(
          stream: NotificationRepository().getUnreadNotificationCount(
            context.read<AuthProvider>().currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                  backgroundColor: VSPColors.accent,
                  child: const Icon(Iconsax.notification_copy, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()));
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// 2. تنبيه الحساب الخفيف
  Widget _buildSlimAlert(UserModel userModel, bool isArabic, bool isExpired, bool isUnderReview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.info_circle_copy, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExpired
                  ? (isArabic ? 'انتهت صلاحية الاشتراك. يرجى التجديد لتفعيل الحجوزات.' : 'Subscription expired. Renew now.')
                  : (isArabic ? 'حسابك قيد المراجعة والتوثيق من إدارة التطبيق.' : 'Account is under review.'),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (isExpired)
            GestureDetector(
              onTap: () => _showProUpgradeSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isArabic ? 'تجديد' : 'Renew',
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 3. النبض اللحظي للملعب
  Widget _buildLiveHeroCockpit(
    BuildContext context,
    List<Booking> allBookings,
    List<Stadium> stadiums,
    bool isArabic,
    bool isExpired,
  ) {
    final now = DateTime.now();

    Booking? activeBooking;
    Booking? nextBooking;

    final sortedToday = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (_selectedStadiumFilter != 'all' && b.stadiumId != _selectedStadiumFilter) return false;
      final bStart = b.startTime.toLocal();
      return bStart.year == now.year && bStart.month == now.month && bStart.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final b in sortedToday) {
      final start = b.startTime.toLocal();
      final end = b.endTime.toLocal();
      if (now.isAfter(start) && now.isBefore(end)) {
        activeBooking = b;
      } else if (now.isBefore(start) && nextBooking == null) {
        nextBooking = b;
      }
    }

    final bool isOccupied = activeBooking != null;
    final String locale = isArabic ? 'ar' : 'en';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOccupied
              ? VSPColors.accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOccupied
                              ? VSPColors.accent.withValues(alpha: 0.4 + (_pulseController.value * 0.6))
                              : Colors.white24,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOccupied
                        ? (isArabic ? 'الملعب مشغول الآن' : 'PITCH OCCUPIED')
                        : (isArabic ? 'الملعب شاغر حالياً' : 'PITCH VACANT'),
                    style: TextStyle(
                      color: isOccupied ? VSPColors.accent : const Color(0xFFA1A1AA),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (isOccupied) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VSPColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '⏳ ${activeBooking.endTime.toLocal().difference(now).inMinutes} ${isArabic ? "دقيقة متبقية" : "min left"}',
                    style: const TextStyle(color: VSPColors.accent, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          if (isOccupied) ...[
            Text(
              (activeBooking.hostName != null && activeBooking.hostName!.isNotEmpty)
                  ? activeBooking.hostName!
                  : (isArabic ? 'حجز ملعب' : 'Match Booking'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Iconsax.clock_copy, size: 13, color: Color(0xFFA1A1AA)),
                const SizedBox(width: 6),
                Text(
                  '${AppDateFormatter.formatTime(activeBooking.startTime.toLocal(), locale)} — ${AppDateFormatter.formatTime(activeBooking.endTime.toLocal(), locale)}',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activeBooking.isPaid ? (isArabic ? 'مدفوع' : 'Paid') : (isArabic ? 'كاش' : 'Cash'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (activeBooking.playerPhone != null && activeBooking.playerPhone!.isNotEmpty) ...[
                  Expanded(
                    child: _buildMicroAction(
                      icon: Iconsax.call_copy,
                      label: isArabic ? 'اتصال بالكابتن' : 'Call Captain',
                      onTap: () => VSPLauncherUtils.makePhoneCall(context, activeBooking!.playerPhone!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMicroAction(
                      icon: Iconsax.message_copy,
                      label: isArabic ? 'واتساب' : 'WhatsApp',
                      onTap: () => VSPLauncherUtils.openWhatsApp(
                        context,
                        phone: activeBooking!.playerPhone!,
                        message: isArabic ? 'مرحباً كابتن ${activeBooking.hostName ?? ""}، بخصوص حجزك في الملعب...' : 'Hi Captain ${activeBooking.hostName ?? ""}, regarding your booking...',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Text(
              nextBooking != null
                  ? (isArabic
                      ? 'الماتش القادم: ${(nextBooking.hostName != null && nextBooking.hostName!.isNotEmpty) ? nextBooking.hostName! : (isArabic ? "حجز" : "Booking")}'
                      : 'Next Match: ${nextBooking.hostName ?? "Booking"}')
                  : (isArabic ? 'لا توجد مباريات أخرى اليوم' : 'No more matches scheduled today'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (nextBooking != null) ...[
              Text(
                '⏰ ${isArabic ? "يبدأ في" : "Starts at"} ${AppDateFormatter.formatTime(nextBooking.startTime.toLocal(), locale)}',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.5),
              ),
            ] else ...[
              Text(
                isArabic ? 'الملعب متاح لاستقبال الحجوزات المباشرة.' : 'Ready for walk-in and phone bookings.',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _navigateToWalkInBooking(context, isExpired),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.add_circle_copy, color: Colors.white, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      isArabic ? 'تسجيل حجز كاش الآن' : 'Record Walk-In Booking',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 4. كبسولة الأرباح والإشغال الموحدة لغوياً
  Widget _buildFinancialGlance(OwnerFinancialMetrics metrics, bool isProOwner, bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الإيرادات والتشغيل' : 'Revenue & Metrics',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildPeriodPill('today', isArabic ? 'اليوم' : 'Today'),
                      const SizedBox(width: 4),
                      _buildPeriodPill('yesterday', isArabic ? 'أمس' : 'Yest'),
                      const SizedBox(width: 4),
                      _buildPeriodPill('week', isArabic ? 'الأسبوع' : 'Week'),
                      const SizedBox(width: 4),
                      _buildPeriodPill('month', isArabic ? 'الشهر' : 'Month'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metrics.totalPipeline.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  isArabic ? 'ج.م إجمالي' : 'EGP Total',
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'كاش الملعب' : 'Pitch Cash',
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.pitchCashRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'رصيد أونلاين' : 'Online Balance',
                        style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.digitalVspBalance.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIndicator(
                label: isArabic ? 'الحجوزات' : 'Bookings',
                value: '${metrics.activeBookingsCount}',
              ),
              _buildIndicator(
                label: isArabic ? 'ساعات اللعب' : 'Play Hours',
                value: '${metrics.totalHours.toStringAsFixed(1)} ${isArabic ? "ساعة" : "h"}',
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()));
                },
                child: Text(
                  isArabic ? 'السجل المالي ➔' : 'Financial Ledger ➔',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPill(String periodKey, String label) {
    final isSelected = _selectedTimePeriod == periodKey;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTimePeriod = periodKey);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : const Color(0xFFA1A1AA),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator({required String label, required String value}) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// 5. شريط الإجراءات السريعة
  Widget _buildQuickActionDock(BuildContext context, bool isArabic, bool isExpired) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: GestureDetector(
            onTap: () => _navigateToWalkInBooking(context, isExpired),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.add_square_copy, color: Colors.black, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'حجز كاش سريع' : 'Quick Walk-In',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        Expanded(
          flex: 4,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.calendar_1_copy, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'الجدول الكامل' : 'Schedule',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTournamentWizard()));
          },
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Iconsax.cup_copy, color: Colors.white70, size: 19),
          ),
        ),
      ],
    );
  }

  /// 6. جدول حجوزات اليوم الموحد
  Widget _buildGlanceableTimeline(BuildContext context, List<Booking> allBookings, bool isArabic) {
    final now = DateTime.now();
    final String locale = isArabic ? 'ar' : 'en';

    final todayBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (_selectedStadiumFilter != 'all' && b.stadiumId != _selectedStadiumFilter) return false;
      final bStart = b.startTime.toLocal();
      return bStart.year == now.year && bStart.month == now.month && bStart.day == now.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'حجوزات اليوم' : "Today's Bookings",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
              },
              child: Text(
                isArabic ? 'عرض الكل ➔' : 'View All ➔',
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (todayBookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141417),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.calendar_tick_copy, size: 28, color: Color(0xFFA1A1AA)),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'لا توجد حجوزات مسجلة اليوم' : 'No bookings recorded today',
                  style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayBookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final b = todayBookings[index];
              final isOngoing = now.isAfter(b.startTime.toLocal()) && now.isBefore(b.endTime.toLocal());
              final isPassed = now.isAfter(b.endTime.toLocal());

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isOngoing ? const Color(0xFF12231A) : const Color(0xFF141417),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOngoing
                        ? VSPColors.accent.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOngoing
                            ? VSPColors.accent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppDateFormatter.formatTime(b.startTime.toLocal(), locale),
                        style: TextStyle(
                          color: isOngoing ? VSPColors.accent : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (b.hostName != null && b.hostName!.isNotEmpty) ? b.hostName! : (isArabic ? 'حجز ملعب' : 'Booking'),
                            style: TextStyle(
                              color: isPassed ? const Color(0xFFA1A1AA) : Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              decoration: isPassed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${b.totalPrice > 0 ? b.totalPrice.toStringAsFixed(0) : b.depositPaid.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 6),
                              Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                              const SizedBox(width: 6),
                              Text(
                                b.isPaid ? (isArabic ? 'مدفوع' : 'Paid') : (isArabic ? 'كاش' : 'Cash'),
                                style: TextStyle(
                                  color: b.isPaid ? VSPColors.accent : Colors.white60,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (b.playerPhone != null && b.playerPhone!.isNotEmpty && !isPassed) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.call_copy, size: 17, color: Colors.white70),
                        onPressed: () => VSPLauncherUtils.makePhoneCall(context, b.playerPhone!),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Iconsax.message_copy, size: 17, color: Colors.white70),
                        onPressed: () => VSPLauncherUtils.openWhatsApp(
                          context,
                          phone: b.playerPhone!,
                          message: isArabic ? 'مرحباً كابتن ${b.hostName ?? ""}، بخصوص حجزك اليوم...' : 'Hi Captain ${b.hostName ?? ""}, regarding your booking today...',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMicroAction({
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
