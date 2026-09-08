import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../shared/widgets/vsp_countdown_timer.dart';
import '../../../core/repositories/app_settings_repository.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/repositories/notification_repository.dart';
import '../../../core/services/sharing_service.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../shared/widgets/vsp_bottom_nav_bar.dart';
import '../../../widgets/banner_slider_widget.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../shared/widgets/public_match_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/ui/components/vsp_section_title.dart';
import '../../../core/constants/egypt_governorates.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import '../../../shared/widgets/stadium_card.dart';
import 'stadium_details_screen.dart';
import 'all_stadiums_screen.dart';
import 'team_dashboard_screen.dart';
import 'bookings_screen.dart';
import 'champion_screen.dart';
import 'profile_screen.dart';
import 'championship_details_screen.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/match_result_modal.dart';
import '../../../core/providers/booking_provider.dart';
import 'global_search_screen.dart';
import 'notifications_center_screen.dart';
import '../../../shared/widgets/vsp_ambient_background.dart';

// المفتاح العالمي للتحكم في تبويبات الرئيسية والملاحة (يتم استيراد championScreenKey من champion_screen.dart)
final GlobalKey<PlayerHomeScreenState> playerHomeScreenKey = GlobalKey<PlayerHomeScreenState>();

class PlayerHomeScreen extends StatefulWidget {
 const PlayerHomeScreen({super.key});

 @override
 State<PlayerHomeScreen> createState() => PlayerHomeScreenState();
}

class PlayerHomeScreenState extends State<PlayerHomeScreen> {
 int _selectedIndex = 0;

 void switchToTab(int index) {
 setState(() => _selectedIndex = index);
 }
 final _searchController = TextEditingController();

 @override
 void initState() {
 super.initState();
 _fetchInitialData();
 }

 void _fetchInitialData() {
 WidgetsBinding.instance.addPostFrameCallback((_) async {
 if (!mounted) return;
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
 
 if (auth.isAuthenticated && !auth.isOwner) {
 String? gov = auth.userModel?.governorate;
 
 // إذا لم يكن لديه محافظة مسجلة، نقوم بمحاولة جلبها فوراً بالـ GPS أولاً في الخلفية
  if (gov == null || gov.isEmpty) {
  final isAr = Localizations.localeOf(context).languageCode == 'ar';
 VSPFeedback.showSuccess(context, isAr ? 'جاري تحديد موقعك الجغرافي تلقائياً...' : 'Determining your location automatically...');
 final success = await auth.updateUserLocation();
 
 if (success) {
 final resolvedGov = auth.userModel?.governorate ?? (isAr ? 'القاهرة' : 'Cairo');
 stadiumProvider.applyGovernorateFilter(resolvedGov);
 } else {
 // إذا فشل الـ GPS أو رفض المستخدم الإذن، نفتح له نافذة الاختيار اليدوي كخيار بديل
 if (mounted) {
 VSPFeedback.showError(context, isAr ? 'تعذر تحديد الموقع الجغرافي. يرجى الاختيار يدوياً.' : 'Could not determine location. Please select manually.');
 _showLocationPickerHelper(context, auth);
 }
 }
 } else {
 stadiumProvider.applyGovernorateFilter(gov);
 
 // Silent GPS check deferred to not block smooth screen entry
 Future.delayed(const Duration(seconds: 2), () async {
   if (!mounted) return;
   try {
     final gpsGov = await auth.determineGPSGovernorate();
     if (gpsGov != null && gpsGov != gov) {
       if (mounted) {
         _showGovernorateChangeAlert(context, auth, gpsGov, stadiumProvider);
       }
     }
   } catch (e) {
     debugPrint('Silent startup GPS check failed: $e');
   }
 });
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

 void _showGovernorateChangeAlert(BuildContext context, AuthProvider auth, String newGov, StadiumProvider stadiumProvider) {
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final title = isArabic ? 'تغيير المحافظة تلقائياً ' : 'Change Location ';
 final content = isArabic 
 ? 'مرحباً بك في $newGov! لاحظنا أنك انتقلت. هل تود تحديث موقعك لتظهر لك الملاعب والفرق في مكانك الجديد؟'
 : 'Welcome to $newGov! We noticed you moved. Would you like to update your location to see nearby stadiums and teams?';
 final yesBtn = isArabic ? 'تحديث الموقع' : 'Update Location';
 final noBtn = isArabic ? 'لا، شكراً' : 'No, thanks';

 return AlertDialog(
 backgroundColor: VSPColors.surface,
 surfaceTintColor: Colors.transparent,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
 title: Row(
 children: [
 const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 28),
 const SizedBox(width: 8),
 Text(
 title,
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 ),
 ],
 ),
 content: Text(
 content,
 style: const TextStyle(color: VSPColors.textSecondary, height: 1.5, fontSize: 14),
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: Text(
 noBtn,
 style: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
 ),
 ),
 ElevatedButton(
 onPressed: () async {
 Navigator.pop(ctx);
 await auth.updateProfile({'governorate': newGov});
 stadiumProvider.applyGovernorateFilter(newGov);
 if (context.mounted) {
 VSPFeedback.showSuccess(context, isArabic ? 'تم تحديث موقعك إلى $newGov! ' : 'Location updated to $newGov! ');
 }
 },
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
 ),
 child: Text(yesBtn, style: const TextStyle(fontWeight: FontWeight.bold)),
 ),
 ],
 );
 },
 );
 }

 static bool _hasShownPostMatchPopupThisSession = false;

 void _checkPendingChallengeResultPopup(BuildContext context) {
 if (_hasShownPostMatchPopupThisSession) return;
 final auth = Provider.of<AuthProvider>(context, listen: false);
 final userId = auth.currentUser?.uid ?? auth.firebaseUser?.uid;
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
 _showPostMatchAddResultDialog(context, booking, userId);
 break;
 }

 // Condition 2: Opponent submitted result -> Open popup for Second Captain to confirm / dispute
 if ((booking.matchResultStatus == MatchResultStatus.waitingOpponent || booking.matchResultStatus == MatchResultStatus.disputed) &&
 booking.resultSubmittedByTeamId != null &&
 booking.resultSubmittedByTeamId != userId) {
 _hasShownPostMatchPopupThisSession = true;
 _showPostMatchConfirmResultDialog(context, booking, userId);
 break;
 }
 }
 }

 void _showPostMatchAddResultDialog(BuildContext context, Booking booking, String userId) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
 title: Column(
 children: [
 const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 36),
 const SizedBox(height: 8),
 Text(
 isArabic ? 'انتهت مباراتك' : 'Match Completed',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 isArabic
 ? 'انتهت مباراتك في ملعب "${booking.stadiumName}". اختر نتيجة المباراة لتحديث ترتيب فريقك بالدوري:'
 : 'Your match at "${booking.stadiumName}" has ended. Select outcome to update your team league rank:',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 16),
 ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 minimumSize: const Size(double.infinity, 44),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 onPressed: () {
 Navigator.pop(ctx);
 showDialog(
 context: context,
 builder: (_) => MatchResultModal(
 booking: booking,
 submittingTeamId: booking.playerTeamId ?? userId,
 onConfirm: (outcome, rating, review) async {
 final provider = Provider.of<BookingProvider>(context, listen: false);
 await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: booking.playerTeamId ?? userId,
 outcome: outcome,
 rating: rating,
 review: review,
 );
 if (context.mounted) {
 VSPFeedback.showSuccess(context, isArabic ? 'تم تسجيل النتيجة بنجاح وفي انتظار تأكيد الخصم.' : 'Result submitted & waiting opponent confirmation.');
 }
 },
 ),
 );
 },
 child: Text(
 isArabic ? 'تسجيل نتيجة المباراة الآن' : 'Enter Match Result Now',
 style: const TextStyle(fontWeight: FontWeight.bold),
 ),
 ),
 const SizedBox(height: 8),
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: Text(isArabic ? 'تخطي للوقت الحالي' : 'Skip for now', style: const TextStyle(color: VSPColors.textSecondary)),
 ),
 ],
 ),
 );
 },
 );
 }

 void _showPostMatchConfirmResultDialog(BuildContext context, Booking booking, String userId) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final pending = booking.pendingOutcome;
 final currentTeamId = booking.opponentTeamId ?? userId;
 final isHome = currentTeamId == booking.playerTeamId;

 String claimText;
 MatchOutcome agreeOutcome;
 MatchOutcome disputeOutcome;

 if (pending == MatchOutcome.draw) {
 claimText = isArabic ? 'أدخل كابتن الخصم أن المباراة انتهت بالتعادل ' : 'Opponent reported a DRAW ';
 agreeOutcome = MatchOutcome.draw;
 disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
 } else if ((pending == MatchOutcome.homeWin && !isHome) || (pending == MatchOutcome.awayWin && isHome)) {
 claimText = isArabic ? 'أدخل كابتن الخصم أن فريقه فاز بالمباراة ' : 'Opponent reported THEY WON ';
 agreeOutcome = pending!;
 disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
 } else {
 claimText = isArabic ? 'أدخل كابتن الخصم أن فريقك هو الفائز ' : 'Opponent reported YOU WON ';
 agreeOutcome = pending!;
 disputeOutcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
 }

 showDialog(
 context: context,
 barrierDismissible: true,
 builder: (ctx) {
 return AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
 title: Column(
 children: [
 const Icon(Iconsax.notification_copy, color: VSPColors.accent, size: 36),
 const SizedBox(height: 8),
 Text(
 isArabic ? 'تأكيد نتيجة مباراة التحدي ' : 'Confirm Challenge Match Result ',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
 textAlign: TextAlign.center,
 ),
 ],
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 claimText,
 style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
 textAlign: TextAlign.center,
 ),
 const SizedBox(height: 6),
 Text(
 isArabic ? 'ملعب: ${booking.stadiumName}' : 'Pitch: ${booking.stadiumName}',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 const SizedBox(height: 16),
 Row(
 children: [
 Expanded(
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 onPressed: () async {
 Navigator.pop(ctx);
 final provider = Provider.of<BookingProvider>(context, listen: false);
 await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: currentTeamId,
 outcome: agreeOutcome,
 );
 if (context.mounted) {
 VSPFeedback.showSuccess(context, isArabic ? 'تم تأكيد النتيجة وتحديث ترتيب الدوري! ' : 'Result confirmed & rankings updated!');
 }
 },
 child: Text(
 isArabic ? ' تأكيد النتيجة' : ' Confirm',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: OutlinedButton(
 style: OutlinedButton.styleFrom(
 foregroundColor: VSPColors.error,
 side: const BorderSide(color: VSPColors.error),
 padding: const EdgeInsets.symmetric(vertical: 10),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
 ),
 onPressed: () async {
 Navigator.pop(ctx);
 final provider = Provider.of<BookingProvider>(context, listen: false);
 await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: currentTeamId,
 outcome: disputeOutcome,
 );
 if (context.mounted) {
 VSPFeedback.showWarning(context, isArabic ? 'تم تسجيل النزاع للمراجعة الإدارية ' : 'Dispute recorded for review ');
 }
 },
 child: Text(
 isArabic ? ' اعتراض' : ' Dispute',
 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: 6),
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: Text(isArabic ? 'تأجيل' : 'Later', style: const TextStyle(color: VSPColors.textSecondary)),
 ),
 ],
 ),
 );
 },
 );
 }

 @override
 void dispose() {
 _searchController.dispose();
 super.dispose();
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
 _HomeContent(
 searchController: _searchController,
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
 onItemTapped: (index) => setState(() => _selectedIndex = index),
 items: [
 VspNavItem(activeIcon: Iconsax.home_1_copy, inactiveIcon: Iconsax.home_1_copy, label: AppLocalizations.of(context)!.homeNav),
 VspNavItem(activeIcon: Iconsax.people_copy, inactiveIcon: Iconsax.people_copy, label: AppLocalizations.of(context)!.matchesNav),
 VspNavItem(activeIcon: Iconsax.cup_copy, inactiveIcon: Iconsax.cup_copy, label: AppLocalizations.of(context)!.championNav),
 VspNavItem(activeIcon: Iconsax.calendar_1_copy, inactiveIcon: Iconsax.calendar_1_copy, label: AppLocalizations.of(context)!.bookedNav),
 VspNavItem(activeIcon: Iconsax.user_copy, inactiveIcon: Iconsax.user_copy, label: AppLocalizations.of(context)!.profileNav),
 ],
 ),
 );
 }
}

// -----------------------------------------------------------------------------
// مكونات الصفحة الرئيسية
// -----------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
 final String title;
 final VoidCallback? onSeeAll;

 const _SectionHeader({required this.title, this.onSeeAll});

 @override
 Widget build(BuildContext context) {
 return Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 VSPSectionTitle(title),
 if (onSeeAll != null)
 TextButton(
 onPressed: onSeeAll,
 child: Text(AppLocalizations.of(context)!.seeAll, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
 ),
 ],
 ),
 );
 }
}

class ChampionshipCard extends StatelessWidget {
 final Championship championship;
 final double? width;
 final EdgeInsetsGeometry? margin;

 const ChampionshipCard({super.key, required this.championship, this.width, this.margin});

 @override
 Widget build(BuildContext context) {
 final int remainingTeams = (championship.maxTeams - championship.joinedTeams.length).clamp(0, championship.maxTeams);

 return GestureDetector(
 onTap: () => Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => ChampionshipDetailsScreen(championship: championship),
 ),
 ),
 child: Container(
 width: width ?? (MediaQuery.sizeOf(context).width - 32).clamp(250.0, 320.0),
 padding: const EdgeInsets.all(16),
 margin: margin ?? EdgeInsets.zero,
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(
 color: Colors.white.withValues(alpha: 0.08),
 width: 0.8,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.25),
 blurRadius: 14,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 _buildTypeBadge(AppLocalizations.of(context)!.tournament),
 if (championship.governorate.isNotEmpty) ...[
 const SizedBox(width: 6),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.full),
 border: Border.all(color: VSPColors.divider, width: 0.5),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 const Icon(Iconsax.location_copy, color: VSPColors.accent, size: 10),
 const SizedBox(width: 3),
 Text(
 championship.governorate,
 style: const TextStyle(
 color: VSPColors.textSecondary,
 fontSize: 10,
 fontWeight: FontWeight.w600,
 ),
 ),
 ],
 ),
 ),
 ],
 ],
 ),
 Builder(builder: (context) {
 final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;
 final isCompleted = championship.status == 'completed';
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 String badgeText;
 Color badgeColor;

 if (isCompleted) {
 badgeText = isArabic ? 'مكتملة' : 'COMPLETED';
 badgeColor = VSPColors.accent;
 } else if (isFull) {
 badgeText = AppLocalizations.of(context)!.full.toUpperCase();
 badgeColor = Colors.orange;
 } else {
 badgeText = AppLocalizations.of(context)!.open.toUpperCase();
 badgeColor = Colors.green;
 }

 return _buildStatusBadge(badgeText, badgeColor);
 }),
 ],
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Container(
 width: 48,
 height: 48,
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4), width: 1.5),
 ),
 child: const Center(
 child: Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 22),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(championship.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
 Text(championship.type, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
 ],
 ),
 ),
 IconButton(
 visualDensity: VisualDensity.compact,
 icon: const Icon(Iconsax.share_copy, color: VSPColors.textSecondary, size: 18), 
 onPressed: () => SharingService.shareChampionshipObject(context: context, championship: championship),
 ),
 ],
 ),
 const SizedBox(height: 12),
 Container(
 padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
 decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 Builder(builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final dateStr = AppDateFormatter.formatDayMonth(championship.startDate, isArabic ? 'ar' : 'en');
 return _buildCompactInfo(Iconsax.calendar_1_copy, isArabic ? 'البداية' : 'START', dateStr);
 }),
 _buildDivider(),
 Builder(builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return _buildCompactInfo(Iconsax.cup_copy, isArabic ? 'الجائزة' : 'PRIZE', championship.grandPrize > 0 ? "${championship.grandPrize.toInt()} ${AppLocalizations.of(context)!.egCurrency}" : (isArabic ? "كأس وميداليات" : "Cup & Medals"));
 }),
 _buildDivider(),
 Builder(builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 return _buildCompactInfo(Iconsax.card_copy, isArabic ? 'الاشتراك' : 'FEE', "${championship.entryFee.toInt()} ${AppLocalizations.of(context)!.egCurrency}");
 }),
 ],
 ),
 ),
 const SizedBox(height: 12),
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Expanded(
 child: Builder(builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final isCompleted = championship.status == 'completed';
 final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;

 if (isCompleted) {
 final hasWinner = championship.championTeamName != null && championship.championTeamName!.isNotEmpty;
 return Row(
 children: [
 const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 16),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 hasWinner
 ? (isArabic ? 'البطل: ${championship.championTeamName}' : 'Champion: ${championship.championTeamName}')
 : (isArabic ? 'البطولة مكتملة ' : 'Tournament Completed '),
 style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 );
 } else if (isFull) {
 return Text(
 isArabic ? 'البطولة مكتملة العدد ' : 'Tournament Full ',
 style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
 );
 } else {
 return Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.baseline,
 textBaseline: TextBaseline.alphabetic,
 children: [
 Text(
 "$remainingTeams",
 style: const TextStyle(
 color: VSPColors.accent,
 fontWeight: FontWeight.w900,
 fontSize: 20,
 ),
 ),
 const SizedBox(width: 4),
 Text(
 AppLocalizations.of(context)!.spotsLeft,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(
 color: VSPColors.textSecondary,
 fontWeight: FontWeight.bold,
 fontSize: 10,
 ),
 ),
 ],
 ),
 if (championship.status == 'open' && championship.startDate.isAfter(DateTime.now())) ...[
 const SizedBox(height: 4),
 VSPCountdownTimer(targetDate: championship.startDate, isCompact: true),
 ],
 ],
 );
 }
 }),
 ),
 const SizedBox(width: 8),
 Builder(builder: (context) {
 final isFull = championship.isFull || championship.joinedTeams.length >= championship.maxTeams;
 final isCompleted = championship.status == 'completed';
 final isClosed = isFull || isCompleted;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 return Container(
 height: 42.0, 
 padding: const EdgeInsets.symmetric(horizontal: 14),
 decoration: BoxDecoration(
 color: isClosed ? VSPColors.accent.withValues(alpha: 0.15) : VSPColors.accent, 
 borderRadius: BorderRadius.circular(12),
 border: isClosed ? Border.all(color: VSPColors.accent, width: 1.5) : null,
 ),
 child: Center(
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Text(
 isClosed 
 ? (isArabic ? 'عرض البطولة' : 'View Tournament')
 : AppLocalizations.of(context)!.join,
 style: TextStyle(
 color: isClosed ? VSPColors.accent : Colors.black,
 fontWeight: FontWeight.w900,
 fontSize: 13,
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(width: 6),
 Icon(
 isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
 size: 16,
 color: isClosed ? VSPColors.accent : Colors.black,
 ),
 ],
 ),
 ),
 );
 }),
 ],
 ),
 ],
 ),
 ),
 );
 }

 Widget _buildTypeBadge(String text) => Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold));

 Widget _buildStatusBadge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))]));

 Widget _buildCompactInfo(IconData? icon, String headerTitle, String value) {
 return Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Text(
 headerTitle,
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.5),
 fontSize: 9.5,
 fontWeight: FontWeight.w600,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: 3),
 Flexible(
 child: Text(
 value,
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 );
 }

 Widget _buildDivider() => Container(width: 1, height: 22, color: Colors.white10);
}

class _HomeContent extends StatelessWidget {
 final TextEditingController searchController;
 final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

 const _HomeContent({required this.searchController, required this.onNavigate});

 @override
 Widget build(BuildContext context) {
 final auth = Provider.of<AuthProvider>(context);

 return Column(
 children: [
 _buildTopBar(context, auth),
 Expanded(
 child: RefreshIndicator(
 color: VSPColors.accent,
 backgroundColor: VSPColors.surface,
 onRefresh: () async {
 context.read<StadiumProvider>().fetchStadiums(isRefresh: true);
 await Future.delayed(const Duration(milliseconds: 800));
 },
 child: SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
 padding: EdgeInsets.only(bottom: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
 child: Column(
 children: [
 const SizedBox(height: 10),
 const BannerSliderWidget(placement: 'home_slider'),
 const SizedBox(height: 14),
 Consumer<StadiumProvider>(
 builder: (context, stadiumProvider, _) => _buildStadiumsList(context, stadiumProvider),
 ),
 const SizedBox(height: 16),
 _HomeMatchesSection(onNavigate: onNavigate),
 const SizedBox(height: 16),
 _HomeChampionshipsSection(onNavigate: onNavigate),
 ],
 ),
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildTopBar(BuildContext context, AuthProvider auth) {
 return SafeArea(
 top: true,
 bottom: false,
 child: Padding(
 padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
 child: Column(
 children: [
 Row(
 children: [
 GestureDetector(
 onTap: () {
 HapticFeedback.lightImpact();
 onNavigate(4); // Switches the bottom navigation index directly to the Profile Tab (index 4)
 },
 child: Container(
 width: 52,
 height: 52,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 gradient: (auth.userModel?.isPro == true)
 ? const SweepGradient(
 colors: [VSPColors.accent, Color(0xFF84CC16), Color(0xFF22C55E), VSPColors.accent],
 )
 : null,
 color: (auth.userModel?.isPro == true) ? null : VSPColors.surface,
 border: (auth.userModel?.isPro == true) ? null : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
 boxShadow: (auth.userModel?.isPro == true)
 ? [
 BoxShadow(
 color: VSPColors.accent.withValues(alpha: 0.35),
 blurRadius: 10,
 spreadRadius: 1,
 ),
 ]
 : null,
 ),
 padding: EdgeInsets.all((auth.userModel?.isPro == true) ? 2.5 : 0),
 child: CircleAvatar(
 radius: 24,
 backgroundColor: VSPColors.surface, 
 backgroundImage: auth.userModel?.profileImageUrl != null ? NetworkImage(auth.userModel!.profileImageUrl!) : null, 
 child: auth.userModel?.profileImageUrl == null ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 20) : null,
 ),
 ),
 ),
 const SizedBox(width: 12),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text('${AppLocalizations.of(context)!.hi} ${auth.userModel?.name?.split(' ').first ?? AppLocalizations.of(context)!.playerDefaultName}', style: Theme.of(context).textTheme.titleLarge),
 Text(
 auth.userModel?.position ?? "ST",
 style: const TextStyle(
 color: Colors.white70,
 fontSize: 12,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.5,
 ),
 ),
 ],
 ),
 ),
 _HomeNotificationBadge(userId: auth.currentUser?.uid ?? ''),
 ],
 ),
 const SizedBox(height: 16),
 _buildSearchBar(context),
 ],
 ),
 ),
 );
 }

 Widget _buildSearchBar(BuildContext context) {
 const double barHeight = 52.0;
 final borderRadius = BorderRadius.circular(VSPRadius.lg);

 return Row(
 children: [
 Expanded(
 child: GestureDetector(
 onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
 child: Container(
 height: barHeight,
 padding: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: borderRadius,
 border: Border.all(color: VSPColors.divider, width: 1),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.15),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: Row(
 children: [
 const Icon(Iconsax.search_normal_copy, color: VSPColors.accent, size: 20),
 const SizedBox(width: 12),
 Expanded(
 child: Text(
 AppLocalizations.of(context)!.searchStadiums,
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 ),
 ),
 ),
 ),
 const SizedBox(width: 12),
 Material(
 color: Colors.transparent,
 child: InkWell(
 borderRadius: borderRadius,
 onTap: () async {
 final result = await showModalBottomSheet<Map<String, dynamic>>(
 context: context,
 backgroundColor: Colors.transparent,
 isScrollControlled: true,
 useSafeArea: true,
 builder: (context) => FilterBottomSheet(
 initialFilters: context.read<StadiumProvider>().currentFilters,
 ),
 );
 if (result != null && context.mounted) {
 context.read<StadiumProvider>().applyFilters(result);
 }
 },
 child: Container(
 width: barHeight,
 height: barHeight,
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: borderRadius,
 border: Border.all(color: VSPColors.divider, width: 1),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.15),
 blurRadius: 12,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: const Icon(Iconsax.filter_copy, color: VSPColors.accent, size: 20),
 ),
 ),
 ),
 ],
 );
 }

 Widget _buildStadiumsList(BuildContext context, StadiumProvider provider) {
 if (provider.stadiums.isEmpty && !provider.isLoading) {
 // DUP-FIX: استخدام القاموس المركزي بدلاً من التكرار المحلي المهدر للذاكرة
 final rawCityName = context.read<AuthProvider>().userModel?.governorate ?? 'منطقتك';
 final isAr = AppLocalizations.of(context)!.localeName == 'ar';
 final String cityName = (isAr && rawCityName != 'منطقتك')
 ? (EgyptGovernorates.governorateToArabic[rawCityName] ?? rawCityName)
 : rawCityName;

 return Container(
 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
 margin: const EdgeInsets.symmetric(horizontal: 16),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.divider),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(Iconsax.location_copy, color: VSPColors.accent.withValues(alpha: 0.3), size: 64),
 const SizedBox(height: 16),
 Text(
 isAr ? 'لم نصل إلى $cityName بعد! ' : 'We haven\'t reached $cityName yet! ',
 textAlign: TextAlign.center,
 style: Theme.of(context).textTheme.titleLarge?.copyWith(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 18,
 ),
 ),
 const SizedBox(height: 8),
 Text(
 isAr ? 'ولكننا نتوسع بسرعة في جميع المحافظات.' : 'But we are expanding rapidly to all governorates.',
 textAlign: TextAlign.center,
 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
 color: VSPColors.textSecondary,
 fontSize: 13,
 ),
 ),
 const SizedBox(height: 24),
 PrimaryButton(
 text: isAr ? 'اقترح ملعباً في منطقتك ' : 'Suggest a stadium in your area ',
 onPressed: () async {
 final message = isAr 
 ? 'مرحباً VSP، أنا من محافظة $cityName وأريد اقتراح إضافة ملاعب في منطقتي!'
 : 'Hello VSP, I am from $cityName and I want to suggest adding stadiums in my area!';
 final settings = await AppSettingsRepository().getSettings();
 final rawPhone = settings.whatsappNumber.isEmpty ? '201100229462' : settings.whatsappNumber;
 if (context.mounted) {
 await VSPLauncherUtils.openWhatsApp(context, phone: rawPhone, message: message);
 }
 },
 ),
 ],
 ),
 );
 }

 return Column(
 children: [
 if (provider.isGeographicFallback) ...[
 Container(
 width: double.infinity,
 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(12),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 20),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 AppLocalizations.of(context)!.geographicFallbackBanner,
 style: const TextStyle(
 color: VSPColors.accent,
 fontSize: 12,
 fontWeight: FontWeight.bold,
 ),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 8),
 ],
      _SectionHeader(
        title: AppLocalizations.of(context)!.nearbyStadiums,
        onSeeAll: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllStadiumsScreen(),
            ),
          );
        },
      ),
 const SizedBox(height: 8),
 SizedBox(
 height: 240,
 child: provider.isLoading && provider.stadiums.isEmpty
 ? ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: 3, itemBuilder: (_, __) => const CardSkeleton())
 : ListView.builder(
 scrollDirection: Axis.horizontal, 
 padding: const EdgeInsets.symmetric(horizontal: 16), 
 itemCount: provider.stadiums.length, 
 itemBuilder: (context, index) {
 final stadium = provider.stadiums[index];
 return Container(
 width: 300, 
 margin: const EdgeInsets.only(right: 6), 
 child: StadiumCard(
 stadium: stadium, 
 onTap: () => Navigator.push(
 context, 
 MaterialPageRoute(
 builder: (_) => StadiumDetailsScreen(stadium: stadium),
 ),
 ),
 ),
 );
 },
 ),
 ),
 ],
 );
 }

}

void _showLocationPickerHelper(BuildContext context, AuthProvider auth) {
 showModalBottomSheet(
 context: context, 
 useSafeArea: true,
 isScrollControlled: true,
 backgroundColor: VSPColors.surface, 
 shape: const RoundedRectangleBorder(
 borderRadius: BorderRadius.vertical(top: Radius.circular(20))
 ), 
 builder: (context) {
 const governorates = EgyptGovernorates.allGovernorates;
 return Container(
 padding: const EdgeInsets.all(16), 
 child: Column(
 mainAxisSize: MainAxisSize.min, 
 children: [
 Text(
 AppLocalizations.of(context)!.selectLocation, 
 style: Theme.of(context).textTheme.titleLarge
 ), 
 const SizedBox(height: 16), 
 Expanded(
 child: ListView.builder(
 itemCount: governorates.length, 
 itemBuilder: (context, index) { 
 final gov = governorates[index]; 
 final isSelected = auth.userModel?.governorate == gov; 
 return ListTile(
 leading: Icon(
 Iconsax.building_copy, 
 color: isSelected ? VSPColors.accent : VSPColors.textSecondary
 ), 
 title: Text(
 gov, 
 style: TextStyle(
 color: isSelected ? VSPColors.accent : Colors.white, 
 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
 )
 ), 
 trailing: isSelected ? const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent) : null, 
 onTap: () { 
 auth.updateProfile({'governorate': gov}); 
 context.read<StadiumProvider>().applyGovernorateFilter(gov); 
 Navigator.pop(context); 
 }
 ); 
 }
 )
 )
 ]
 )
 );
 }
 );
}







class _HomeNotificationBadge extends StatefulWidget {
  final String userId;
  const _HomeNotificationBadge({required this.userId});

  @override
  State<_HomeNotificationBadge> createState() => _HomeNotificationBadgeState();
}

class _HomeNotificationBadgeState extends State<_HomeNotificationBadge> {
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _unreadStream = NotificationRepository().getUnreadNotificationCount(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data ?? 0) > 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Iconsax.notification_copy, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
              ),
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
    );
  }
}

class _HomeMatchesSection extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;
  const _HomeMatchesSection({required this.onNavigate});

  @override
  State<_HomeMatchesSection> createState() => _HomeMatchesSectionState();
}

class _HomeMatchesSectionState extends State<_HomeMatchesSection> {
  late final Stream<List<Booking>> _matchesStream;

  @override
  void initState() {
    super.initState();
    _matchesStream = MatchRepository().getPublicMatches();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: _matchesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(' Matches Stream Error: ');
          return const SizedBox.shrink();
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _SectionHeader(title: AppLocalizations.of(context)!.joinMatches, onSeeAll: () => widget.onNavigate(1)),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: matches.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: matches.length,
                      itemBuilder: (context, i) => Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 320,
                          margin: const EdgeInsets.only(right: 6),
                          child: PublicMatchCard(booking: matches[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeChampionshipsSection extends StatefulWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;
  const _HomeChampionshipsSection({required this.onNavigate});

  @override
  State<_HomeChampionshipsSection> createState() => _HomeChampionshipsSectionState();
}

class _HomeChampionshipsSectionState extends State<_HomeChampionshipsSection> {
  late final Stream<List<Championship>> _championshipsStream;

  @override
  void initState() {
    super.initState();
    _championshipsStream = TournamentRepository().getChampionshipsStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Championship>>(
      stream: _championshipsStream,
      builder: (context, snapshot) {
        final championships = snapshot.data ?? [];
        if (championships.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _SectionHeader(
              title: AppLocalizations.of(context)!.joinChampionships,
              onSeeAll: () => widget.onNavigate(2, arguments: {'initialTab': 0}),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: championships.isEmpty && snapshot.connectionState == ConnectionState.waiting
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (_, __) => const CardSkeleton(),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: championships.length,
                      itemBuilder: (context, i) => Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 320,
                          margin: const EdgeInsets.only(right: 6),
                          child: ChampionshipCard(championship: championships[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
