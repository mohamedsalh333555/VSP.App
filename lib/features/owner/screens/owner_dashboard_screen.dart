import 'dart:async';
import 'dart:math' as math;
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
import 'package:go_router/go_router.dart';
import '../../../core/models/user_model.dart';

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
    if (userModel != null) {
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

                // 2. كارت التوثيق التفاعلي الذكي لحالة المنشأة
                if (userModel != null)
                  _buildVerificationBanner(userModel, isArabic),

                // 2.1 تنبيه انتهاء الاشتراك إن وجد
                if (userModel != null && isExpired)
                  _buildSubscriptionExpiredAlert(isArabic),

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
                        gradient: isProOwner
                            ? const SweepGradient(
                                colors: [
                                  VSPColors.accent,
                                  Color(0xFF84CC16),
                                  Color(0xFF22C55E),
                                  VSPColors.accent,
                                ],
                              )
                            : null,
                        color: isProOwner ? null : const Color(0xFF1E1E24),
                        border: isProOwner ? null : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                        boxShadow: isProOwner
                            ? [
                                BoxShadow(
                                  color: VSPColors.accent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      padding: EdgeInsets.all(isProOwner ? 2.5 : 0),
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

  /// 2. كارت التوثيق التفاعلي الفاخر بحالاته الثلاث (غير موثق / قيد المراجعة / معتمد رسمي)
  Widget _buildVerificationBanner(UserModel userModel, bool isArabic) {
    final bool isApproved = userModel.isIdentityVerified == true || userModel.verificationStatus == 'approved';
    final bool isPending = !isApproved && (userModel.verificationStatus == 'pending' || userModel.verificationStatus == 'under_review');
    final bool isRejected = !isApproved && userModel.verificationStatus == 'rejected';

    // 1. منشأة معتمدة وموثقة رسمياً
    if (isApproved) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withValues(alpha: 0.14),
              const Color(0xFF047857).withValues(alpha: 0.08),
            ],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            width: 0.9,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.verify_copy,
                color: Color(0xFF34D399),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'منشأة رياضية موثقة ومعتمدة رسمياً' : 'Officially Verified Sports Facility',
                    style: const TextStyle(
                      color: Color(0xFFD1FAE5),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'ملاعبك نشطة ومتاحة لجميع اللاعبين على المنصة' : 'Your pitches are live & available for players to book',
                    style: TextStyle(
                      color: const Color(0xFFA7F3D0).withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              '🏆',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    // 2. المستندات قيد المراجعة من الإدارة
    if (isPending) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0284C7).withValues(alpha: 0.16),
              const Color(0xFF0369A1).withValues(alpha: 0.08),
            ],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            width: 0.9,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.timer_1_copy,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic ? 'المستندات قيد المراجعة ⏳' : 'Documents Under Review ⏳',
                    style: const TextStyle(
                      color: Color(0xFFE0F2FE),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isArabic
                        ? 'أوراقك قيد التدقيق حالياً من الإدارة. يمكنك ضبط ملاعبك وإعدادات الأسعار الآن.'
                        : 'Your docs are being audited by administration. You can configure your pitches & prices.',
                    style: TextStyle(
                      color: const Color(0xFFBAE6FD).withValues(alpha: 0.85),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/documentation');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Text(
                  isArabic ? 'عرض' : 'View',
                  style: const TextStyle(
                    color: Color(0xFFE0F2FE),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. مطلوب التوثيق (غير موثق أو تم رفض بعض الوثائق)
    final Color primaryColor = isRejected ? VSPColors.error : const Color(0xFFF59E0B);
    final String title = isRejected
        ? (isArabic ? 'تم رفض بعض المستندات' : 'Documents Need Attention')
        : (isArabic ? 'منشأتك غير موثقة بعد 📄' : 'Facility Verification Required 📄');
    final String subtitle = isRejected
        ? (isArabic ? 'يرجى مراجعة وتحديث الوثائق المطلوبة لاعتماد منشأتك.' : 'Please update your uploaded documents for approval.')
        : (isArabic ? 'يرجى رفع السجل التجاري والبطاقة الضريبية لتفعيل ظهور ملاعبك للاعبين.' : 'Upload commercial registry & tax card to make your pitches visible to players.');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.16),
            primaryColor.withValues(alpha: 0.06),
          ],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.38),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRejected ? Iconsax.warning_2_copy : Iconsax.security_safe_copy,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFEF3C7),
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isRejected ? Colors.white70 : const Color(0xFFFDE68A).withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/documentation');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(VSPRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                isArabic ? 'توثيق الآن' : 'Verify Now',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2.1 تنبيه انتهاء الاشتراك
  Widget _buildSubscriptionExpiredAlert(bool isArabic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VSPColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: VSPColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Iconsax.warning_2_copy,
            color: VSPColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isArabic
                  ? 'انتهت صلاحية الاشتراك. يرجى التجديد لتفعيل الحجوزات.'
                  : 'Subscription expired. Renew now to activate bookings.',
              style: const TextStyle(color: VSPColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
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

  /// 6. قسم التحليلات والقرارات التشغيلية اليومية للمالك (Strategic Business Insights Tab)
  Widget _buildProInsightsView(
    List<Booking> allBookings,
    OwnerFinancialMetrics metrics,
    List<Stadium> stadiums,
    bool isArabic,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);

    // ── تصفية الحجوزات الصالحة (غير الملغية وحسب الملعب المحدد) ──
    final validBookings = allBookings.where((b) {
      if (b.status == BookingStatus.cancelled) return false;
      if (_selectedStadiumFilter != 'all' && b.stadiumId != _selectedStadiumFilter) return false;
      return true;
    }).toList();

    // حالة الفراغ عند عدم وجود أي حجوزات
    if (validBookings.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 6),
          _buildProInsightsFiltersRow(stadiums: stadiums, isArabic: isArabic),
          const SizedBox(height: 14),
          _buildInsightsEmptyState(isArabic),
        ],
      );
    }

    // ── تصنيف الحجوزات حسب الفترة الزمنية المحددة ──
    List<Booking> periodBookings = [];
    List<Booking> comparisonBookings = [];
    String periodLabel = isArabic ? 'اليوم' : 'Today';
    String comparisonLabel = isArabic ? 'أمس' : 'Yesterday';
    double totalAvailableHoursFactor = 1.0;

    switch (_selectedTimePeriod) {
      case 'yesterday':
        periodLabel = isArabic ? 'أمس' : 'Yesterday';
        comparisonLabel = isArabic ? 'اليوم السابق' : 'Prev Day';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayStart);
        }).toList();
        final dayBeforeYesterday = yesterdayStart.subtract(const Duration(days: 1));
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(dayBeforeYesterday.subtract(const Duration(seconds: 1))) && d.isBefore(yesterdayStart);
        }).toList();
        totalAvailableHoursFactor = 1.0;
        break;

      case 'week':
        periodLabel = isArabic ? 'الأسبوع' : 'This Week';
        comparisonLabel = isArabic ? 'الأسبوع السابق' : 'Last Week';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(thisWeekStart.subtract(const Duration(seconds: 1)));
        }).toList();
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(lastWeekStart.subtract(const Duration(seconds: 1))) && d.isBefore(thisWeekStart);
        }).toList();
        totalAvailableHoursFactor = 7.0;
        break;

      case 'month':
        periodLabel = isArabic ? 'الشهر' : 'This Month';
        comparisonLabel = isArabic ? 'الشهر السابق' : 'Last Month';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(thisMonthStart.subtract(const Duration(seconds: 1)));
        }).toList();
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(lastMonthStart.subtract(const Duration(seconds: 1))) && d.isBefore(thisMonthStart);
        }).toList();
        totalAvailableHoursFactor = 30.0;
        break;

      case 'all':
        periodLabel = isArabic ? 'الكل' : 'All-Time';
        comparisonLabel = isArabic ? 'إجمالي' : 'Overall';
        periodBookings = validBookings;
        comparisonBookings = [];
        totalAvailableHoursFactor = 30.0;
        break;

      case 'today':
      default:
        periodLabel = isArabic ? 'اليوم' : 'Today';
        comparisonLabel = isArabic ? 'أمس' : 'Yesterday';
        periodBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(todayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayEnd);
        }).toList();
        comparisonBookings = validBookings.where((b) {
          final d = (b.operationalDate ?? b.startTime).toLocal();
          return d.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) && d.isBefore(todayStart);
        }).toList();
        totalAvailableHoursFactor = 1.0;
        break;
    }

    // =========================================================================
    // METRIC 1: HERO METRIC (إجمالي إيراد الفترة مقارنة بالطاقة الاستيعابية)
    // =========================================================================
    final double periodRevenue = periodBookings.fold(0.0, (sum, b) => sum + (b.totalPrice > 0 ? b.totalPrice : b.depositPaid));
    final double previousRevenue = comparisonBookings.fold(0.0, (sum, b) => sum + (b.totalPrice > 0 ? b.totalPrice : b.depositPaid));
    final double revenueChange = previousRevenue > 0
        ? ((periodRevenue - previousRevenue) / previousRevenue) * 100
        : (periodRevenue > 0 ? 100.0 : 0.0);

    // حساب الطاقة الاستيعابية القصوى للملعب للفترة المحددة
    final int activePitchCount = _selectedStadiumFilter != 'all' ? 1 : (stadiums.isNotEmpty ? stadiums.length : 1);
    final double totalAvailableHours = activePitchCount * 16.0 * totalAvailableHoursFactor;
    final double pitchHourlyRate = stadiums.isNotEmpty && stadiums.first.pricePerHour > 0
        ? stadiums.first.pricePerHour
        : (periodRevenue > 0 && periodBookings.isNotEmpty ? (periodRevenue / periodBookings.length) : 300.0);
    final double maxCapacityRevenue = totalAvailableHours * pitchHourlyRate;
    final double ringProgress = maxCapacityRevenue > 0
        ? (periodRevenue / maxCapacityRevenue).clamp(0.0, 1.0)
        : 0.0;

    // =========================================================================
    // METRIC 2: REVENUE BREAKDOWN (تقسيم الإيراد: دفع رقمي vs كاش)
    // =========================================================================
    double digitalRevenue = 0.0;
    double cashRevenue = 0.0;
    for (final b in periodBookings) {
      final price = b.totalPrice > 0 ? b.totalPrice : b.depositPaid;
      final method = b.paymentMethod.toLowerCase().trim();
      final bool isDigital = b.isPaid ||
          b.isDepositPaid ||
          b.depositPaid > 0 ||
          (method.isNotEmpty && method != 'cash' && method != 'كاش' && method != 'نقدي');

      if (isDigital) {
        digitalRevenue += price;
      } else {
        cashRevenue += price;
      }
    }
    final double digitalPct = periodRevenue > 0 ? (digitalRevenue / periodRevenue * 100) : 0.0;
    final double cashPct = periodRevenue > 0 ? (cashRevenue / periodRevenue * 100) : 0.0;

    // =========================================================================
    // METRIC 3: STRATEGIC BUSINESS METRICS (الإشغال الفعلي + الإيراد الضائع)
    // =========================================================================
    final int totalBookingsPeriod = periodBookings.length;
    final int onlinePaidCount = periodBookings.where((b) => b.isPaid).length;
    final double averageBookingPrice = totalBookingsPeriod > 0 ? (periodRevenue / totalBookingsPeriod) : 0.0;

    double totalHoursBookedPeriod = 0.0;
    for (final b in periodBookings) {
      final diffMins = b.endTime.difference(b.startTime).inMinutes;
      totalHoursBookedPeriod += diffMins > 0 ? (diffMins / 60.0) : 1.0;
    }

    final double occupancyRate = totalAvailableHours > 0
        ? ((totalHoursBookedPeriod / totalAvailableHours) * 100).clamp(0.0, 100.0)
        : 0.0;

    final double unbookedHours = (totalAvailableHours - totalHoursBookedPeriod).clamp(0.0, totalAvailableHours);
    final double lostRevenue = unbookedHours * pitchHourlyRate;

    // =========================================================================
    // METRIC 4: BOOKING TYPES BREAKDOWN (أنواع الحجوزات من إجمالي كل الحجوزات)
    // =========================================================================
    int personalCount = 0;
    int challengeCount = 0;
    int openJoinCount = 0;

    for (final b in validBookings) {
      if (b.bookingType == BookingType.challenge || b.bookingType == BookingType.team) {
        challengeCount++;
      } else if (b.bookingType == BookingType.openJoin) {
        openJoinCount++;
      } else {
        personalCount++;
      }
    }

    final int totalAllBookings = validBookings.length;
    final double personalPct = totalAllBookings > 0 ? (personalCount / totalAllBookings * 100) : 0.0;
    final double challengePct = totalAllBookings > 0 ? (challengeCount / totalAllBookings * 100) : 0.0;
    final double openJoinPct = totalAllBookings > 0 ? (openJoinCount / totalAllBookings * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // 0. TOP FILTERS ROW (زر فلتر الملاعب + زر فلتر الأيام في صف متقابل)
        _buildProInsightsFiltersRow(
          stadiums: stadiums,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 1. HERO CARD (إطار مستطيل فاخر لمقياس المؤشرات الشعاعية)
        _buildRadialHeroCard(
          currentRevenue: periodRevenue,
          previousRevenue: previousRevenue,
          revenueChange: revenueChange,
          ringProgress: ringProgress,
          maxCapacityRevenue: maxCapacityRevenue,
          periodLabel: periodLabel,
          comparisonLabel: comparisonLabel,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 2. REVENUE SOURCES CARD (إطار مستطيل لطرق التحصيل: رقمي وكاش)
        _buildRevenueSourcesCard(
          digitalRevenue: digitalRevenue,
          digitalPct: digitalPct,
          cashRevenue: cashRevenue,
          cashPct: cashPct,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 3. 2x2 STRATEGIC KPI SQUARES (4 مربعات بإطارات رمادية وأيقونات أنيقة)
        _buildStrategicKpiGridCards(
          totalBookingsToday: totalBookingsPeriod,
          onlinePaidCount: onlinePaidCount,
          lostRevenue: lostRevenue,
          unbookedHours: unbookedHours,
          occupancyRate: occupancyRate,
          totalHoursBookedToday: totalHoursBookedPeriod,
          totalAvailableHours: totalAvailableHours,
          averageBookingPrice: averageBookingPrice,
          isArabic: isArabic,
        ),
        const SizedBox(height: 14),

        // 4. BOOKING TYPES CARD (إطار مستطيل لأنواع الحجوزات من إجمالي كل الحجوزات)
        _buildBookingTypesCard(
          totalBookings: totalAllBookings,
          personalCount: personalCount,
          personalPct: personalPct,
          challengeCount: challengeCount,
          challengePct: challengePct,
          openJoinCount: openJoinCount,
          openJoinPct: openJoinPct,
          isArabic: isArabic,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 0. PRO INSIGHTS TOP FILTERS ROW: زر الملاعب وزر الأيام متقابلين (نص وسهم فقط)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildProInsightsFiltersRow({
    required List<Stadium> stadiums,
    required bool isArabic,
  }) {
    final periodOptions = [
      {'key': 'today', 'label': isArabic ? 'اليوم' : 'Today'},
      {'key': 'yesterday', 'label': isArabic ? 'أمس' : 'Yesterday'},
      {'key': 'week', 'label': isArabic ? 'الأسبوع' : 'This Week'},
      {'key': 'month', 'label': isArabic ? 'الشهر' : 'This Month'},
      {'key': 'all', 'label': isArabic ? 'الكل' : 'All Time'},
    ];

    return Row(
      children: [
        // 1. زر فلتر الملاعب (Stadium Filter Dropdown)
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141417),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStadiumFilter,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 12),
                selectedItemBuilder: (context) {
                  final items = [
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text(
                        isArabic ? 'جميع الملاعب' : 'All Pitches',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...stadiums.map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    )),
                  ];
                  return items.map((item) => Align(alignment: Alignment.centerRight, child: item.child)).toList();
                },
                items: [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text(
                      isArabic ? 'جميع الملاعب' : 'All Pitches',
                      style: GoogleFonts.tajawal(
                        color: _selectedStadiumFilter == 'all' ? VSPColors.accent : VSPColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: _selectedStadiumFilter == 'all' ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  ...stadiums.map((s) => DropdownMenuItem<String>(
                    value: s.id,
                    child: Text(
                      s.name,
                      style: GoogleFonts.tajawal(
                        color: _selectedStadiumFilter == s.id ? VSPColors.accent : VSPColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: _selectedStadiumFilter == s.id ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  )),
                ],
                onChanged: (val) {
                  if (val != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedStadiumFilter = val);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 2. زر فلتر الأيام / الفترة الزمنية (Time Period Dropdown)
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF141417),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimePeriod,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1C21),
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 12),
                selectedItemBuilder: (context) {
                  return periodOptions.map((p) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        p['label']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList();
                },
                items: periodOptions.map((p) {
                  final isCurrent = _selectedTimePeriod == p['key'];
                  return DropdownMenuItem<String>(
                    value: p['key'],
                    child: Text(
                      p['label']!,
                      style: GoogleFonts.tajawal(
                        color: isCurrent ? VSPColors.accent : VSPColors.textPrimary,
                        fontSize: 12.5,
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
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. HERO CARD: مستطيل بإطار رمادي فاخر لمقياس المؤشرات الشعاعية
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRadialHeroCard({
    required double currentRevenue,
    required double previousRevenue,
    required double revenueChange,
    required double ringProgress,
    required double maxCapacityRevenue,
    required String periodLabel,
    required String comparisonLabel,
    required bool isArabic,
  }) {
    final bool isPositive = revenueChange > 0;
    final bool isNegative = revenueChange < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        children: [
          // Radial Tick Dial Gauge (مقياس المؤشرات الشعاعية)
          SizedBox(
            width: 172,
            height: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Radial Ticks Painter
                CustomPaint(
                  size: const Size(172, 172),
                  painter: _RadialTickGaugePainter(
                    progress: ringProgress.clamp(0.0, 1.0),
                    activeColor: VSPColors.accent,
                    inactiveColor: const Color(0xFF27272A),
                    totalTicks: 52,
                    tickLength: 13.5,
                    strokeWidth: 2.3,
                  ),
                ),
                // Center Stats
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currentRevenue.toStringAsFixed(0),
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'جنيه $periodLabel' : 'EGP $periodLabel',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Balanced 2-Column Micro-Stats Strip (مقارنة الفترة + الطاقة القصوى)
          Row(
            children: [
              // 1. مقارنة بالفترة السابقة
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Iconsax.trend_up_copy
                            : (isNegative ? Iconsax.trend_down_copy : Iconsax.minus_copy),
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPositive
                                  ? '+${revenueChange.toStringAsFixed(1)}% ${isArabic ? "نمو" : "Growth"}'
                                  : (isNegative
                                      ? '-${revenueChange.abs().toStringAsFixed(1)}% ${isArabic ? "تراجع" : "Drop"}'
                                      : (isArabic ? 'أداء مستقر' : 'Stable')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} ج.م'
                                  : '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. الطاقة القصوى للفترة
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.flash_1_copy,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? '${(ringProgress * 100).toInt()}% إشغال'
                                  : '${(ringProgress * 100).toInt()}% Occupancy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? 'القصوى: ${maxCapacityRevenue.toStringAsFixed(0)} ج.م'
                                  : 'Max: ${maxCapacityRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
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

  // ──────────────────────────────────────────────────────────────────────────
  // 2. REVENUE SOURCES CARD: مستطيل بإطار لطرق التحصيل (رقمي / كاش)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildRevenueSourcesCard({
    required double digitalRevenue,
    required double digitalPct,
    required double cashRevenue,
    required double cashPct,
    required bool isArabic,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.wallet_3_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'طرق التحصيل والإيراد' : 'COLLECTION & PAYMENT METHODS',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFramedRevenueItem(
            title: isArabic ? 'دفع إلكتروني ورقمي' : 'Digital & Online',
            amount: digitalRevenue,
            percentage: digitalPct,
            color: VSPColors.accent,
            isArabic: isArabic,
          ),
          const SizedBox(height: 14),

          _buildFramedRevenueItem(
            title: isArabic ? 'تحصيل كاش ونقدي' : 'Cash on Arrival',
            amount: cashRevenue,
            percentage: cashPct,
            color: Colors.white70,
            isArabic: isArabic,
          ),
        ],
      ),
    );
  }

  Widget _buildFramedRevenueItem({
    required String title,
    required double amount,
    required double percentage,
    required Color color,
    required bool isArabic,
    String? unit,
  }) {
    final displayUnit = unit ?? (isArabic ? 'ج.م' : 'EGP');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              '(${percentage.toStringAsFixed(0)}%)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${amount.toStringAsFixed(0)} $displayUnit',
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFF27272A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. 2x2 KPI GRID CARDS: 4 مربعات قابلة للنقر مع شروحات بوب اب
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStrategicKpiGridCards({
    required int totalBookingsToday,
    required int onlinePaidCount,
    required double lostRevenue,
    required double unbookedHours,
    required double occupancyRate,
    required double totalHoursBookedToday,
    required double totalAvailableHours,
    required double averageBookingPrice,
    required bool isArabic,
  }) {
    return Column(
      children: [
        // Row 1: حجوزات اليوم + الإيراد غير المستغل
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.calendar_1_copy,
                value: '$totalBookingsToday',
                label: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                subtext: isArabic
                    ? '$onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش'
                    : '$onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash',
                onTap: () => _showKpiExplanationSheet(
                  title: isArabic ? 'حجوزات اليوم' : 'Bookings Today',
                  value: isArabic
                      ? '$totalBookingsToday حجز ($onlinePaidCount أونلاين • ${totalBookingsToday - onlinePaidCount} كاش)'
                      : '$totalBookingsToday bookings ($onlinePaidCount online • ${totalBookingsToday - onlinePaidCount} cash)',
                  icon: Iconsax.calendar_1_copy,
                  explanation: isArabic
                      ? 'يمثل إجمالي عدد الحجوزات المؤكدة لملعبك خلال ساعات اليوم، مع تصنيف فوري للحجوزات المدفوعة إلكترونياً (أونلاين) والحجوزات النقدية (كاش) لتسهيل مراجعة الخزينة.'
                      : 'Represents the total confirmed bookings for your venue today, with a breakdown between digital online payments and cash collections.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.moneys_copy,
                value: '${lostRevenue.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential',
                subtext: isArabic
                    ? '${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة'
                    : '${unbookedHours.toStringAsFixed(1)} unbooked hrs',
                onTap: () => _showKpiExplanationSheet(
                  title: isArabic ? 'الإيراد غير المستغل' : 'Lost Potential Revenue',
                  value: isArabic
                      ? '${lostRevenue.toStringAsFixed(0)} ج.م (${unbookedHours.toStringAsFixed(unbookedHours % 1 == 0 ? 0 : 1)} ساعة شاغرة اليوم)'
                      : '${lostRevenue.toStringAsFixed(0)} EGP (${unbookedHours.toStringAsFixed(1)} unbooked hrs today)',
                  icon: Iconsax.moneys_copy,
                  explanation: isArabic
                      ? 'القيمة المالية التقديرية للساعات الشاغرة التي لم تُحجز اليوم حتى الآن بناءً على سعر الساعة للملعب. يوضح لك هذا الرقم الإيراد المفقود الذي كان بإمكانك تحقيقه إذا عمل الملعب بكامل طاقته.'
                      : 'The estimated financial value of unbooked hours today based on your hourly pitch rate. Shows the missed revenue opportunity.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: نسبة الإشغال الفعلية + متوسط سعر الحجز
        Row(
          children: [
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.chart_square_copy,
                value: '${occupancyRate.toStringAsFixed(0)}%',
                label: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy',
                subtext: isArabic
                    ? '${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة'
                    : '${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} hrs',
                onTap: () => _showKpiExplanationSheet(
                  title: isArabic ? 'نسبة الإشغال الفعلية' : 'Actual Occupancy Rate',
                  value: isArabic
                      ? '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} من ${totalAvailableHours.toStringAsFixed(0)} ساعة متاحة)'
                      : '${occupancyRate.toStringAsFixed(0)}% (${totalHoursBookedToday.toStringAsFixed(1)} of ${totalAvailableHours.toStringAsFixed(0)} available hrs)',
                  icon: Iconsax.chart_square_copy,
                  explanation: isArabic
                      ? 'النسبة المئوية لعدد الساعات المحجوزة بالفعل اليوم مقارنة بإجمالي عدد الساعات التشغيلية المتاحة في الملعب خلال 24 ساعة.'
                      : 'The percentage of operational hours actually booked today compared to the total available hours.',
                  isArabic: isArabic,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFramedKpiCard(
                icon: Iconsax.ticket_copy,
                value: '${averageBookingPrice.toStringAsFixed(0)} ${isArabic ? "ج.م" : "EGP"}',
                label: isArabic ? 'متوسط سعر الحجز' : 'Avg. Ticket Price',
                subtext: isArabic ? 'لكل حجز مسجل اليوم' : 'per registered booking',
                onTap: () => _showKpiExplanationSheet(
                  title: isArabic ? 'متوسط سعر الحجز' : 'Average Booking Price',
                  value: isArabic
                      ? '${averageBookingPrice.toStringAsFixed(0)} ج.م لكل حجز مسجل'
                      : '${averageBookingPrice.toStringAsFixed(0)} EGP per registered booking',
                  icon: Iconsax.ticket_copy,
                  explanation: isArabic
                      ? 'متوسط الإيراد الناتج عن كل حجز تم تسجيله اليوم، ويتم حسابه بقسمة إجمالي إيرادات اليوم على عدد الحجوزات.'
                      : 'The average revenue generated per booking today, calculated by dividing total daily revenue by total bookings count.',
                  isArabic: isArabic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFramedKpiCard({
    required IconData icon,
    required String value,
    required String label,
    required String subtext,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(VSPRadius.md),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141417),
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Icon(icon, size: 16, color: Colors.white70),
                  ),
                  const Icon(
                    Iconsax.info_circle_copy,
                    size: 13,
                    color: Colors.white30,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: VSPColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BOTTOM SHEET: شرح بسيط وهادئ للمؤشر (POPUP EXPLANATION)
  // ──────────────────────────────────────────────────────────────────────────
  void _showKpiExplanationSheet({
    required String title,
    required String value,
    required IconData icon,
    required String explanation,
    required bool isArabic,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141417),
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF27272A), width: 1),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grabber Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Icon + Title + Value
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Iconsax.info_circle_copy, size: 20, color: VSPColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Explanation Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(
                    explanation,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. BOOKING TYPES CARD: مستطيل بإطار لأنواع الحجوزات من إجمالي كل الحجوزات
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBookingTypesCard({
    required int totalBookings,
    required int personalCount,
    required double personalPct,
    required int challengeCount,
    required double challengePct,
    required int openJoinCount,
    required double openJoinPct,
    required bool isArabic,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.category_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'أنواع الحجوزات' : 'BOOKING TYPES',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                isArabic ? 'إجمالي $totalBookings حجز' : '$totalBookings total',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (totalBookings == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isArabic ? 'لا توجد حجوزات مسجلة بعد.' : 'No bookings registered yet.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
          else ...[
            _buildFramedRevenueItem(
              title: isArabic ? 'حجوزات عادية ومباشرة' : 'Direct & Standard',
              amount: personalCount.toDouble(),
              percentage: personalPct,
              color: VSPColors.accent,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),
            const SizedBox(height: 14),

            _buildFramedRevenueItem(
              title: isArabic ? 'تحديات ومباريات فرق' : 'Team Challenges',
              amount: challengeCount.toDouble(),
              percentage: challengePct,
              color: Colors.white70,
              isArabic: isArabic,
              unit: isArabic ? 'حجز' : 'bookings',
            ),

            if (openJoinCount > 0) ...[
              const SizedBox(height: 14),
              _buildFramedRevenueItem(
                title: isArabic ? 'مباريات انضمام وتجميع' : 'Open-Join Matches',
                amount: openJoinCount.toDouble(),
                percentage: openJoinPct,
                color: Colors.white38,
                isArabic: isArabic,
                unit: isArabic ? 'حجز' : 'bookings',
              ),
            ],
          ],
        ],
      ),
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
      {'key': 'all', 'label': isArabic ? 'الكل' : 'All Time'},
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

// ──────────────────────────────────────────────────────────────────────────
// RADIAL TICK GAUGE PAINTER (دائرة المؤشرات الشعاعية الدقيقة)
// ──────────────────────────────────────────────────────────────────────────
class _RadialTickGaugePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int totalTicks;
  final double tickLength;
  final double strokeWidth;

  _RadialTickGaugePainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.totalTicks,
    required this.tickLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 2;
    final innerRadius = outerRadius - tickLength;
    const startAngle = -math.pi / 2; // 12 o'clock
    final angleStep = (2 * math.pi) / totalTicks;

    final activeTicksCount = (progress * totalTicks).round().clamp(progress > 0 ? 1 : 0, totalTicks);

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalTicks; i++) {
      final angle = startAngle + (i * angleStep);
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);

      final p1 = Offset(center.dx + innerRadius * cosA, center.dy + innerRadius * sinA);
      final p2 = Offset(center.dx + outerRadius * cosA, center.dy + outerRadius * sinA);

      final isTickActive = i < activeTicksCount;
      canvas.drawLine(p1, p2, isTickActive ? activePaint : inactivePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialTickGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
