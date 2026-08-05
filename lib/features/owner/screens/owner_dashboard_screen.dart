import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
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
    final isExpired = userModel?.isPlanExpired == true;

    return Scaffold(
      backgroundColor: VSPColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(VSPSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(auth, isArabic),
              const SizedBox(height: VSPSpacing.md),

              if (userModel != null) ...[
                _buildSubscriptionPlanBanner(userModel, isArabic),
                const SizedBox(height: VSPSpacing.md),
              ],

              if (auth.userModel?.verificationStatus == 'pending' && !_isPendingBannerDismissed) ...[
                _buildCompactPendingBanner(isArabic),
                const SizedBox(height: VSPSpacing.md),
              ],

              // ⚡ Quick Walk-in Action CTA
              _buildQuickWalkInCTA(isArabic, isExpired),
              const SizedBox(height: VSPSpacing.md),

              // 📊 1. كارت التحصيلات الأساسي (تعديل الهرمية البصرية ومراعاة الصفر)
              _buildStatsGrid(isArabic),
              const SizedBox(height: VSPSpacing.lg),

              // 💡 2. شارات اللمحة التفاعلية (Insight Badges) بدلاً من الكروت الكبيرة المغلقة
              _buildInsightBadges(isProOwner, isArabic),
              const SizedBox(height: VSPSpacing.xl),

              // 📋 حجوزات اليوم
              Text(
                isArabic ? 'حجوزات اليوم' : "Today's Bookings",
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: VSPSpacing.md),
              _buildBookedTodayList(isArabic),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, bool isArabic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isArabic ? 'أهلاً' : 'Hi'} ${(auth.userModel?.name ?? 'Owner').split(' ').first}', style: Theme.of(context).textTheme.displayMedium),
            Text(isArabic ? 'لوحة تحكم الملعب' : 'Facility Dashboard', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
          ],
        ),
        IconButton(
          icon: const Icon(LucideIcons.bell, color: Colors.white),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsCenterScreen())),
        ),
      ],
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

  Widget _buildSubscriptionPlanBanner(userModel, bool isArabic) {
    final bool isTrial = userModel.isInActiveTrial;
    final bool isPro = userModel.isProPlan;
    final bool isExpired = userModel.isPlanExpired;

    final Color statusColor = isPro
        ? Colors.amber
        : (isTrial
            ? VSPColors.accent
            : (isExpired ? Colors.redAccent : VSPColors.textSecondary));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.1)
            : (isPro ? Colors.amber.withValues(alpha: 0.1) : VSPColors.surface),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isExpired ? Colors.redAccent : (isPro ? Colors.amber : (isTrial ? VSPColors.accent : VSPColors.divider)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPro ? LucideIcons.crown : (isTrial ? LucideIcons.award : LucideIcons.shieldAlert),
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
                    Text(
                      '${isArabic ? "حالة الاشتراك:" : "Plan:"} ',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      userModel.subscriptionPlanLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  isExpired
                      ? (isArabic ? 'استقبال الحجوزات متوقف حتى التجديد' : 'New bookings paused until renewal')
                      : '${isArabic ? "الملاعب المسموحة:" : "Allowed Stadiums:"} ${userModel.maxStadiums}',
                  style: TextStyle(
                    color: isExpired ? Colors.redAccent : VSPColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showProUpgradeSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: statusColor,
              foregroundColor: isExpired ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired
                      ? (isArabic ? 'تجديد الآن' : 'Renew Now')
                      : (isArabic ? 'ترقية / تغيير' : 'Upgrade'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.arrowUpRight, size: 14),
              ],
            ),
          ),
        ],
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
          isArabic ? 'إضافة حجز نقدي / يدوي (Quick Walk-in)' : 'Quick Walk-in Booking',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildStatsGrid(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    double grossRev = 0;
    double platformFees = 0;

    for (var b in bookingProvider.userBookings) {
      if (b.status != BookingStatus.cancelled) {
        grossRev += b.totalPrice;
        if (b.paymentMethod == 'paymob' || b.paymentMethod == 'paymob_test' || b.paymentMethod == 'card') {
          platformFees += (b.totalPrice * 0.02);
        }
      }
    }

    final double netRev = grossRev; // 100% of gross stadium revenue goes to owner since fees are collected from player

    final bool isZeroRevenue = grossRev == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isZeroRevenue
            ? null
            : const LinearGradient(colors: [VSPColors.accent, VSPColors.cardDarkGreen]),
        color: isZeroRevenue ? VSPColors.surface : null,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: isZeroRevenue ? Border.all(color: VSPColors.divider) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'إجمالي تحصيلات الملعب' : 'Total Revenue',
                style: TextStyle(
                  color: isZeroRevenue ? VSPColors.textSecondary : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Icon(
                LucideIcons.wallet,
                color: isZeroRevenue ? VSPColors.textSecondary : Colors.black87,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${grossRev.toInt()} ج.م',
            style: TextStyle(
              color: isZeroRevenue ? Colors.white70 : Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'صافي مستحقات المالك (100%)' : 'Net Owner Revenue',
                    style: TextStyle(
                      color: isZeroRevenue ? VSPColors.textSecondary : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${netRev.toInt()} ج.م',
                    style: TextStyle(
                      color: isZeroRevenue ? Colors.white : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    isArabic ? '* رسوم المنصة والمعالجة تُحصل مباشرة من اللاعب' : '* Platform & gateway fees billed to player',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBadges(bool isProOwner, bool isArabic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'لمحات ذكية وأدوات نمو' : 'Smart Insights',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSingleInsightBadge(
                title: isArabic ? 'الساعات الميتة' : 'Dead Hours',
                subtitle: isArabic ? 'تحليل فترات الركود' : 'Analyze quiet slots',
                icon: LucideIcons.flame,
                iconColor: Colors.orange,
                isPro: isProOwner,
                onTap: () => _showProUpgradeSheet(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSingleInsightBadge(
                title: isArabic ? 'مقارنة الأرباح' : 'Growth Chart',
                subtitle: isArabic ? 'مقارنة بالمنطقة' : 'Compare performance',
                icon: LucideIcons.trendingUp,
                iconColor: VSPColors.accent,
                isPro: isProOwner,
                onTap: () => _showProUpgradeSheet(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleInsightBadge({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isPro,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VSPRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(color: VSPColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isPro) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookedTodayList(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final bookings = bookingProvider.userBookings;

    if (bookings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
        child: Center(child: Text(isArabic ? 'لا توجد حجوزات مسجلة اليوم' : 'No bookings for today', style: const TextStyle(color: VSPColors.textSecondary))),
      );
    }

    return Column(
      children: bookings.take(3).map((b) => ListTile(
        title: Text(b.playerTeamName ?? 'Player', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(b.stadiumName, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
        trailing: Text('${b.totalPrice.toInt()} ج.م', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
      )).toList(),
    );
  }
}

