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
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/services/logger_service.dart';
import 'subscription_plans_screen.dart';
import 'owner_bookings_screen.dart';
import 'owner_ledger_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/image_pick_service.dart';
import '../../../core/utils/vsp_feedback.dart';

export '../../../core/utils/owner_financial_calculator.dart';
import '../../../core/utils/owner_financial_calculator.dart';
import '../widgets/owner_notification_button.dart';
import '../widgets/dashboard/owner_verification_banner.dart';
import '../widgets/dashboard/owner_venue_filter_chips.dart';
import '../widgets/dashboard/owner_pro_overview_card.dart';
import '../widgets/dashboard/owner_pro_insights_view.dart';
import '../widgets/dashboard/owner_basic_financial_glance.dart';
import '../widgets/dashboard/owner_glanceable_timeline.dart';
import '../widgets/dashboard/owner_pro_upgrade_teaser.dart';

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
  OwnerFinancialMetrics? _cachedMetrics;
  String? _lastMetricsKey;

  OwnerFinancialMetrics _getOrCalculateMetrics(List<Booking> allBookings) {
    final key = '${allBookings.length}_${_ownerChampionships.length}_${_selectedTimePeriod}_$_selectedStadiumFilter';
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

    final metrics = _getOrCalculateMetrics(allBookings);

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
                  OwnerVerificationBanner(userModel: userModel, isArabic: isArabic),

                // 2.1 تنبيه انتهاء الاشتراك إن وجد
                if (userModel != null && isExpired)
                  OwnerSubscriptionExpiredAlert(
                    isArabic: isArabic,
                    onRenew: () => _showProUpgradeSheet(context),
                  ),

                // 3. المحتوى المتفرع حسب الباقة (Basic vs Pro)
                if (isProOwner) ...[
                  // شريط التبويب المقسم (Pill Segmented Switcher)
                  _buildProSegmentedTabs(isArabic),
                  const SizedBox(height: 12),

                  // شريط فلاتر الملاعب الأفقي (يظهر فقط إذا كان المالك يمتلك أكثر من ملعب)
                  if (stadiums.length > 1) ...[
                    OwnerVenueFilterChips(
                      stadiums: stadiums,
                      selectedStadiumId: _selectedStadiumFilter,
                      onStadiumSelected: (id) => setState(() => _selectedStadiumFilter = id),
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_selectedProTabIndex == 0) ...[
                    // تاب نظرة عامة (Overview)
                    OwnerProOverviewCard(
                      metrics: metrics,
                      selectedTimePeriod: _selectedTimePeriod,
                      onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                      onSettleDues: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerLedgerScreen())),
                      isArabic: isArabic,
                    ),
                    const SizedBox(height: 16),
                    OwnerGlanceableTimeline(
                      allBookings: allBookings,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      isArabic: isArabic,
                      onNavigateToBookings: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(3);
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
                        }
                      },
                    ),
                  ] else ...[
                    // تاب التحليلات العميقة (Insights)
                    OwnerProInsightsView(
                      allBookings: allBookings,
                      metrics: metrics,
                      stadiums: stadiums,
                      selectedTimePeriod: _selectedTimePeriod,
                      selectedStadiumFilter: _selectedStadiumFilter,
                      onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                      onStadiumFilterChanged: (id) => setState(() => _selectedStadiumFilter = id),
                      onNavigateTab: widget.onNavigateTab,
                      isArabic: isArabic,
                    ),
                  ],
                ] else ...[
                  // واجهة الباقة الأساسية (Overview Only)
                  OwnerBasicFinancialGlance(
                    metrics: metrics,
                    selectedTimePeriod: _selectedTimePeriod,
                    onTimePeriodChanged: (period) => setState(() => _selectedTimePeriod = period),
                    isArabic: isArabic,
                  ),
                  const SizedBox(height: 16),
                  OwnerGlanceableTimeline(
                    allBookings: allBookings,
                    selectedStadiumFilter: _selectedStadiumFilter,
                    isArabic: isArabic,
                    onNavigateToBookings: () {
                      if (widget.onNavigateTab != null) {
                        widget.onNavigateTab!(3);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBookingsScreen()));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  OwnerProUpgradeTeaser(
                    onUpgrade: () => _showProUpgradeSheet(context),
                    isArabic: isArabic,
                  ),
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
                OwnerNotificationButton(userId: auth.currentUser?.uid ?? ''),
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


}
