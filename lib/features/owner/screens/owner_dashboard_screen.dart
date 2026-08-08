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

import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  bool _isPendingBannerDismissed = false;

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
    if (isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.shieldAlert, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'الاشتراك منتهي. يرجى التجديد لتفعيل إضافة الحجوزات.'
                      : 'Subscription expired. Please renew to resume bookings.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
        ),
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
        child: SingleChildScrollView(
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

              // 📊 3. كارت الأرباح المالي الموحد (البطل البصري للشاشة)
              _buildStatsGrid(isArabic),
              const SizedBox(height: VSPSpacing.lg),

              // 💡 4. شارات اللمحات الذكية (كاملة العرض لمنع قص النصوص)
              _buildInsightBadges(isProOwner, isArabic),
              const SizedBox(height: VSPSpacing.xl),

              // 📋 5. حجوزات اليوم
              Text(
                isArabic ? 'حجوزات اليوم' : "Today's Bookings",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: VSPSpacing.md),
              _buildBookedTodayList(isArabic),
              const SizedBox(height: VSPSpacing.md),

              // ⚡ 6. زر الحجز السريع المباشر (موضوع أسفل حجوزات اليوم)
              _buildQuickWalkInCTA(isArabic, isExpired),
            ],
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
            ? (isArabic ? 'فترة تجريبية (متبقي $remainingDays يوم ⏳)' : 'Free Trial ($remainingDays days left ⏳)')
            : (isArabic 
                ? (isPro ? 'احترافية (Pro)' : 'أساسية (Basic)')
                : userModel.subscriptionPlanLabel));

    final String subtitleText = isExpired
        ? (isArabic ? 'انتهت الفترة التجريبية. يرجى الاشتراك لتفعيل الحجوزات.' : 'Free trial ended. Subscribe to resume bookings.')
        : (isTrial
            ? (isArabic ? '⏳ ينتهي التجريبي في $trialEndDateStr | الملاعب: ${userModel.maxStadiums}' : '⏳ Ends on $trialEndDateStr | Stadiums: ${userModel.maxStadiums}')
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

  /// 📊 كارت الأرباح الكبير المصلح والنظيف (Clean Hero Card)
  Widget _buildStatsGrid(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final bookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();

    double totalRev = 0;
    int totalHours = 0;
    int completedBookingsCount = 0;

    final now = DateTime.now();

    for (var b in bookings) {
      final bool isEnded = b.status == BookingStatus.completed || b.endTime.isBefore(now);
      if (isEnded) {
        totalRev += b.totalPrice;
        final diff = b.endTime.difference(b.startTime).inHours;
        totalHours += (diff == 0 ? 1 : diff); // الحد الأدنى ساعة
        completedBookingsCount++;
      } else if (b.depositPaid > 0) {
        totalRev += b.depositPaid;
      } else if (b.isPaid) {
        totalRev += b.totalPrice;
      }
    }

    final String currencySymbol = isArabic ? 'ج.م' : 'EGP';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VSPColors.accent, VSPColors.cardDarkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الهيدر + شارة 0% عمولة
          Text(
            isArabic ? 'إجمالي أرباح الملعب' : 'Total Pitch Revenue',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          
          // الرقم الرئيسي الكبير النظيف
          Text(
            '${totalRev.toInt()} $currencySymbol',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // الإحصائيات السريعة النظيفة (الحجوزات والساعات)
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendarCheck, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'الحجوزات' : 'Bookings',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        Text(
                          '$completedBookingsCount ${isArabic ? "حجز مكتمل" : "Completed"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 24, color: Colors.white24),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.clock, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'ساعات التشغيل' : 'Hours Booked',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        Text(
                          '$totalHours ${isArabic ? "ساعة" : "Hours"}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 💡 كروت اللمحات المصلحة بحجم عريض وبدون قص (_buildInsightBadges)
  Widget _buildInsightBadges(bool isProOwner, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'لمحات ذكية وأدوات تسويق' : 'Smart Marketing Insights',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        
        // كارت 1: أوقات الحجز (Full Width)
        _buildFullWidthInsightCard(
          title: isArabic ? 'تحليل أوقات الذروة والساعات' : 'Peak Hours & Slots Analytics',
          subtitle: isArabic ? 'معرفة أكثر الساعات والأيام طلباً لحجز ملعبك' : 'Discover the most requested hours and days',
          icon: LucideIcons.clock,
          iconColor: VSPColors.accent,
          isPro: isProOwner,
          onTap: () => _showProUpgradeSheet(context),
          isArabic: isArabic,
        ),
        
        const SizedBox(height: 10),

        // كارت 2: مصدر الحجز (Full Width)
        _buildFullWidthInsightCard(
          title: isArabic ? 'تقرير مصادر الحجوزات' : 'Booking Source Report',
          subtitle: isArabic ? 'نسبة الحجز المباشر مقابل مباريات التحدي بين الفرق' : 'Direct bookings ratio vs Team challenge matches',
          icon: LucideIcons.barChart3,
          iconColor: Colors.blueAccent,
          isPro: isProOwner,
          onTap: () => _showProUpgradeSheet(context),
          isArabic: isArabic,
        ),
      ],
    );
  }

  Widget _buildFullWidthInsightCard({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isPro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 0.5),
                          ),
                          child: const Text(
                            'PRO 👑',
                            style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(LucideIcons.chevronRight, color: VSPColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBookedTodayList(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final bookings = bookingProvider.userBookings.where((b) => b.status != BookingStatus.cancelled).toList();
    final String currencySymbol = isArabic ? 'ج.م' : 'EGP';

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
        child: Center(
          child: Text(
            isArabic ? 'لا توجد حجوزات مسجلة اليوم' : 'No bookings for today', 
            style: const TextStyle(color: VSPColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: bookings.take(3).map((b) {
        final bool isEnded = b.status == BookingStatus.completed || b.endTime.isBefore(DateTime.now());
        final String paymentStatus = b.paymentStatus;
        final double depositPaid = b.depositPaid;
        final double rawPrice = b.totalPrice;
        final double totalPrice = rawPrice > 0 ? rawPrice : (depositPaid > 0 ? depositPaid : 0.0);
        final bool isPaidInFull = b.isPaid || paymentStatus == 'paid' || (totalPrice > 0 && depositPaid >= totalPrice);
        final bool isPartiallyPaid = !isPaidInFull && (paymentStatus == 'partially_paid' || b.isDepositPaid || depositPaid > 0);

        final double remaining = totalPrice - depositPaid;
        final String badgeLabel;
        final Color badgeColor;
        if (isPaidInFull) {
          badgeLabel = isArabic ? 'تم الدفع' : 'Paid';
          badgeColor = VSPColors.success;
        } else if (isEnded) {
          badgeLabel = isArabic ? 'محصل' : 'Collected';
          badgeColor = VSPColors.success;
        } else if (isPartiallyPaid) {
          badgeLabel = isArabic 
              ? 'متبقي ${remaining.toStringAsFixed(0)} ج.م' 
              : 'Remaining ${remaining.toStringAsFixed(0)} EGP';
          badgeColor = Colors.amber;
        } else {
          badgeLabel = isArabic ? 'غير مدفوع' : 'Unpaid';
          badgeColor = VSPColors.warning;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
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
                      b.playerTeamName ?? (isArabic ? 'عميل' : 'Customer'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.stadiumName} • ${DateFormat('hh:mm a').format(b.startTime)}',
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
        );
      }).toList(),
    );
  }
}
