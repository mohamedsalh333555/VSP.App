import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../core/ui/tokens/vsp_design_tokens.dart';
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

/// دالة تنقل سريعة تأخذ المستخدم مباشرة لتبويب ترتيب الفرق في شاشة الأبطال
void navigateToTeamsStandings(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
  playerHomeScreenKey.currentState?.switchToTab(2);
  championScreenKey.currentState?.switchToTab(1);
}

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
            final resolvedGov = auth.userModel?.governorate;
            if (resolvedGov != null && resolvedGov.isNotEmpty) {
              stadiumProvider.applyGovernorateFilter(resolvedGov);
            }
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
        // Await the authoritative booking snapshot before checking post-match actions.
        // Otherwise the popup check can run against an empty/stale list on first launch.
        final userId = auth.currentUser?.id;
        if (userId != null && mounted) {
          final bookingsLoaded =
              await Provider.of<BookingProvider>(context, listen: false)
                  .loadUserBookings(userId);
          if (mounted && bookingsLoaded) {
            try {
              // An empty set means the user is not a captain; a query failure
              // must not be silently interpreted as that business state.
              final captainTeamIds =
                  await TeamRepository().getUserCaptainTeamIdsStrict(userId);
              if (mounted) {
                _checkPendingChallengeResultPopup(
                  context,
                  captainTeamIds: captainTeamIds,
                );
              }
            } catch (e) {
              debugPrint('Could not verify captain access for pending match results: $e');
              if (mounted) {
                final isArabic =
                    Localizations.localeOf(context).languageCode == 'ar';
                VSPFeedback.showError(
                  context,
                  isArabic
                      ? 'تعذر التحقق من صلاحية قائد الفريق. أعد فتح الشاشة للمحاولة مرة أخرى.'
                      : 'Could not verify team captain access. Reopen the screen to try again.',
                );
              }
            }
          }
        }
      } else {
        stadiumProvider.fetchStadiums(isRefresh: true);
      }
    });
  }

  String? _popupShownForUserId;

  void _checkPendingChallengeResultPopup(
    BuildContext context, {
    required Set<String> captainTeamIds,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null || captainTeamIds.isEmpty) return;
    if (_popupShownForUserId == userId) return;

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);

    if (!context.mounted) return;
    final now = DateTime.now();

    for (final booking in bookingProvider.userBookings) {
      if (booking.bookingType != BookingType.challenge) continue;
      if (booking.status != BookingStatus.confirmed &&
          booking.status != BookingStatus.completed &&
          booking.status != BookingStatus.upcoming) {
        continue;
      }

      // Must be ended within past 30 days and belong to the current captain's team.
      if (booking.endTime.isAfter(now)) continue;
      if (booking.endTime.add(const Duration(days: 30)).isBefore(now)) continue;
      final myTeamId = captainTeamIds.firstWhere(
        (teamId) =>
            teamId == booking.playerTeamId || teamId == booking.opponentTeamId,
        orElse: () => '',
      );
      if (myTeamId.isEmpty) continue;

      final isCaptainOfBothTeams =
          booking.playerTeamId != null &&
          booking.opponentTeamId != null &&
          captainTeamIds.contains(booking.playerTeamId) &&
          captainTeamIds.contains(booking.opponentTeamId);

      // Either participating captain may submit the first result.
      if (booking.matchResultStatus == MatchResultStatus.noResult) {
        _popupShownForUserId = userId;
        showPostMatchAddResultDialog(context, booking, myTeamId: myTeamId);
        break;
      }

      // Only the other team's captain may respond to an existing submission.
      if (!isCaptainOfBothTeams &&
          (booking.matchResultStatus == MatchResultStatus.waitingOpponent ||
              booking.matchResultStatus == MatchResultStatus.disputed) &&
          booking.resultSubmittedByTeamId != null &&
          booking.resultSubmittedByTeamId != myTeamId) {
        showPostMatchConfirmResultDialog(
          context,
          booking,
          currentTeamId: myTeamId,
        );
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

    return VSPScaffold(
      extendBody: true,
      backgroundColor: VSPDSSemanticColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: VSPAmbientBackground(
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
      ),
      bottomNavigationBar: VspBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() => _selectedIndex = index);
          _persistSelectedTab(index);
        },
        items: [
          VspNavItem(
            inactiveIcon: Iconsax.home_1,
            activeIcon: Iconsax.home_1_copy,
            label: AppLocalizations.of(context)!.homeNav,
          ),
          VspNavItem(
            inactiveIcon: Iconsax.people,
            activeIcon: Iconsax.people_copy,
            label: AppLocalizations.of(context)!.matchesNav,
          ),
          VspNavItem(
            inactiveIcon: Iconsax.cup,
            activeIcon: Iconsax.cup_copy,
            label: AppLocalizations.of(context)!.championNav,
          ),
          VspNavItem(
            inactiveIcon: Iconsax.calendar_1,
            activeIcon: Iconsax.calendar_1_copy,
            label: AppLocalizations.of(context)!.bookedNav,
          ),
          VspNavItem(
            inactiveIcon: Iconsax.user,
            activeIcon: Iconsax.user_copy,
            label: AppLocalizations.of(context)!.profileNav,
          ),
        ],
      ),
    );
  }
}
