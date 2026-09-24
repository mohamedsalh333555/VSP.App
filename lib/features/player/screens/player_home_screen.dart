import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/vsp_ambient_background.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../widgets/home/home_feed_content.dart';
import '../widgets/home/home_governorate_modal.dart';
import '../widgets/home/home_match_outcome_dialogs.dart';
import 'bookings_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import 'team_dashboard_screen.dart';

// المفتاح العالمي للتحكم في تبويبات الرئيسية والملاحة (يتم استيراد championScreenKey من champion_screen.dart)
final GlobalKey<PlayerHomeScreenState> playerHomeScreenKey = GlobalKey<PlayerHomeScreenState>();

class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => PlayerHomeScreenState();
}

class PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _selectedIndex = 0;
  static const _selectedTabKey = 'player_last_selected_tab';

  void switchToTab(int index) {
    if (index < 0 || index > 4) return;
    setState(() => _selectedIndex = index);
    _persistSelectedTab(index);
  }

  Future<void> _persistSelectedTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTabKey, index);
  }

  Future<void> _restoreSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_selectedTabKey);
    if (saved != null && saved >= 0 && saved <= 4 && mounted) {
      setState(() => _selectedIndex = saved);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  void _fetchInitialData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreSelectedTab();
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);

      if (auth.isAuthenticated && !auth.isOwner) {
        String? gov = auth.userModel?.governorate;

        // إذا لم يكن لديه محافظة مسجلة، نقوم بمحاولة جلبها فوراً بالـ GPS أولاً في الخلفية
        if (gov == null || gov.isEmpty) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          VSPFeedback.showSuccess(
            context,
            isAr ? 'جاري تحديد موقعك الجغرافي تلقائياً...' : 'Determining your location automatically...',
          );
          final success = await auth.updateUserLocation();

          if (success) {
            final resolvedGov = auth.userModel?.governorate ?? (isAr ? 'القاهرة' : 'Cairo');
            stadiumProvider.applyGovernorateFilter(resolvedGov);
          } else {
            // إذا فشل الـ GPS أو رفض المستخدم الإذن، نفتح له نافذة الاختيار اليدوي كخيار بديل
            if (mounted) {
              VSPFeedback.showError(
                context,
                isAr
                    ? 'تعذر تحديد الموقع الجغرافي. يرجى الاختيار يدوياً.'
                    : 'Could not determine location. Please select manually.',
              );
              showLocationPickerHelper(context, auth);
            }
          }
        } else {
          stadiumProvider.applyGovernorateFilter(gov);
        }
        // Load user bookings to populate Live Match Radar
        final userId = auth.currentUser?.uid;
        if (userId != null && mounted) {
          Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
        }

        // Check for any pending challenge match result popup automatically on app launch
        if (mounted) _checkPendingChallengeResultPopup(context);
      } else {
        stadiumProvider.fetchStadiums(isRefresh: true);
      }
    });
  }

  static bool _hasShownPostMatchPopupThisSession = false;

  void _checkPendingChallengeResultPopup(BuildContext context) {
    if (_hasShownPostMatchPopupThisSession) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    bookingProvider.loadUserBookings(userId);

    if (!context.mounted) return;
    final now = DateTime.now();

    for (final booking in bookingProvider.userBookings) {
      if (booking.bookingType != BookingType.challenge) continue;
      if (booking.status == BookingStatus.cancelled) continue;

      // Must be ended within past 30 days
      if (booking.endTime.isAfter(now)) continue;
      if (booking.endTime.add(const Duration(days: 30)).isBefore(now)) continue;

      // Condition 1: No result submitted yet -> Open popup for First Captain to submit
      if (booking.matchResultStatus == MatchResultStatus.noResult) {
        _hasShownPostMatchPopupThisSession = true;
        showPostMatchAddResultDialog(context, booking, userId);
        break;
      }

      // Condition 2: Opponent submitted result -> Open popup for Second Captain to confirm / dispute
      if ((booking.matchResultStatus == MatchResultStatus.waitingOpponent ||
              booking.matchResultStatus == MatchResultStatus.disputed) &&
          booking.resultSubmittedByTeamId != null &&
          booking.resultSubmittedByTeamId != userId) {
        _hasShownPostMatchPopupThisSession = true;
        showPostMatchConfirmResultDialog(context, booking, userId);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system status bar style to match the dark theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // White icons
      statusBarBrightness: Brightness.dark, // iOS specific
    ));

    return Scaffold(
      extendBody: true,
      backgroundColor: VSPColors.background,
      body: VSPAmbientBackground(
        showTopGlow: true,
        showBottomGlow: true,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeFeedContent(
              onNavigate: (index, {arguments}) {
                setState(() {
                  _selectedIndex = index;
                  if (index == 2 && arguments != null && arguments['initialTab'] != null) {
                    championScreenKey.currentState?.switchToTab(arguments['initialTab']);
                  }
                });
              },
            ),
            const TeamDashboardScreen(),
            ChampionScreen(key: championScreenKey),
            const BookingsScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: VspBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() => _selectedIndex = index);
          _persistSelectedTab(index);
        },
        items: [
          VspNavItem(
            activeIcon: Iconsax.home_1_copy,
            inactiveIcon: Iconsax.home_1_copy,
            label: AppLocalizations.of(context)!.homeNav,
          ),
          VspNavItem(
            activeIcon: Iconsax.people_copy,
            inactiveIcon: Iconsax.people_copy,
            label: AppLocalizations.of(context)!.matchesNav,
          ),
          VspNavItem(
            activeIcon: Iconsax.cup_copy,
            inactiveIcon: Iconsax.cup_copy,
            label: AppLocalizations.of(context)!.championNav,
          ),
          VspNavItem(
            activeIcon: Iconsax.calendar_1_copy,
            inactiveIcon: Iconsax.calendar_1_copy,
            label: AppLocalizations.of(context)!.bookedNav,
          ),
          VspNavItem(
            activeIcon: Iconsax.user_copy,
            inactiveIcon: Iconsax.user_copy,
            label: AppLocalizations.of(context)!.profileNav,
          ),
        ],
      ),
    );
  }
}
