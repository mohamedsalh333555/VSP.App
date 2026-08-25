import 'dart:async';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../data/models.dart';
import '../../../features/player/screens/notifications_center_screen.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/repositories/tournament_repository.dart';
import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_ledger_screen.dart';
import '../../../core/utils/app_date_formatter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/image_pick_service.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// لوحة تحكم المالك المتجاوبة مع باقات الاشتراك (Basic vs Pro)
class OwnerDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const OwnerDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  String _selectedStadiumFilter = 'all';
  String _selectedTimePeriod = 'today';
  int _selectedProTabIndex = 0; // 0 = Overview (نظرة عامة), 1 = Insights (التحليلات)
  StreamSubscription? _champSubscription;
  List<Championship> _ownerChampionships = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
      if (uid != null) {
        Provider.of<BookingProvider>(context, listen: false).loadOwnerBookings(uid);
        Provider.of<StadiumProvider>(context, listen: false).listenToOwnerStadiums(uid);
        _champSubscription = TournamentRepository().getChampionshipsStream(isOwner: true, ownerId: uid).listen((champs) {
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. الهيدر الموحد وشارة الباقة
                _buildSleekHeader(auth, isProOwner, isArabic),
                const SizedBox(height: 14),

                // 2. تنبيه الحساب الخفيف (إذا كان الاشتراك منتهياً أو قيد المراجعة)
                if (userModel != null && (isExpired || isUnderReview))
                  _buildSlimAlert(userModel, isArabic, isExpired, isUnderReview),

                // 3. المحتوى المتفرع حسب الباقة (Basic vs Pro)
                if (isProOwner) ...[
                  // شريط التبويب المقسم (Pill Segmented Switcher)
                  _buildProSegmentedTabs(isArabic),
                  const SizedBox(height: 12),

                  // شريط فلاتر الملاعب الأفقي (يظهر فقط إذا كان المالك يمتلك أكثر من ملعب)
                  if (stadiums.length > 1) ...[
                    _buildVenueFilterChips(stadiums, isArabic),
                    const SizedBox(height: 12),
                  ],

                  if (_selectedProTabIndex == 0) ...[
                    // تاب نظرة عامة (Overview)
                    _buildProOverviewAnalytics(metrics, isArabic),
                    const SizedBox(height: 16),
                    _buildGlanceableTimeline(context, allBookings, isArabic),
                  ] else ...[
                    // تاب التحليلات العميقة (Insights)
                    _buildProInsightsView(allBookings, metrics, stadiums, isArabic),
                  ],
                ] else ...[
                  // واجهة الباقة الأساسية (Overview Only)
                  _buildBasicFinancialGlance(metrics, isArabic),
                  const SizedBox(height: 16),
                  _buildGlanceableTimeline(context, allBookings, isArabic),
                  const SizedBox(height: 16),
                  _buildProUpgradeTeaser(context, isArabic),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. الهيدر الموحد الفاخر بالأفاتار النيوني وشارة الباقة
  Widget _buildSleekHeader(AuthProvider auth, bool isProOwner, bool isArabic) {
    final user = auth.userModel;
    final rawName = user?.name?.trim();
    final String name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (isArabic ? 'كابتن الملعب' : 'Pitch Owner');
    final isTrial = user?.isInActiveTrial == true;
    final photoUrl = user?.profileImageUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Owner Identity with Glow Avatar, Name & Pro Badge
        Expanded(
          child: Row(
            children: [
              // 1. Avatar with Neon Green Glow Ring & Quick Edit Badge
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final picked = await ImagePickService.pick(
                    context,
                    aspectRatio: CropAspectRatioPreset.square,
                  );
                  if (picked != null && mounted) {
                    try {
                      await auth.updateProfilePhoto(picked);
                      if (mounted) {
                        VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث الصورة بنجاح' : 'Photo updated');
                      }
                    } catch (_) {
                      if (mounted) {
                        VSPFeedback.showError(context, isArabic ? 'فشل تحديث الصورة' : 'Failed to update photo');
                      }
                    }
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            VSPColors.accent,
                            Color(0xFF84CC16),
                            Color(0xFF22C55E),
                            VSPColors.accent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: VSPColors.accent.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF141417),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => _buildAvatarFallback(name),
                              )
                            : _buildAvatarFallback(name),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: isArabic ? null : -1,
                      left: isArabic ? -1 : null,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Iconsax.edit_2_copy,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 2. Name & Pro Badge Pill
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Badge Pill (Pro / Basic)
                    GestureDetector(
                      onTap: () => _showProUpgradeSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isProOwner
                              ? VSPColors.accent.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                          border: Border.all(
                            color: isProOwner
                                ? VSPColors.accent.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                          boxShadow: isProOwner
                              ? [
                                  BoxShadow(
                                    color: VSPColors.accent.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          isProOwner
                              ? 'Pro'
                              : (isTrial ? (isArabic ? 'تجريبي' : 'Trial') : 'Basic'),
                          style: TextStyle(
                            color: isProOwner ? VSPColors.accent : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Notifications Button (Kept in place)
        StreamBuilder<int>(
          stream: NotificationRepository().getUnreadNotificationCount(auth.currentUser?.uid ?? ''),
          builder: (context, snapshot) {
            final unread = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: IconButton(
                    icon: const Icon(Iconsax.notification_copy, color: VSPColors.textPrimary, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                      );
                    },
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: VSPColors.accent,
                        shape: BoxShape.circle,
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

  Widget _buildAvatarFallback(String name) {
    final initials = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'M';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: VSPColors.accent,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// شريط كبسولات الملاعب الأفقي (يظهر فقط إذا كان المالك PRO ويمتلك أكثر من ملعب)
  Widget _buildVenueFilterChips(List<Stadium> stadiums, bool isArabic) {
    if (stadiums.length <= 1) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildVenueChip(
            id: 'all',
            label: isArabic ? 'كافة الملاعب' : 'All Pitches',
            icon: Iconsax.buildings_copy,
          ),
          const SizedBox(width: 8),
          ...stadiums.map((s) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _buildVenueChip(
              id: s.id,
              label: s.name,
              icon: Iconsax.location_copy,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildVenueChip({required String id, required String label, required IconData icon}) {
    final isSelected = _selectedStadiumFilter == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStadiumFilter = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(VSPRadius.full),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : VSPColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. تنبيه الحساب الخفيف
  Widget _buildSlimAlert(dynamic userModel, bool isArabic, bool isExpired, bool isUnderReview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isExpired
            ? VSPColors.error.withValues(alpha: 0.12)
            : VSPColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: isExpired
              ? VSPColors.error.withValues(alpha: 0.3)
              : VSPColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Iconsax.warning_2_copy : Iconsax.info_circle_copy,
            color: isExpired ? VSPColors.error : VSPColors.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExpired
                  ? (isArabic ? 'انتهت صلاحية الاشتراك. يرجى التجديد لتفعيل الحجوزات.' : 'Subscription expired. Renew now.')
                  : (isArabic ? 'حسابك قيد المراجعة والتوثيق من إدارة التطبيق.' : 'Account is under review.'),
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (isExpired)
            GestureDetector(
              onTap: () => _showProUpgradeSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
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

  /// 4. شريط التبويب المقسم (Pill Segmented Switcher) - مطابق 100% لنمط وحجم تبويبات التطبيق الفاخرة
  Widget _buildProSegmentedTabs(bool isArabic) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: _selectedProTabIndex == 0
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: VSPColors.accent,
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildProTabButton(
                title: isArabic ? 'نظرة عامة' : 'Overview',
                index: 0,
              ),
              _buildProTabButton(
                title: isArabic ? 'التحليلات' : 'Insights',
                index: 1,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProTabButton({required String title, required int index}) {
    final isSelected = _selectedProTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedProTabIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.black : VSPColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// 5. قسم نظرة عامة لباقة PRO (Overview Tab)
  Widget _buildProOverviewAnalytics(OwnerFinancialMetrics metrics, bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'الإيرادات' : 'Revenue',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _buildTimePeriodDropdown(isArabic),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metrics.totalPipeline.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: VSPColors.textPrimary,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  isArabic ? 'ج.م إجمالي الإيرادات' : 'EGP Total Revenue',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'كاش الملعب' : 'Pitch Cash',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.pitchCashRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'رصيد أونلاين' : 'Online Balance',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.digitalVspBalance.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
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
              Row(
                children: [
                  Text(
                    '${metrics.activeBookingsCount} ${isArabic ? "حجوزات" : "Bookings"}',
                    style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                  const SizedBox(width: 8),
                  Text(
                    '${metrics.totalHours.toStringAsFixed(1)} ${isArabic ? "ساعات لعب" : "Hours"}',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerLedgerScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(VSPRadius.full),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.document_download_copy, size: 13, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text(
                        isArabic ? 'كشف الحساب' : 'Export Ledger',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
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

  /// 6. قسم التحليلات العميقة لباقة PRO (Insights Tab)
  Widget _buildProInsightsView(
    List<Booking> allBookings,
    OwnerFinancialMetrics metrics,
    List<Stadium> stadiums,
    bool isArabic,
  ) {
    // تصفية الحجوزات الصالحة حسب الملعب المحدد
    final filtered = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (_selectedStadiumFilter != 'all' && b.stadiumId != _selectedStadiumFilter) return false;
      return true;
    }).toList();

    // ── المشكلة 2: حالة الفراغ الكاملة عند عدم وجود حجوزات كافية (Threshold-based Empty State) ──
    if (filtered.isEmpty) {
      return _buildInsightsEmptyState(isArabic);
    }

    // حساب التغير الأسبوعي مقارنة بالأسبوع السابق
    final now = DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    double thisWeekRevenue = 0.0;
    double lastWeekRevenue = 0.0;
    for (final b in filtered) {
      final bDate = b.operationalDate ?? b.startTime.toLocal();
      final price = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      if (bDate.isAfter(thisWeekStart.subtract(const Duration(seconds: 1)))) {
        thisWeekRevenue += price;
      } else if (bDate.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) && bDate.isBefore(thisWeekStart)) {
        lastWeekRevenue += price;
      }
    }

    double wowGrowth = 0.0;
    if (lastWeekRevenue > 0) {
      wowGrowth = ((thisWeekRevenue - lastWeekRevenue) / lastWeekRevenue) * 100;
    }

    final totalIncludingCancelled = allBookings.where((b) {
      if (_selectedStadiumFilter != 'all' && b.stadiumId != _selectedStadiumFilter) return false;
      return true;
    }).toList();
    final cancelledCount = totalIncludingCancelled.where((b) => b.status == BookingStatus.cancelled).length;
    final noShowCount = filtered.where((b) => b.notes?.contains('NO_SHOW') == true || b.notes?.contains('no_show') == true).length;

    // 1. المستحقات قيد التحصيل في الملعب (Pending Collections)
    double pendingTotal = 0.0;
    int pendingCount = 0;
    for (final b in filtered) {
      if (b.status != BookingStatus.cancelled && !b.isPaid && b.paymentStatus != 'paid') {
        final remaining = (b.totalPrice - b.depositPaid).clamp(0.0, double.infinity);
        if (remaining > 0) {
          pendingTotal += remaining;
          pendingCount++;
        }
      }
    }

    // 2. إجمالي ساعات اللعب والماتشات (Play Hours & Match Count)
    double totalHours = 0.0;
    int matchCount = 0;
    for (final b in filtered) {
      if (b.status != BookingStatus.cancelled) {
        matchCount++;
        final diffMins = b.endTime.difference(b.startTime).inMinutes;
        final durationHours = diffMins > 0 ? (diffMins / 60.0) : 1.0;
        totalHours += durationHours;
      }
    }

    // 3. موثوقية الحجوزات (Booking Reliability)
    final totalBookings = totalIncludingCancelled.length;
    final double reliabilityRate = totalBookings > 0
        ? (((totalBookings - cancelledCount - noShowCount) / totalBookings) * 100).clamp(0.0, 100.0)
        : 100.0;

    // 4. توزيع طرق التحصيل والإيراد (Cash vs Digital/Online)
    double cashRevenue = 0.0;
    double digitalRevenue = 0.0;
    for (final b in filtered) {
      final total = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      final deposit = b.depositPaid;
      final method = b.paymentMethod.toLowerCase();
      final bool isCashMethod = method == 'cash' || method.isEmpty;

      if (b.isPaid || b.paymentStatus == 'paid') {
        if (isCashMethod) {
          cashRevenue += total;
        } else {
          digitalRevenue += total;
        }
      } else {
        if (deposit > 0) {
          if (isCashMethod) {
            cashRevenue += deposit;
          } else {
            digitalRevenue += deposit;
          }
        }
        final remaining = (total - deposit).clamp(0.0, double.infinity);
        if (remaining > 0) {
          cashRevenue += remaining;
        }
      }
    }
    final double totalPaymentRevenue = cashRevenue + digitalRevenue;
    final double digitalPct = totalPaymentRevenue > 0 ? (digitalRevenue / totalPaymentRevenue * 100) : 0.0;
    final double cashPct = totalPaymentRevenue > 0 ? (cashRevenue / totalPaymentRevenue * 100) : 100.0;

    // 5. أفضل أيام الأسبوع (Best Days of Week)
    final Map<int, double> dayRevenues = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final b in filtered) {
      final day = b.startTime.toLocal().weekday;
      final price = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      dayRevenues[day] = (dayRevenues[day] ?? 0) + price;
    }
    final maxDayRevenue = dayRevenues.values.fold(0.0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. شبكة كروت الـ 4 KPIs (2x2 Grid) بتنسيق واضح وفاخر ──
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.38,
          children: [
            _buildKpiCard(
              title: isArabic ? 'مستحقات قيد التحصيل' : 'Pending Collections',
              primaryValue: '${pendingTotal.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
              subtitle: isArabic
                  ? (pendingCount == 0 ? 'لا توجد مستحقات معلقة' : 'متبقي من $pendingCount حجز')
                  : (pendingCount == 0 ? 'All collected' : 'From $pendingCount bookings'),
              icon: Iconsax.moneys_copy,
            ),
            _buildKpiCard(
              title: isArabic ? 'ساعات اللعب' : 'Play Hours',
              primaryValue: isArabic
                  ? '${totalHours.toStringAsFixed(totalHours % 1 == 0 ? 0 : 1)} ساعة'
                  : '${totalHours.toStringAsFixed(totalHours % 1 == 0 ? 0 : 1)} hrs',
              subtitle: isArabic
                  ? (matchCount == 0 ? 'لا توجد مباريات' : '$matchCount ماتش مسجل')
                  : '$matchCount matches',
              icon: Iconsax.timer_1_copy,
            ),
            _buildKpiCard(
              title: isArabic ? 'النمو الأسبوعي' : 'Weekly Growth',
              primaryValue: '${wowGrowth >= 0 ? "+" : ""}${wowGrowth.toStringAsFixed(1)}%',
              subtitle: isArabic ? 'مقارنة بالأسبوع السابق' : 'vs previous week',
              icon: wowGrowth >= 0 ? Iconsax.trend_up_copy : Iconsax.trend_down_copy,
            ),
            _buildKpiCard(
              title: isArabic ? 'موثوقية الحجوزات' : 'Booking Reliability',
              primaryValue: '${reliabilityRate.toStringAsFixed(0)}%',
              subtitle: isArabic
                  ? (cancelledCount == 0 && noShowCount == 0 ? 'سجل التزام 100%' : '$cancelledCount إلغاء • $noShowCount غياب')
                  : (cancelledCount == 0 && noShowCount == 0 ? '100% attendance' : '$cancelledCount cancel • $noShowCount no-show'),
              icon: Iconsax.shield_tick_copy,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 2. طرق التحصيل والإيراد (Revenue by Payment Method) ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141417),
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.card_pos_copy, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'طرق التحصيل والإيراد' : 'Revenue by Payment Method',
                    style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(VSPRadius.full),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (digitalPct > 0)
                        Expanded(
                          flex: digitalPct.toInt().clamp(1, 100),
                          child: Container(color: VSPColors.accent),
                        ),
                      if (cashPct > 0)
                        Expanded(
                          flex: cashPct.toInt().clamp(1, 100),
                          child: Container(color: const Color(0xFF38BDF8)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        '${isArabic ? "دفع رقمي / إلكتروني:" : "Digital / Online:"} ${digitalRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"} (${digitalPct.toStringAsFixed(0)}%)',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        '${isArabic ? "كاش بالملعب:" : "Cash at Venue:"} ${cashRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"} (${cashPct.toStringAsFixed(0)}%)',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 4. أفضل أيام الأسبوع (Best Days of the Week) ──
        Builder(
          builder: (context) {
            final now = DateTime.now();
            final startDate = now.subtract(const Duration(days: 6));
            final startStr = AppDateFormatter.formatDayMonth(startDate, isArabic ? 'ar' : 'en');
            final endStr = AppDateFormatter.formatDayMonth(now, isArabic ? 'ar' : 'en');
            final rangeStr = '$startStr - $endStr';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141417),
                borderRadius: BorderRadius.circular(VSPRadius.lg),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Iconsax.calendar_1_copy, color: VSPColors.accent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'إيراد أيام الأسبوع' : 'Weekly Revenue',
                            style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(VSPRadius.full),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          rangeStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDayBar(isArabic ? 'سبت' : 'Sat', dayRevenues[6] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.saturday),
                      _buildDayBar(isArabic ? 'أحد' : 'Sun', dayRevenues[7] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.sunday),
                      _buildDayBar(isArabic ? 'إثنين' : 'Mon', dayRevenues[1] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.monday),
                      _buildDayBar(isArabic ? 'ثلاثاء' : 'Tue', dayRevenues[2] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.tuesday),
                      _buildDayBar(isArabic ? 'أربعاء' : 'Wed', dayRevenues[3] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.wednesday),
                      _buildDayBar(isArabic ? 'خميس' : 'Thu', dayRevenues[4] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.thursday),
                      _buildDayBar(isArabic ? 'جمعة' : 'Fri', dayRevenues[5] ?? 0, maxDayRevenue, isArabic, now.weekday == DateTime.friday),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// ودجت حالة الفراغ للتحليلات (Threshold Empty State)
  Widget _buildInsightsEmptyState(bool isArabic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.chart_21_copy, size: 28, color: Colors.white54),
          const SizedBox(height: 8),
          Text(
            isArabic ? 'التحليلات في انتظار أول حجز' : 'Awaiting Your First Booking',
            style: const TextStyle(
              color: VSPColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'ستظهر الرسوم البيانية ومؤشرات الأداء تلقائياً بمجرد تسجيل أول حجز.'
                : 'Charts and performance metrics will appear after your first booking.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.onNavigateTab != null) {
                widget.onNavigateTab!(3);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Text(
                isArabic ? 'إدارة الحجوزات' : 'Go to Bookings',
                style: const TextStyle(color: Colors.black, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String primaryValue,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              primaryValue,
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(String dayLabel, double amount, double maxAmount, bool isArabic, bool isToday) {
    final double ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.08, 1.0) : 0.08;
    final bool isBestDay = maxAmount > 0 && amount == maxAmount;

    return Column(
      children: [
        Text(
          amount > 0 ? '${(amount / 1000).toStringAsFixed(1)}k' : '0',
          style: TextStyle(
            color: isToday ? VSPColors.accent : (isBestDay ? VSPColors.accent : VSPColors.textMuted),
            fontSize: 9.5,
            fontWeight: (isToday || isBestDay) ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 60 * ratio,
          decoration: BoxDecoration(
            color: isToday
                ? VSPColors.accent
                : (isBestDay ? VSPColors.accent.withValues(alpha: 0.7) : VSPColors.surfaceAlt),
            borderRadius: BorderRadius.circular(VSPRadius.xs),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dayLabel,
          style: TextStyle(
            color: isToday ? VSPColors.textPrimary : VSPColors.textSecondary,
            fontSize: 10.5,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        if (isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VSPRadius.full),
            ),
            child: Text(
              isArabic ? 'اليوم' : 'Today',
              style: const TextStyle(
                color: VSPColors.accent,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else
          const SizedBox(height: 13),
      ],
    );
  }

  /// 7. كبسولة الأرباح للباقة الأساسية (Basic Financial Glance)
  Widget _buildBasicFinancialGlance(OwnerFinancialMetrics metrics, bool isArabic) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
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
                isArabic ? 'الإيرادات' : 'Revenue',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _buildTimePeriodDropdown(isArabic),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metrics.totalPipeline.toStringAsFixed(0),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: VSPColors.textPrimary, height: 1),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  isArabic ? 'ج.م إجمالي' : 'EGP Total',
                  style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'كاش الملعب' : 'Pitch Cash',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.pitchCashRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'رصيد أونلاين' : 'Online Balance',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${metrics.digitalVspBalance.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                        style: const TextStyle(color: VSPColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
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

  /// 8. جدول حجوزات اليوم الموحد
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
                color: VSPColors.textPrimary,
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
                isArabic ? 'عرض الكل' : 'View All',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
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
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                const Icon(Iconsax.calendar_tick_copy, size: 28, color: Colors.white54),
                const SizedBox(height: 8),
                Text(
                  isArabic ? 'لا توجد حجوزات مسجلة اليوم' : 'No bookings recorded today',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.onNavigateTab != null) {
                      widget.onNavigateTab!(3);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                    ),
                    child: Text(
                      isArabic ? 'إدارة الحجوزات' : 'Manage Bookings',
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
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
                  color: isOngoing ? const Color(0xFF12231A) : VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.md),
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
                            ? VSPColors.accentSoft
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(VSPRadius.sm),
                      ),
                      child: Text(
                        AppDateFormatter.formatTime(b.startTime.toLocal(), locale),
                        style: TextStyle(
                          color: isOngoing ? VSPColors.accent : VSPColors.textPrimary,
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
                              color: isPassed ? VSPColors.textSecondary : VSPColors.textPrimary,
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
                                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
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

  /// 9. بطاقة الترقية الذكية للباقة الأساسية
  Widget _buildProUpgradeTeaser(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VSPColors.surface,
            VSPColors.accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.crown_copy, color: VSPColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'ضاعف أرباحك مع الباقة الاحترافية (PRO)' : 'Maximize Growth with PRO Plan',
                style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'أدر حتى 3 ملاعب كاملة، واحصل على مركز التحليلات العميقة، وتقارير نسبة الإشغال، ورسوم بيانية لأفضل أيام الأسبوع وساعات الذروة.'
                : 'Operate up to 3 pitches, get Deep Insights Center, Occupancy rate analytics, and weekly revenue & peak hour charts.',
            style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showProUpgradeSheet(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: VSPColors.accent,
                borderRadius: BorderRadius.circular(VSPRadius.full),
              ),
              child: Center(
                child: Text(
                  isArabic ? 'ترقية الآن (1000 ج.م / شهر)' : 'Upgrade to Pro (1000 EGP)',
                  style: const TextStyle(color: Colors.black, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodDropdown(bool isArabic) {
    final itemStyle = GoogleFonts.tajawal(
      color: VSPColors.textPrimary,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
    );

    final periods = [
      {'key': 'today', 'label': isArabic ? 'اليوم' : 'Today'},
      {'key': 'yesterday', 'label': isArabic ? 'أمس' : 'Yesterday'},
      {'key': 'week', 'label': isArabic ? 'الأسبوع' : 'This Week'},
      {'key': 'month', 'label': isArabic ? 'الشهر' : 'This Month'},
    ];

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimePeriod,
          dropdownColor: const Color(0xFF1C1C21),
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 13),
          style: itemStyle,
          selectedItemBuilder: (context) {
            return periods.map((p) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  p['label']!,
                  style: GoogleFonts.tajawal(
                    color: VSPColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList();
          },
          items: periods.map((p) {
            final isCurrent = _selectedTimePeriod == p['key'];
            return DropdownMenuItem<String>(
              value: p['key'],
              child: Text(
                p['label']!,
                style: GoogleFonts.tajawal(
                  color: isCurrent ? VSPColors.accent : VSPColors.textPrimary,
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.selectionClick();
              setState(() => _selectedTimePeriod = val);
            }
          },
        ),
      ),
    );
  }
}
