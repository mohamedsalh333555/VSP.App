import 'dart:async';
import 'dart:ui';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import '../../../features/player/screens/notifications_center_screen.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/repositories/tournament_repository.dart';

import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  bool _isPendingBannerDismissed = false;
  String _selectedTimePeriod = 'today'; // 'today' | 'week' | 'month' | 'all'
  StreamSubscription<List<Championship>>? _champSubscription;
  double _championshipDigitalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated && auth.firebaseUser != null) {
        final uid = auth.firebaseUser!.uid;
        final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
        stadiumProvider.listenToOwnerStadiums(uid);

        if (!mounted) return;
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid);

        _champSubscription?.cancel();
        _champSubscription = TournamentRepository()
            .getChampionshipsStream(isOwner: true, ownerId: uid)
            .listen((champs) {
          if (!mounted) return;
          double total = 0.0;
          for (var c in champs) {
            if (c.entryFee > 0 && c.paidTeams.isNotEmpty) {
              total += (c.paidTeams.length * c.entryFee);
            }
          }
          if (_championshipDigitalRevenue != total) {
            setState(() => _championshipDigitalRevenue = total);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _champSubscription?.cancel();
    super.dispose();
  }

  void _showProUpgradeSheet(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen()));
  }

  void _navigateToWalkInBooking(BuildContext context, bool isExpired) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final status = auth.userModel?.verificationStatus;
    final isUnderReview = status == 'pending' || status == 'under_review';
    final isRejected = status == 'rejected';

    if (isUnderReview || isRejected) {
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'عذراً، حسابك قيد المراجعة والتوثيق من قِبل إدارة التطبيق. الحجوزات معطلة حتى يتم الاعتماد والتفعيل من مالك التطبيق!'
            : 'Sorry, your account is under review. Bookings are disabled until admin approval!',
      );
      return;
    }

    if (isExpired) {
      VSPFeedback.showError(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'الاشتراك منتهي. يرجى التجديد لتفعيل إضافة الحجوزات.'
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
    if (userModel != null) {
      if (userModel.trialEndsAt == null && userModel.subscriptionExpiresAt == null) {
        isExpired = false;
      } else {
        isExpired = userModel.isPlanExpired;
      }
    }

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: VSPColors.accent,
          backgroundColor: VSPColors.surface,
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
            padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md, horizontal: VSPSpacing.md),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. الهيدر العلوي
              _buildHeader(auth, isArabic),
              const SizedBox(height: VSPSpacing.md),

              // 2. بانر التنبيه والاشتراك
              if (userModel != null) ...[
                _buildOwnerStatusBanner(userModel, isArabic, isExpired),
                const SizedBox(height: VSPSpacing.md),
              ],

              // 🔹 شريط النطاق الزمني (Time-Filter Bar)
              _buildTimeFilterBar(isArabic),
              const SizedBox(height: VSPSpacing.sm),

              // 🧮 3. المحرك المالي والكارت الرئيسي (Hero Revenue Card)
              _buildStatsGrid(isArabic),
              const SizedBox(height: VSPSpacing.lg),

              // 💡 4. شارات اللمحات الذكية
              _buildInsightBadges(isProOwner, isArabic),
              const SizedBox(height: VSPSpacing.xl),

              // 📋 5. قائمة الحجوزات الديناميكية
              Text(
                _selectedTimePeriod == 'today'
                    ? (isArabic ? 'حجوزات اليوم' : "Today's Bookings")
                    : (_selectedTimePeriod == 'week'
                        ? (isArabic ? 'حجوزات هذا الأسبوع' : "This Week's Bookings")
                        : (_selectedTimePeriod == 'month'
                            ? (isArabic ? 'حجوزات هذا الشهر' : "This Month's Bookings")
                            : (isArabic ? 'جميع الحجوزات' : 'All Bookings'))),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: VSPSpacing.md),
              _buildBookedTodayList(isArabic),
              const SizedBox(height: VSPSpacing.md),

              // ⚡ 6. زر الحجز السريع المباشر
              _buildQuickWalkInCTA(isArabic, isExpired),
            ],
          ),
        ),
      ),
    ),
  );
}
  /// 1. الهيدر الموحد لغوياً مع شارة الباقة الذهبية الهادئة
  Widget _buildHeader(AuthProvider auth, bool isArabic) {
    final firstName = (auth.userModel?.name ?? 'Owner').split(' ').first;
    final isProOwner = auth.userModel?.isProPlan == true;
    final isTrial = auth.userModel?.isInActiveTrial == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isArabic ? 'أهلاً $firstName' : 'Hi $firstName', 
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                if (isProOwner || isTrial) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showProUpgradeSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.crown_copy, color: Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            isTrial ? (isArabic ? 'تجريبي' : 'Trial') : 'Pro',
                            style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              isArabic ? 'لوحة تحكم الملعب' : 'Facility Dashboard', 
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        StreamBuilder<int>(
          stream: NotificationRepository().getUnreadNotificationCount(
            context.read<AuthProvider>().currentUser?.uid ?? '',
          ),
          builder: (context, snapshot) {
            final hasUnread = (snapshot.data ?? 0) > 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Iconsax.notification_copy, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsCenterScreen())),
                ),
                if (hasUnread)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (ctx, val, _) => Transform.scale(
                        scale: val,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: VSPColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: VSPColors.error.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1)],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 2. البانر الأمني الموحد لغوياً
  Widget _buildOwnerStatusBanner(dynamic userModel, bool isArabic, bool isExpired) {
    final String? verificationStatus = userModel.verificationStatus as String?;
    final bool isUnderReview = verificationStatus == 'pending' || verificationStatus == 'under_review';
    final bool isRejected = verificationStatus == 'rejected';

    if (isUnderReview && !_isPendingBannerDismissed) {
      return _buildCompactPendingBanner(isArabic);
    }

    if (isRejected) {
      return _buildRejectedBanner(isArabic);
    }

    return _buildSubscriptionPlanBanner(userModel, isArabic, isExpired);
  }

  Widget _buildRejectedBanner(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.security_safe_copy, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'تم رفض مستنداتك. يرجى إعادة رفع المستندات المطلوبة.'
                  : 'Your documents were rejected. Please re-upload the required documents.',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPendingBanner(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.clock_copy, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic ? "حسابك قيد المراجعة - الحجوزات ستفعل فور توثيق أوراقك." : "Under review - Bookings will activate once verified.",
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isPendingBannerDismissed = true),
            child: const Icon(Iconsax.close_circle_copy, color: Colors.orange, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlanBanner(dynamic userModel, bool isArabic, bool isExpired) {
    final bool isPro = userModel.isProPlan;
    final bool isTrial = userModel.isInActiveTrial;
    final DateTime? trialEnd = userModel.effectiveTrialEndsAt;
    final DateTime? subEnd = userModel.subscriptionExpiresAt;

    final now = DateTime.now();
    int remainingDays = 999;
    if (isTrial && trialEnd != null) {
      remainingDays = trialEnd.difference(now).inDays;
    } else if (subEnd != null) {
      remainingDays = subEnd.difference(now).inDays;
    }

    // 🌟 DYNAMIC STATE MACHINE ARCHITECTURE:
    // 1. ACTIVE & HEALTHY (> 7 days left on Pro/Paid plan):
    //    -> HIDE BANNER COMPLETELY! User has subtle gold Pro badge in header.
    // 2. RENEWAL WARNING (<= 7 days left or in active trial):
    //    -> Show Amber Warning Banner ("متبقي X أيام على تجديد الاشتراك - تجديد الآن ⚡")
    // 3. EXPIRED:
    //    -> Show Red Danger Banner ("انتهت الباقة! ادفع الآن لتفعيل الملاعب ⚠️")

    if (!isExpired && isPro && !isTrial && remainingDays > 7) {
      return const SizedBox.shrink();
    }

    final String trialEndDateStr = trialEnd != null ? DateFormat('yyyy/MM/dd').format(trialEnd) : '';

    final String planLabel = isExpired
        ? (isArabic ? 'انتهت الباقة - ادفع الآن ⚠️' : 'Plan Expired - Renew Now ⚠️')
        : (isTrial
            ? (isArabic ? 'فترة تجريبية (متبقي $remainingDays يوم)' : 'Free Trial ($remainingDays days left)')
            : (remainingDays <= 7
                ? (isArabic ? 'تجديد قريب (متبقي $remainingDays يوم ⏳)' : 'Renewal Due ($remainingDays days left ⏳)')
                : (isArabic ? 'احترافية (Pro)' : 'Pro Plan')));

    final String subtitleText = isExpired
        ? (isArabic ? 'انتهت فترة الاشتراك. يرجى التجديد لتشغيل الحجوزات.' : 'Subscription ended. Renew to enable bookings.')
        : (isTrial
            ? (isArabic ? 'ينتهي التجريبي في $trialEndDateStr | الملاعب: ${userModel.maxStadiums}' : 'Ends on $trialEndDateStr | Stadiums: ${userModel.maxStadiums}')
            : (remainingDays <= 7
                ? (isArabic ? 'يرجى التجديد قبل انتهاء المدة لتجنب توقف الحجوزات.' : 'Please renew to prevent service interruption.')
                : '${isArabic ? "الملاعب المسموحة:" : "Allowed Stadiums:"} ${userModel.maxStadiums}'));

    final String buttonLabel = isExpired
        ? (isArabic ? 'ادفع الآن' : 'Pay Now')
        : (remainingDays <= 7
            ? (isArabic ? 'تجديد ⚡' : 'Renew ⚡')
            : (isArabic ? 'ترقية' : 'Upgrade'));

    final Color statusColor = isExpired
        ? Colors.redAccent
        : Colors.amber;

    return InkWell(
      onTap: () => _showProUpgradeSheet(context),
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.15)
              : Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isExpired ? Colors.redAccent : Colors.amber,
            width: isExpired ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpired
                  ? Iconsax.security_safe_copy
                  : (remainingDays <= 7 || isTrial ? Iconsax.clock_copy : Iconsax.crown_copy),
              color: statusColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isExpired)
                        Text(
                          '${isArabic ? "الباقة:" : "Plan:"} ',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      Expanded(
                        child: Text(
                          planLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      color: isExpired ? Colors.redAccent : VSPColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: () => _showProUpgradeSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    buttonLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Iconsax.arrow_up_3_copy, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickWalkInCTA(bool isArabic, bool isExpired) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => _navigateToWalkInBooking(context, isExpired),
        icon: const Icon(Iconsax.add_circle_copy, size: 18),
        label: Text(
          isArabic ? 'إضافة حجز يدوي' : 'Add Manual Booking',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isExpired ? VSPColors.surfaceAlt : VSPColors.accent,
          foregroundColor: isExpired ? VSPColors.textSecondary : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.md),
            side: isExpired ? const BorderSide(color: VSPColors.divider) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// 🎨 Component 1: Period Tabs (UX Spec: 14px, 12x20px padding, 10px spacing, single row)
  Widget _buildTimeFilterBar(bool isArabic) {
    final filters = [
      {'key': 'today', 'labelAr': 'اليوم', 'labelEn': 'Today'},
      {'key': 'yesterday', 'labelAr': 'أمس', 'labelEn': 'Yesterday'},
      {'key': 'week', 'labelAr': 'هذا الأسبوع', 'labelEn': 'This Week'},
      {'key': 'month', 'labelAr': 'هذا الشهر', 'labelEn': 'This Month'},
      {'key': 'all', 'labelAr': 'الكل', 'labelEn': 'All-time'},
    ];

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((f) {
          final isSelected = _selectedTimePeriod == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTimePeriod = f['key'] as String),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFC8FF00)
                      : const Color(0xFF27272A).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  isArabic ? f['labelAr'] as String : f['labelEn'] as String,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF09090B)
                        : const Color(0xFFA1A1AA),
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  /// 🧮 1️⃣ + 2️⃣ المحرك المالي والكارت الرئيسي (Financial Engine + Hero Revenue Card)
  Widget _buildStatsGrid(bool isArabic) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isProOwner = auth.userModel?.isProPlan == true;
    final bookingProvider = Provider.of<BookingProvider>(context);
    final allBookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();

    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final List<Booking> bookings = allBookings.where((b) {
      final bStartLocal = b.startTime.toLocal();
      if (_selectedTimePeriod == 'today') {
        return bStartLocal.year == now.year && bStartLocal.month == now.month && bStartLocal.day == now.day;
      } else if (_selectedTimePeriod == 'yesterday') {
        return bStartLocal.year == yesterday.year && bStartLocal.month == yesterday.month && bStartLocal.day == yesterday.day;
      } else if (_selectedTimePeriod == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return bStartLocal.isAfter(startOfWeek.subtract(const Duration(days: 1))) && bStartLocal.isBefore(endOfWeek);
      } else if (_selectedTimePeriod == 'month') {
        return bStartLocal.year == now.year && bStartLocal.month == now.month;
      }
      return true; // 'all'
    }).toList();

    double pitchCashRevenue = 0.0;
    double digitalVspBalance = 0.0;
    double collectedRevenue = 0.0;
    double pendingReceivables = 0.0;
    double totalPipeline = 0.0;
    double totalHours = 0.0;
    final int activeBookingsCount = bookings.length;

    for (var b in bookings) {
      final double totalPrice = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      final bool isEnded = now.isAfter(b.endTime) || b.status == BookingStatus.completed;
      final bool isPaidInFull = b.isPaid || b.paymentStatus == 'paid' || (totalPrice > 0 && b.depositPaid >= totalPrice) || isEnded;

      final double paidAmount = isPaidInFull 
          ? totalPrice 
          : (b.depositPaid > 0 ? b.depositPaid : 0.0);
      
      final double remainingAmount = (totalPrice - paidAmount).clamp(0.0, 999999.0);

      collectedRevenue += paidAmount;
      pendingReceivables += remainingAmount;
      totalPipeline += totalPrice;

      final bool isManual = (b.paymentMethod == 'cash' || (b.paymentTransactionId?.startsWith('MANUAL') == true));
      final bool isOnlinePayment = !isManual && (
        b.paymentMethod == 'online' || 
        b.paymentMethod == 'paymob' || 
        b.paymentMethod == 'vodafone_cash' || 
        b.paymentMethod == 'instapay' || 
        (b.paymentTransactionId?.startsWith('PAYMOB') == true)
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

    // 🏆 دمج إيرادات اشتراكات البطولات الأونلاين الحية
    digitalVspBalance += _championshipDigitalRevenue;
    collectedRevenue += _championshipDigitalRevenue;
    totalPipeline += _championshipDigitalRevenue;

    final String currencySymbol = isArabic ? 'ج.م' : 'EGP';

    // Format human-friendly operating hours (e.g. 30 mins / 1.5 hrs)
    String formattedHoursStr;
    if (totalHours == 0) {
      formattedHoursStr = isArabic ? '0 دقيقة' : '0 mins';
    } else if (totalHours < 1.0) {
      final mins = (totalHours * 60).toInt();
      formattedHoursStr = isArabic ? '$mins دقيقة' : '$mins mins';
    } else if (totalHours == 1.0) {
      formattedHoursStr = isArabic ? 'ساعة واحدة' : '1 hr';
    } else {
      final hoursStr = (totalHours % 1 == 0) ? totalHours.toInt().toString() : totalHours.toStringAsFixed(1);
      formattedHoursStr = '$hoursStr ${isArabic ? "ساعة" : "hrs"}';
    }

    final String periodLabel = _selectedTimePeriod == 'today'
        ? (isArabic ? 'إجمالي إيرادات اليوم' : "Today's Total Revenue")
        : (_selectedTimePeriod == 'yesterday'
            ? (isArabic ? 'إجمالي إيرادات أمس' : "Yesterday's Revenue")
            : (_selectedTimePeriod == 'week'
                ? (isArabic ? 'إجمالي إيرادات الأسبوع' : 'Weekly Revenue')
                : (_selectedTimePeriod == 'month'
                    ? (isArabic ? 'إجمالي إيرادات الشهر' : 'Monthly Revenue')
                    : (isArabic ? 'إجمالي الإيرادات الكلي' : 'All-time Revenue'))));

    // 🛡️ باقة الـ 500 ج.م والفترة التجريبية (الكارت الداكن الفاخر والمتقن 100%)
    if (!isProOwner) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          border: Border.all(
            color: VSPColors.accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    periodLabel,
                    style: const TextStyle(
                      color: VSPColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showProUpgradeSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.lock_copy, color: Colors.amber, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? 'المحرك المالي 1000ج' : 'Pro Engine 1000 EGP',
                          style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${totalPipeline.toInt()}',
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  currencySymbol,
                  style: const TextStyle(
                    color: VSPColors.accent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: VSPColors.divider, height: 1),
            const SizedBox(height: 14),

            // 🔒 تلميح قفل تحليل الحجوزات والساعات للباقة المحترفة 1000ج
            InkWell(
              onTap: () => _showProUpgradeSheet(context),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.lock_copy, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isArabic
                          ? 'إحصائيات الحجوزات وساعات التشغيل متاحة في باقة 1000ج'
                          : 'Bookings & Hours analytics available in 1000 EGP Pro Plan',
                      style: const TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(
          color: VSPColors.accent.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان + شارة "محدّث الآن"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  periodLabel,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'محدّث الآن' : 'Updated now',
                      style: TextStyle(color: VSPColors.accent.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // الرقم المالي الرئيسي المباشر
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey('counter_$_selectedTimePeriod'),
                tween: Tween(begin: 0.0, end: collectedRevenue),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => Text(
                  '${val.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFFC8FF00),
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                currencySymbol,
                style: const TextStyle(
                  color: Color(0xFFC8FF00),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: VSPColors.divider, height: 1),
          const SizedBox(height: 16),

          // 📊 1. الصف الأول: القيمة الإجمالية + معلق
          Row(
            children: [
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'القيمة الإجمالية' : 'Total Value',
                  value: '${totalPipeline.toInt()} $currencySymbol',
                  valueColor: Colors.white,
                  tooltipText: isArabic
                      ? 'إجمالي القيمة المالية الكاملة لجميع الحجوزات (المدفوعة والمستحقة كاش) في الفترة المحددة، وتمثل القيمة الكاملة لنشاط الملعب.'
                      : 'The total gross financial value of all bookings (both paid online and cash due) for the selected period.',
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'معلق' : 'Pending',
                  value: '${pendingReceivables.toInt()} $currencySymbol',
                  valueColor: const Color(0xFFFFB800),
                  tooltipText: isArabic
                      ? 'المبالغ المتبقية من الحجوزات القادمة التي لم يتم تحصيلها بالكامل بعد، وتستحق الدفع كاش من اللاعبين عند حضورهم للملعب.'
                      : 'Remaining amounts for upcoming bookings not yet paid in full. These will be collected in cash upon player arrival.',
                  isArabic: isArabic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 💵 2. الصف الثاني: دفع مباشر + محفظة رقمية
          Row(
            children: [
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'دفع مباشر' : 'Direct Cash',
                  value: '${pitchCashRevenue.toInt()} $currencySymbol',
                  valueColor: const Color(0xFFC8FF00),
                  tooltipText: isArabic
                      ? 'المبالغ النقدية التي تم تحصيلها يدوياً وكاش مباشرة من اللاعبين في الملعب مقابل الحجوزات.'
                      : 'Total cash payments collected directly by hand from players at your sports facility.',
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'رقمي' : 'Digital',
                  value: '${digitalVspBalance.toInt()} $currencySymbol',
                  valueColor: const Color(0xFF38BDF8),
                  borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  tooltipText: isArabic
                      ? 'الأرباح المسددة أونلاين عبر التطبيق (بطاقات/محافظ)، والمحفوظة في رصيدك الرقمي بـ VSP؛ يمكنك طلب سحبها فوراً لحسابك البنكي أو إنستا باي.'
                      : 'Online earnings paid by players via the app. Stored safely in your VSP balance and withdrawable to your bank or InstaPay.',
                  isArabic: isArabic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ⏱️ 3. الصف الثالث: عدد الحجوزات + ساعات التشغيل
          Row(
            children: [
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'عدد الحجوزات' : 'Bookings',
                  value: '$activeBookingsCount',
                  valueColor: Colors.white,
                  tooltipText: isArabic
                      ? 'إجمالي عدد المباريات والحجوزات المؤكدة والنشطة التي تم تسجيلها للملعب خلال هذه الفترة.'
                      : 'Total count of confirmed and active match bookings recorded for your pitch during this period.',
                  isArabic: isArabic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildGridStatCard(
                  title: isArabic ? 'ساعات التشغيل' : 'Operating Hours',
                  value: formattedHoursStr,
                  valueColor: const Color(0xFFA3E635),
                  tooltipText: isArabic
                      ? 'مجموع الساعات والدقائق الفعلية التي تم فيها شغل الملعب وإقامة المباريات خلال هذه الفترة.'
                      : 'Total duration of active matches played and field utilization time during this period.',
                  isArabic: isArabic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🏦 4. زر تحويل/سحب الأرباح التفاعلي المباشر (خلفية رمادية أخف وأستروك رمادي متناسق)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showSettlementModal(context, digitalVspBalance, currencySymbol, isArabic),
              icon: Icon(
                digitalVspBalance > 0 ? Iconsax.wallet_add_copy : Iconsax.empty_wallet_change_copy,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                digitalVspBalance > 0
                    ? (isArabic
                        ? 'طلب سحب الأرباح (${digitalVspBalance.toInt()} $currencySymbol)'
                        : 'Withdraw Earnings (${digitalVspBalance.toInt()} $currencySymbol)')
                    : (isArabic
                        ? 'سحب الأرباح (الرصيد المتاح: 0 $currencySymbol)'
                        : 'Withdraw Profits (Available: 0 $currencySymbol)'),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27272A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  side: const BorderSide(
                    color: Color(0xFF3F3F46),
                    width: 1.0,
                  ),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🗂️ كارت إحصائي متقن بسلسل هيراركي ألوان واضح وواجهة عالية الجودة
  Widget _buildGridStatCard({
    required String title,
    required String value,
    required Color valueColor,
    required String tooltipText,
    required bool isArabic,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: () => _showTermHelpModal(
        context,
        title,
        tooltipText,
        isArabic,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? const Color(0xFF27272A),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFA1A1AA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Iconsax.info_circle_copy,
                  color: Color(0xFFA1A1AA),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 💡 كروت اللمحات الذكية جنب بعض (Side-by-Side Row Layout)
  Widget _buildInsightBadges(bool isProOwner, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'لمحات ذكية وأدوات تسويق' : 'Smart Marketing Insights',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildCompactInsightCard(
                title: isArabic ? 'أوقات الذروة' : 'Peak Hours',
                subtitle: isArabic ? 'أكثر الساعات طلباً' : 'Most requested slots',
                icon: Iconsax.clock_copy,
                iconColor: VSPColors.accent,
                isPro: isProOwner,
                onTap: () {
                  if (isProOwner) {
                    _showPeakHoursAnalyticsModal(context, isArabic);
                  } else {
                    _showProUpgradeSheet(context);
                  }
                },
                isArabic: isArabic,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildCompactInsightCard(
                title: isArabic ? 'مصادر الحجوزات' : 'Booking Sources',
                subtitle: isArabic ? 'المباشر والتحديات' : 'Direct vs Challenges',
                icon: Iconsax.chart_1_copy,
                iconColor: Colors.blueAccent,
                isPro: isProOwner,
                onTap: () {
                  if (isProOwner) {
                    _showBookingSourcesReportModal(context, isArabic);
                  } else {
                    _showProUpgradeSheet(context);
                  }
                },
                isArabic: isArabic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactInsightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isPro,
    required VoidCallback onTap,
    required bool isArabic,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (!isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Icon(
                    isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_3_copy,
                    color: VSPColors.textSecondary,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }



  void _showTermHelpModal(BuildContext context, String term, String description, bool isArabic) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
            border: Border(top: BorderSide(color: VSPColors.accent, width: 2.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      term,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: VSPColors.divider, height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VSPColors.background,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                  border: Border.all(color: VSPColors.divider),
                ),
                child: Text(
                  description,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                    elevation: 0,
                  ),
                  child: Text(
                    isArabic ? 'فهمت ذلك 👍' : 'Got it 👍',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettlementModal(BuildContext context, double amount, String currency, bool isArabic) {
    final TextEditingController accountController = TextEditingController();
    String selectedMethod = 'InstaPay';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                VSPSpacing.lg,
                VSPSpacing.lg,
                VSPSpacing.lg,
                MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg,
              ),
              decoration: const BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
                border: Border(top: BorderSide(color: Color(0xFFC8FF00), width: 2.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Iconsax.money_change_copy, color: Color(0xFFC8FF00), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'طلب تسوية رقمية من VSP' : 'VSP Settlement Request',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: VSPColors.divider),
                  const SizedBox(height: 12),

                  // Amount card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isArabic ? 'المبلغ المستحق للتسوية من VSP' : 'Available Digital Settlement Balance',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${amount.toInt()} $currency',
                          style: const TextStyle(color: Color(0xFFC8FF00), fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'اختر طريقة استلام الأموال:' : 'Select Payout Channel:',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedMethod = 'InstaPay'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'InstaPay' ? const Color(0xFF27272A) : const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(
                                color: selectedMethod == 'InstaPay' ? const Color(0xFFC8FF00) : const Color(0xFF27272A),
                                width: selectedMethod == 'InstaPay' ? 1.5 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'InstaPay',
                                style: TextStyle(
                                  color: selectedMethod == 'InstaPay' ? const Color(0xFFC8FF00) : const Color(0xFFA1A1AA),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedMethod = 'Vodafone Cash'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'Vodafone Cash' ? const Color(0xFF27272A) : const Color(0xFF18181B),
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                              border: Border.all(
                                color: selectedMethod == 'Vodafone Cash' ? const Color(0xFFC8FF00) : const Color(0xFF27272A),
                                width: selectedMethod == 'Vodafone Cash' ? 1.5 : 1.0,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Vodafone Cash',
                                style: TextStyle(
                                  color: selectedMethod == 'Vodafone Cash' ? const Color(0xFFC8FF00) : const Color(0xFFA1A1AA),
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

                  const SizedBox(height: 16),
                  Text(
                    selectedMethod == 'InstaPay'
                        ? (isArabic ? 'عنوان InstaPay IPA أو رقم الهاتف:' : 'InstaPay IPA / Phone Number:')
                        : (isArabic ? 'رقم محفظة فودافون كاش:' : 'Vodafone Cash Wallet Number:'),
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: accountController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: selectedMethod == 'InstaPay' ? 'name@instapay' : '010XXXXXXXX',
                      hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: VSPColors.surfaceAlt,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () {
                        final acc = accountController.text.trim();
                        if (acc.isEmpty) {
                          VSPFeedback.showError(
                            context,
                            isArabic ? 'يرجى كتابة تفاصيل حساب الاستلام' : 'Please enter your account details',
                          );
                          return;
                        }

                        if (amount <= 0) {
                          VSPFeedback.showError(
                            context,
                            isArabic ? 'لا توجد مستحقات رقمية متاحة للتسوية حالياً' : 'No available digital balance to settle',
                          );
                          return;
                        }

                        // 🛡️ USER CONTROL & FREEDOM: Confirmation Dialog before submitting settlement request
                        showDialog(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: VSPColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
                            title: Text(
                              isArabic ? 'تأكيد طلب التسوية' : 'Confirm Settlement',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            content: Text(
                              isArabic
                                  ? 'هل أنت متأكد من طلب تسوية بمبلغ ${amount.toInt()} $currency وتحويله إلى حسابك $selectedMethod ($acc)؟'
                                  : 'Are you sure you want to request payout of ${amount.toInt()} $currency to your $selectedMethod ($acc)?',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: Text(isArabic ? 'مراجعة وتعديل' : 'Review & Edit', style: const TextStyle(color: VSPColors.textSecondary)),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(dialogCtx);
                                  setModalState(() => isSubmitting = true);

                                  try {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    final owner = auth.userModel;

                                    await NotificationRepository().sendNotification(
                                      'vsp_admin',
                                      AppNotification(
                                        id: '',
                                        title: 'طلب تسوية مالية جديد من مالك ملعب',
                                        body: 'المالك ${owner?.name ?? "مالك ملعب"} يطلب تسوية بمبلغ ${amount.toInt()} $currency عبر $selectedMethod ($acc).',
                                        type: 'info',
                                        createdAt: DateTime.now(),
                                      ),
                                    );

                                    if (!context.mounted) return;
                                    Navigator.pop(ctx);
                                    VSPFeedback.showSuccess(
                                      context,
                                      isArabic
                                          ? 'تم إرسال طلب التسوية بنجاح إلى إدارة VSP! سيتم مراجعة الطلب وتحويل المبلغ خلال ساعات.'
                                          : 'Settlement request submitted successfully to VSP Admin!',
                                    );
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (!context.mounted) return;
                                    VSPFeedback.showError(
                                      context,
                                      isArabic ? 'حدث خطأ أثناء إرسال الطلب، يرجى المحاولة لاحقاً.' : 'Failed to send request.',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC8FF00),
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  isArabic ? 'تأكيد وإرسال' : 'Confirm & Send',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8FF00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(
                              isArabic ? 'تأكيد وإرسال طلب التسوية' : 'Confirm Settlement Request',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPeakHoursAnalyticsModal(BuildContext context, bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final bookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();

    int s1Count = 0; // 06:00 ص - 12:00 ظ (06:00 - 12:00)
    int s2Count = 0; // 12:00 ظ - 06:00 م (12:00 - 18:00) -> 2:00 PM lands HERE
    int s3Count = 0; // 06:00 م - 12:00 ص (18:00 - 24:00)
    int s4Count = 0; // 12:00 ص - 06:00 ص (00:00 - 06:00)

    final Map<int, int> dayCounts = {};

    for (var b in bookings) {
      final hour = b.startTime.hour;
      final day = b.startTime.weekday;
      dayCounts[day] = (dayCounts[day] ?? 0) + 1;

      if (hour >= 6 && hour < 12) {
        s1Count++;
      } else if (hour >= 12 && hour < 18) {
        s2Count++;
      } else if (hour >= 18 && hour < 24) {
        s3Count++;
      } else {
        s4Count++;
      }
    }

    final int totalSlotBookings = bookings.length;

    final String slot1Label = isArabic ? '06:00 ص - 12:00 ظ' : '06:00 AM - 12:00 PM';
    final String slot2Label = isArabic ? '12:00 ظ - 06:00 م' : '12:00 PM - 06:00 PM';
    final String slot3Label = isArabic ? '06:00 م - 12:00 ص' : '06:00 PM - 12:00 AM';
    final String slot4Label = isArabic ? '12:00 ص - 06:00 ص' : '12:00 AM - 06:00 AM';

    // Pure DB calculation for Peak Slot
    String peakHourStr;
    if (totalSlotBookings > 0) {
      if (s2Count >= s1Count && s2Count >= s3Count && s2Count >= s4Count) {
        peakHourStr = slot2Label;
      } else if (s3Count >= s1Count && s3Count >= s4Count) {
        peakHourStr = slot3Label;
      } else if (s1Count >= s4Count) {
        peakHourStr = slot1Label;
      } else {
        peakHourStr = slot4Label;
      }
    } else {
      peakHourStr = isArabic ? 'غير محدد بعد' : 'Not determined yet';
    }

    int peakDay = 5;
    int maxDayCount = 0;
    dayCounts.forEach((d, count) {
      if (count > maxDayCount) {
        maxDayCount = count;
        peakDay = d;
      }
    });

    final List<String> dayNamesAr = ['', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final List<String> dayNamesEn = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final String peakDayStr = totalSlotBookings > 0 ? (isArabic ? dayNamesAr[peakDay] : dayNamesEn[peakDay]) : (isArabic ? 'غير محدد' : 'N/A');

    // 100% Pure Database Percentages
    final double s1Pct = totalSlotBookings > 0 ? (s1Count / totalSlotBookings) : 0.0;
    final double s2Pct = totalSlotBookings > 0 ? (s2Count / totalSlotBookings) : 0.0;
    final double s3Pct = totalSlotBookings > 0 ? (s3Count / totalSlotBookings) : 0.0;
    final double s4Pct = totalSlotBookings > 0 ? (s4Count / totalSlotBookings) : 0.0;

    final double maxPct = [s1Pct, s2Pct, s3Pct, s4Pct].reduce((a, b) => a > b ? a : b);

    final String l1 = '$slot1Label${s1Pct == maxPct && totalSlotBookings > 0 && s1Pct > 0 ? (isArabic ? ' (الذروة)' : ' (Peak)') : ''}';
    final String l2 = '$slot2Label${s2Pct == maxPct && totalSlotBookings > 0 && s2Pct > 0 ? (isArabic ? ' (الذروة)' : ' (Peak)') : ''}';
    final String l3 = '$slot3Label${s3Pct == maxPct && totalSlotBookings > 0 && s3Pct > 0 ? (isArabic ? ' (الذروة)' : ' (Peak)') : ''}';
    final String l4 = '$slot4Label${s4Pct == maxPct && totalSlotBookings > 0 && s4Pct > 0 ? (isArabic ? ' (الذروة)' : ' (Peak)') : ''}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
            border: Border(top: BorderSide(color: VSPColors.accent, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'تحليل أوقات الذروة' : 'Peak Hours Analytics',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: VSPColors.divider),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'ساعة الذروة الأولى' : 'Top Peak Hour',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            peakHourStr,
                            style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'اليوم الأكثر طلباً' : 'Top Booked Day',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            peakDayStr,
                            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Text(
                isArabic ? 'كثافة الطلب خلال ساعات تشغيل الملعب:' : 'Demand Intensity during Stadium Hours:',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),

              _buildDemandProgressRow(l1, s1Pct, s1Pct > 0 && s1Pct == maxPct ? Colors.amber : VSPColors.accent),
              const SizedBox(height: 8),
              _buildDemandProgressRow(l2, s2Pct, s2Pct > 0 && s2Pct == maxPct ? Colors.amber : VSPColors.accent),
              const SizedBox(height: 8),
              _buildDemandProgressRow(l3, s3Pct, s3Pct > 0 && s3Pct == maxPct ? Colors.amber : VSPColors.accent),
              const SizedBox(height: 8),
              _buildDemandProgressRow(l4, s4Pct, s4Pct > 0 && s4Pct == maxPct ? Colors.amber : Colors.blueAccent),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingSourcesReportModal(BuildContext context, bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final bookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();

    int manualCount = 0;
    int directCount = 0;
    int challengeCount = 0;

    double manualRev = 0;
    double directRev = 0;
    double challengeRev = 0;

    for (var b in bookings) {
      final double price = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      final bool isManual = b.paymentTransactionId?.startsWith('MANUAL') == true || b.playerPhone != null;
      if (b.bookingType == BookingType.challenge || b.bookingType == BookingType.team) {
        challengeCount++;
        challengeRev += price;
      } else if (isManual) {
        manualCount++;
        manualRev += price;
      } else {
        directCount++;
        directRev += price;
      }
    }

    final double totalRevenue = (manualRev + directRev + challengeRev);
    final int totalCount = (manualCount + directCount + challengeCount);

    final double manualPct = totalRevenue > 0
        ? (manualRev / totalRevenue)
        : (totalCount > 0 ? (manualCount / totalCount) : 0.0);
    final double directPct = totalRevenue > 0
        ? (directRev / totalRevenue)
        : (totalCount > 0 ? (directCount / totalCount) : 0.0);
    final double challengePct = totalRevenue > 0
        ? (challengeRev / totalRevenue)
        : (totalCount > 0 ? (challengeCount / totalCount) : 0.0);

    final int manualPctInt = (manualPct * 100).round();
    final int directPctInt = (directPct * 100).round();
    final int challengePctInt = (challengePct * 100).round();

    // 💡 Dynamic Insight Analysis (Mathematically verified breakdown)
    final String dynamicInsightText;
    final IconData dynamicInsightIcon;
    if (manualRev > 0 && directRev > 0 && challengeRev > 0) {
      dynamicInsightIcon = Iconsax.chart_21_copy;
      dynamicInsightText = isArabic
          ? 'توزع الأرباح: الكاش اليدوي $manualPctInt%، التطبيق $directPctInt%، والتحديات $challengePctInt%.'
          : 'Revenue breakdown: Cash $manualPctInt%, App $directPctInt%, Challenges $challengePctInt%.';
    } else if (manualRev > 0 && directRev > 0) {
      dynamicInsightIcon = Iconsax.chart_1_copy;
      dynamicInsightText = isArabic
          ? 'الحجوزات اليدوية/الكاش تشكل $manualPctInt% وتطبيقات اللاعبين تشكل $directPctInt% من إجمالي أرباح ملعبك.'
          : 'Manual cash walk-ins represent $manualPctInt% and direct app bookings represent $directPctInt% of your total revenue.';
    } else if (manualRev > 0 && challengeRev > 0) {
      dynamicInsightIcon = Iconsax.cup_copy;
      dynamicInsightText = isArabic
          ? 'الحجوزات اليدوية تشكل $manualPctInt% وتحديات الفرق تشكل $challengePctInt% من أرباحك.'
          : 'Manual bookings form $manualPctInt% and team challenges form $challengePctInt% of revenue.';
    } else if (directRev > 0 && challengeRev > 0) {
      dynamicInsightIcon = Iconsax.mobile_copy;
      dynamicInsightText = isArabic
          ? 'الحجوزات المباشرة تشكل $directPctInt% والتحديات تشكل $challengePctInt% من أرباحك الأونلاين.'
          : 'Direct app bookings account for $directPctInt% and challenges account for $challengePctInt% of revenue.';
    } else if (manualRev > 0) {
      dynamicInsightIcon = Iconsax.flash_1_copy;
      dynamicInsightText = isArabic
          ? 'الحجوزات اليدوية / الكاش تشكل 100% من أرباحك حالياً. ننصح بتفعيل استقبال الحجوزات الأونلاين والتحديات لجذب عملاء وجدد!'
          : 'Cash walk-ins account for 100% of revenue. Consider enabling online player bookings to attract new teams!';
    } else if (directRev > 0) {
      dynamicInsightIcon = Iconsax.mobile_copy;
      dynamicInsightText = isArabic
          ? 'حجوزات اللاعبين الأونلاين عبر التطبيق تشكل 100% من إيرادات ملعبك!'
          : 'Direct online app bookings represent 100% of your pitch revenue!';
    } else if (challengeRev > 0) {
      dynamicInsightIcon = Iconsax.cup_copy;
      dynamicInsightText = isArabic
          ? 'مباريات وتحديات الفرق تشكل 100% من أرباح ملعبك حالياً!'
          : 'Team challenges drive 100% of your pitch revenue currently!';
    } else {
      dynamicInsightIcon = Iconsax.flash_1_copy;
      dynamicInsightText = isArabic
          ? 'لم تستقبل أي حجوزات بعد. يمكنك إضافة حجزك اليدوي الأول الآن أو تفعيل ملعبك لاستقبال حجوزات اللاعبين!'
          : 'No bookings received yet. Add your first manual booking or open online player slots!';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(VSPSpacing.lg),
          decoration: const BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
            border: Border(top: BorderSide(color: Colors.blueAccent, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.chart_1_copy, color: Colors.blueAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'تقرير مصادر الحجوزات' : 'Booking Sources Report',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: VSPColors.divider),
              const SizedBox(height: 12),

              _buildSourceProgressRow(
                label: isArabic ? 'حجوزات يدوية / كاش' : 'Manual / Cash Walk-ins',
                pct: manualPct,
                count: manualCount,
                revenue: manualRev,
                color: VSPColors.accent,
                isArabic: isArabic,
              ),
              const SizedBox(height: 12),
              _buildSourceProgressRow(
                label: isArabic ? 'حجوزات اللاعبين المباشرة' : 'Direct Player App Bookings',
                pct: directPct,
                count: directCount,
                revenue: directRev,
                color: Colors.blueAccent,
                isArabic: isArabic,
              ),
              const SizedBox(height: 12),
              _buildSourceProgressRow(
                label: isArabic ? 'مباريات وتحديات الفرق' : 'Team Challenges & Matches',
                pct: challengePct,
                count: challengeCount,
                revenue: challengeRev,
                color: Colors.amber,
                isArabic: isArabic,
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(dynamicInsightIcon, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dynamicInsightText,
                        style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemandProgressRow(String title, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5)),
            Text('${(pct * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: VSPColors.surfaceAlt,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceProgressRow({
    required String label,
    required double pct,
    required int count,
    required double revenue,
    required Color color,
    required bool isArabic,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(
                '${revenue.toInt()} ${isArabic ? "ج.م" : "EGP"} ($count ${isArabic ? "حجز" : "bookings"})',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: VSPColors.background,
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildBookedTodayList(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    final allBookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();

    final now = DateTime.now();
    final List<Booking> bookings = allBookings.where((b) {
      if (_selectedTimePeriod == 'today') {
        return b.startTime.year == now.year && b.startTime.month == now.month && b.startTime.day == now.day;
      } else if (_selectedTimePeriod == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return b.startTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) && b.startTime.isBefore(endOfWeek);
      } else if (_selectedTimePeriod == 'month') {
        return b.startTime.year == now.year && b.startTime.month == now.month;
      }
      return true; // 'all'
    }).toList();

    final String currencySymbol = isArabic ? 'ج.م' : 'EGP';

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
        child: Center(
          child: Text(
            isArabic ? 'لا توجد حجوزات مسجلة في هذا النطاق الزمني' : 'No bookings in this time period', 
            style: const TextStyle(color: VSPColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: bookings.take(5).map((b) {
        final String paymentStatus = b.paymentStatus;
        final double depositPaid = b.depositPaid;
        final double rawPrice = b.totalPrice;
        final double totalPrice = rawPrice > 0 ? rawPrice : (depositPaid > 0 ? depositPaid : 0.0);
        final bool isEnded = now.isAfter(b.endTime) || b.status == BookingStatus.completed;
        final bool isPaidInFull = b.isPaid || paymentStatus == 'paid' || (totalPrice > 0 && depositPaid >= totalPrice) || isEnded;
        final bool isPartiallyPaid = !isPaidInFull && (paymentStatus == 'partially_paid' || b.isDepositPaid || depositPaid > 0);

        final double remaining = (totalPrice - depositPaid).clamp(0.0, 999999.0);
        final String badgeLabel;
        final Color badgeColor;
        if (isPaidInFull) {
          badgeLabel = isArabic ? 'مدفوع بالكامل' : 'Paid in Full';
          badgeColor = VSPColors.success;
        } else if (isPartiallyPaid || (depositPaid > 0 && remaining > 0)) {
          badgeLabel = isArabic 
              ? 'عربون (متبقي ${remaining.toInt()} ج.م)' 
              : 'Deposit (Rest ${remaining.toInt()} EGP)';
          badgeColor = Colors.amber;
        } else {
          badgeLabel = isArabic ? 'غير مدفوع' : 'Unpaid';
          badgeColor = Colors.redAccent;
        }

        Stadium? selectedStadium;
        try {
          selectedStadium = stadiumProvider.stadiums.firstWhere((s) => s.id == b.stadiumId);
        } catch (_) {
          selectedStadium = null;
        }

        String displayName = b.playerTeamName?.trim() ?? '';
        if (displayName.isEmpty) {
          displayName = isArabic ? 'حجز يدوي' : 'Manual Booking';
        } else if (RegExp(r'^\d+$').hasMatch(displayName)) {
          displayName = isArabic ? 'لاعب #$displayName' : 'Player #$displayName';
        }

        String pitchName = b.stadiumName.trim();
        if (pitchName.isEmpty || pitchName == 'Mo') {
          if (selectedStadium != null && selectedStadium.name.trim().isNotEmpty && selectedStadium.name.trim() != 'Mo') {
            pitchName = selectedStadium.name.trim();
          } else {
            pitchName = isArabic ? 'الملعب الرئيسي' : 'Main Pitch';
          }
        }

        final slot = {
          'time': DateFormat('hh:mm a').format(b.startTime),
          'hour': b.startTime.hour,
          'minute': b.startTime.minute,
          'isBooked': true,
          'name': displayName,
          'booking': b,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (selectedStadium != null) {
                  showOwnerBookingModal(
                    context: context,
                    isEdit: true,
                    slot: slot,
                    selectedStadium: selectedStadium,
                    parentContext: context,
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                }
              },
              borderRadius: BorderRadius.circular(VSPRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.divider, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$pitchName • ${DateFormat('hh:mm a').format(b.startTime)}',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${totalPrice.toInt()} $currencySymbol',
                          style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}



