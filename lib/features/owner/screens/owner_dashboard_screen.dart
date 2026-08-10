import 'dart:ui';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        final uid = auth.firebaseUser!.uid;
        final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
        stadiumProvider.listenToOwnerStadiums(uid);
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        final stadiums = stadiumProvider.stadiums.where((s) => s.ownerId == uid).map((s) => s.id).toList();
        final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
        bookingProvider.loadOwnerBookings(uid, stadiumIds: stadiums.isNotEmpty ? stadiums : null);
      }
    });
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

              // 🔹 أ. شريط النطاق الزمني (Time-Filter Bar)
              _buildTimeFilterBar(isArabic),
              const SizedBox(height: VSPSpacing.sm),

              // 🧮 3. المحرك المالي والكارت الرئيسي 10/10 (Hero Revenue Card)
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
  /// 1. الهيدر الموحد لغوياً
  Widget _buildHeader(AuthProvider auth, bool isArabic) {
    final firstName = (auth.userModel?.name ?? 'Owner').split(' ').first;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'أهلاً $firstName' : 'Hi $firstName', 
              style: Theme.of(context).textTheme.displayMedium,
            ),
            Text(
              isArabic ? 'لوحة تحكم الملعب' : 'Facility Dashboard', 
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(LucideIcons.bell, color: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsCenterScreen())),
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
          const Icon(LucideIcons.shieldAlert, color: Colors.redAccent, size: 18),
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
          const Icon(LucideIcons.clock, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic ? "حسابك قيد المراجعة - الحجوزات ستفعل فور توثيق أوراقك." : "Under review - Bookings will activate once verified.",
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _isPendingBannerDismissed = true),
            child: const Icon(LucideIcons.x, color: Colors.orange, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlanBanner(dynamic userModel, bool isArabic, bool isExpired) {
    final bool isPro = userModel.isProPlan;
    final bool isTrial = userModel.isInActiveTrial;
    final DateTime? trialEnd = userModel.effectiveTrialEndsAt;
    final int remainingDays = trialEnd != null ? trialEnd.difference(DateTime.now()).inDays : 0;
    final String trialEndDateStr = trialEnd != null ? DateFormat('yyyy/MM/dd').format(trialEnd) : '';

    final String planLabel = isExpired
        ? (isArabic ? 'انتهت المدة - ادفع الآن' : 'Period Expired - Pay Now')
        : (isTrial
            ? (isArabic ? 'فترة تجريبية (متبقي $remainingDays يوم)' : 'Free Trial ($remainingDays days left)')
            : (isArabic 
                ? (isPro ? 'احترافية (Pro)' : 'أساسية (Basic)')
                : userModel.subscriptionPlanLabel));

    final String subtitleText = isExpired
        ? (isArabic ? 'انتهت الفترة التجريبية. يرجى الاشتراك لتفعيل الحجوزات.' : 'Free trial ended. Subscribe to resume bookings.')
        : (isTrial
            ? (isArabic ? 'ينتهي التجريبي في $trialEndDateStr | الملاعب: ${userModel.maxStadiums}' : 'Ends on $trialEndDateStr | Stadiums: ${userModel.maxStadiums}')
            : '${isArabic ? "الملاعب المسموحة:" : "Allowed Stadiums:"} ${userModel.maxStadiums}');

    final String buttonLabel = isExpired
        ? (isArabic ? 'ادفع الآن' : 'Pay Now')
        : (isArabic ? 'ترقية' : 'Upgrade');

    final Color statusColor = isPro
        ? Colors.amber
        : (!isExpired
            ? VSPColors.accent
            : Colors.redAccent);

    return InkWell(
      onTap: () => _showProUpgradeSheet(context),
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.15)
              : (isPro ? Colors.amber.withValues(alpha: 0.1) : VSPColors.surface),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isExpired ? Colors.redAccent : (isPro ? Colors.amber : VSPColors.accent),
            width: isExpired ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPro ? LucideIcons.crown : (isTrial ? LucideIcons.timer : (!isExpired ? LucideIcons.award : LucideIcons.shieldAlert)),
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
                  const Icon(LucideIcons.arrowUpRight, size: 14),
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
        icon: const Icon(LucideIcons.plusCircle, size: 18),
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

  /// 🔹 أ. شريط النطاق الزمني (Time-Filter Bar)
  Widget _buildTimeFilterBar(bool isArabic) {
    final filters = [
      {'key': 'today', 'labelAr': 'اليوم', 'labelEn': 'Today'},
      {'key': 'week', 'labelAr': 'هذا الأسبوع', 'labelEn': 'This Week'},
      {'key': 'month', 'labelAr': 'هذا الشهر', 'labelEn': 'This Month'},
      {'key': 'all', 'labelAr': 'الكل', 'labelEn': 'All'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedTimePeriod == f['key'];
          return Container(
            margin: const EdgeInsets.only(left: 6, right: 2),
            child: InkWell(
              onTap: () => setState(() => _selectedTimePeriod = f['key'] as String),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? VSPColors.accent : VSPColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? VSPColors.accent : VSPColors.divider,
                  ),
                ),
                child: Text(
                  isArabic ? f['labelAr'] as String : f['labelEn'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.black : VSPColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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

      final diffMinutes = b.endTime.difference(b.startTime).inMinutes;
      totalHours += (diffMinutes / 60.0);
    }

    final String formattedHours = (totalHours % 1 == 0) ? totalHours.toInt().toString() : totalHours.toStringAsFixed(1);
    final String currencySymbol = isArabic ? 'ج.م' : 'EGP';

    final String periodLabel = _selectedTimePeriod == 'today'
        ? (isArabic ? 'إجمالي إيرادات اليوم' : "Today's Total Revenue")
        : (_selectedTimePeriod == 'week'
            ? (isArabic ? 'إجمالي إيرادات الأسبوع' : 'Weekly Revenue')
            : (_selectedTimePeriod == 'month'
                ? (isArabic ? 'إجمالي إيرادات الشهر' : 'Monthly Revenue')
                : (isArabic ? 'إجمالي الإيرادات الكلي' : 'All-time Revenue')));

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
                        const Icon(LucideIcons.lock, color: Colors.amber, size: 12),
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
                  '${collectedRevenue.toInt()}',
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
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'إجمالي الحجوزات' : 'Total Bookings',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$activeBookingsCount ${isArabic ? "حجز" : "Bookings"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'ساعات التشغيل' : 'Hours Booked',
                          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$formattedHours ${isArabic ? "ساعة" : "Hours"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
          // الهيدر علوي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                periodLabel,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // الرقم الرئيسي الكبير (المُحصل فعلياً في جيب المالك)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${collectedRevenue.toInt()}',
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
          const SizedBox(height: 16),

          // الصف الأوسط: المستحقات المعلقة + إجمالي قيمة الحجوزات
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'المستحقات المعلقة' : 'Pending Receivables',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pendingReceivables.toInt()} $currencySymbol',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
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
                    color: VSPColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'إجمالي الحجوزات' : 'Total Pipeline',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalPipeline.toInt()} $currencySymbol',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // الصف السفلي: عدد الحجوزات + ساعات التشغيل
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, color: VSPColors.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${isArabic ? "الحجوزات:" : "Bookings:"} $activeBookingsCount',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: VSPColors.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(VSPRadius.sm),
                    border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, color: VSPColors.textSecondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${isArabic ? "التشغيل:" : "Hours:"} $formattedHours ${isArabic ? "ساعة" : "h"}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
                icon: LucideIcons.clock,
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
                icon: LucideIcons.barChart3,
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
                    isArabic ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
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
                      const Icon(LucideIcons.clock, color: VSPColors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'تحليل أوقات الذروة' : 'Peak Hours Analytics',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: VSPColors.textSecondary, size: 18),
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

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.lightbulb, color: VSPColors.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isArabic 
                                ? 'تحليل أوقات الذروة: فترة ($peakHourStr) تشهد الإقبال الأعلى بناءً على قائمة حجوزاتك الحالية.'
                                : 'Analytics Advice: Period ($peakHourStr) enjoys peak demand based on your actual bookings.',
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          VSPFeedback.showSuccess(
                            context,
                            isArabic ? 'تم فتح خاصية تعديل تسعير ساعات الذروة بنجاح!' : 'Dynamic peak pricing settings opened!',
                          );
                        },
                        icon: const Icon(LucideIcons.settings2, size: 16),
                        label: Text(
                          isArabic ? 'تعديل أسعار ساعات الذروة' : 'Adjust Peak Pricing',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VSPColors.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
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

    final totalCount = (manualCount + directCount + challengeCount);
    final double manualPct = totalCount > 0 ? (manualCount / totalCount) : 0.0;
    final double directPct = totalCount > 0 ? (directCount / totalCount) : 0.0;
    final double challengePct = totalCount > 0 ? (challengeCount / totalCount) : 0.0;

    // 💡 Dynamic Insight Analysis
    final String dynamicInsightText;
    final IconData dynamicInsightIcon;
    if (challengeCount >= directCount && challengeCount >= manualCount && challengeCount > 0) {
      dynamicInsightIcon = LucideIcons.trophy;
      dynamicInsightText = isArabic 
          ? 'مباريات وتحديات الفرق تشكل المصدر الأعلى دخلاً ونشاطاً لملعبك حالياً!'
          : 'Team challenges & match bookings drive your highest revenue!';
    } else if (directCount >= manualCount && directCount > 0) {
      dynamicInsightIcon = LucideIcons.smartphone;
      dynamicInsightText = isArabic
          ? 'حجوزات اللاعبين المباشرة عبر التطبيق هي المصدر الأساسي لأرباح ملعبك حالياً!'
          : 'Direct app player bookings drive the majority of your pitch revenue!';
    } else if (manualCount > 0) {
      dynamicInsightIcon = LucideIcons.lightbulb;
      dynamicInsightText = isArabic
          ? 'الحجوزات اليدوية / الكاش تشكل 100% من أرباحك حالياً. ننصح بتفعيل استقبال الحجوزات الأونلاين والتحديات لجذب عملاء وجدد لملعبك!'
          : 'Cash walk-ins account for 100% of revenue. Consider enabling online player bookings to attract new teams!';
    } else {
      dynamicInsightIcon = LucideIcons.lightbulb;
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
                      const Icon(LucideIcons.barChart3, color: Colors.blueAccent, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        isArabic ? 'تقرير مصادر الحجوزات' : 'Booking Sources Report',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: VSPColors.textSecondary, size: 18),
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

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VSPColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(dynamicInsightIcon, color: Colors.blueAccent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dynamicInsightText,
                            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          VSPFeedback.showSuccess(
                            context,
                            isArabic ? 'تم تفعيل استقبال الحجز الإلكتروني وتحديات الفرق بنجاح!' : 'Online player bookings and team challenges activated!',
                          );
                        },
                        icon: const Icon(LucideIcons.rocket, size: 16),
                        label: Text(
                          isArabic ? 'تفعيل الحجز الإلكتروني والتحديات' : 'Enable Online Player Bookings',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
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
