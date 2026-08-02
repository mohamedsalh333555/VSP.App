import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../shared/widgets/vsp_pro_locked_card.dart';
import '../../../data/models.dart';
import '../../../features/player/screens/notifications_center_screen.dart';

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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
          border: Border(top: BorderSide(color: Colors.amber, width: 2)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(LucideIcons.crown, color: Colors.amber, size: 40),
            ),
            const SizedBox(height: 12),
            Text(isArabic ? 'ترقية لحساب VSP PRO 👑' : 'Upgrade to VSP PRO 👑', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              isArabic ? 'احصل على التحليلات الذكية وتعبئة الساعات الميتة لزيادة أرباحك 35%' : 'Unlock smart analytics to fill dead hours & boost profits by 35%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            _buildProRow(isArabic ? 'تحليل وتحديد الساعات الميتة تلقائياً' : 'Dead Hours Analytics'),
            _buildProRow(isArabic ? 'رسم بياني لمقارنة النمو شهرياً' : 'Monthly Growth Charts'),
            _buildProRow(isArabic ? 'تصدير التقارير المالية والضريبية PDF' : 'Export Financial PDF Reports'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg), border: Border.all(color: Colors.amber)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isArabic ? 'اشتراك المحترفين الشهري' : 'Pro Subscription', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const Text('499 ج.م/شهرياً', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: Text(isArabic ? 'اشترك الآن 🚀' : 'Subscribe Now 🚀', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isProOwner = auth.userModel?.additionalData?['isPro'] == true;

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

              if (auth.userModel?.verificationStatus == 'pending' && !_isPendingBannerDismissed) ...[
                _buildCompactPendingBanner(isArabic),
                const SizedBox(height: VSPSpacing.md),
              ],

              // 📊 1. كارت التحصيلات الأساسي (مجاني لجميع المالكين)
              _buildStatsGrid(isArabic),
              const SizedBox(height: VSPSpacing.xl),

              // 🔒 2. كارت الساعات الميتة (مغلق بالزجاج للمجانيين)
              VSPProLockedCard(
                isPro: isProOwner,
                title: 'Dead Hours Analytics',
                featureTag: 'الساعات الميتة',
                benefitText: isArabic 
                    ? 'لديك أوقات ركود تسبب خسارة أرباحك. اكتشفها وفعل الخصومات التلقائية!'
                    : 'Analyze dead hours and boost revenue automatically!',
                onUpgradeTap: () => _showProUpgradeSheet(context),
                child: _buildDeadHoursPreviewCard(isArabic),
              ),

              const SizedBox(height: VSPSpacing.md),

              // 🔒 3. كارت رسم البياني للنمو (مغلق بالزجاج للمجانيين)
              VSPProLockedCard(
                isPro: isProOwner,
                title: 'Growth Chart',
                featureTag: 'مقارنة الأرباح',
                benefitText: isArabic 
                    ? 'اكتشف رسم أرباحك البياني مقارنة بالشهر السابق والمتوسط العام.'
                    : 'Compare your monthly revenue graph with regional averages.',
                onUpgradeTap: () => _showProUpgradeSheet(context),
                child: _buildRevenueChartPreviewCard(isArabic),
              ),

              const SizedBox(height: VSPSpacing.xl),

              // 📋 حجوزات اليوم
              Text(isArabic ? 'حجوزات اليوم' : "Today's Bookings", style: Theme.of(context).textTheme.displaySmall),
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
              isArabic ? "حسابك قيد المراجعة ⏳ الحجوزات ستفعل فور توثيق أوراقك." : "Under review ⏳ Bookings will activate once verified.",
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

  Widget _buildStatsGrid(bool isArabic) {
    final bookingProvider = Provider.of<BookingProvider>(context);
    double totalRev = 0;
    for (var b in bookingProvider.userBookings) {
      if (b.status != BookingStatus.cancelled) totalRev += b.totalPrice;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [VSPColors.accent, VSPColors.cardDarkGreen]),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isArabic ? 'إجمالي تحصيلات الشهر' : 'Total Gross Revenue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${totalRev.toInt()} ج.م', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildDeadHoursPreviewCard(bool isArabic) {
    return VSPCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isArabic ? '🔥 تحليل الساعات الميتة' : '🔥 Dead Hours Analytics', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Icon(LucideIcons.flame, color: Colors.orange, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(6, (i) => Expanded(
              child: Container(
                height: 30, margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(color: i % 2 == 0 ? Colors.red.withValues(alpha: 0.3) : VSPColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartPreviewCard(bool isArabic) {
    return VSPCard(
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isArabic ? '📈 رسم نمو الأرباح' : '📈 Revenue Growth', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const Icon(LucideIcons.trendingUp, color: VSPColors.accent, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 50, color: VSPColors.surfaceAlt),
        ],
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
