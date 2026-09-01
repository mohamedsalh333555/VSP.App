import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import 'chat_screen.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../shared/widgets/vsp_animated_button.dart';
import '../../../shared/widgets/vsp_empty_state.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'matchup_live_dashboard_screen.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;
import '../../../data/models.dart';
import '../widgets/match_result_modal.dart';
import '../../../core/repositories/team_repository.dart';
import 'payment_gateway_screen.dart';
import '../../../core/utils/app_date_formatter.dart';
import '../../../core/utils/vsp_feedback.dart';
import 'player_home_screen.dart';

class BookingsScreen extends StatefulWidget {
 const BookingsScreen({super.key});

 @override
 State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
 @override
 void initState() {
 super.initState();
 _loadData();
 }

 String? _myTeamId;

 Future<void> _loadData() async {
 final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
 
 final userId = authProvider.currentUser?.uid;
 if (userId != null) {
 bookingProvider.loadUserBookings(userId);
 final team = await TeamRepository().getUserTeam(userId);
 if (mounted) {
 setState(() => _myTeamId = team?.id);
 }
 }
 }

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 
 return Scaffold(
 backgroundColor: VSPColors.background,
 appBar: AppBar(
 backgroundColor: VSPColors.background,
 elevation: 0,
 automaticallyImplyLeading: false,
 title: Text(
 l10n.bookedTitle,
 style: Theme.of(context).textTheme.displayMedium,
 ),
 ),
 body: SafeArea(
 top: true,
 bottom: false,
 child: Selector<BookingProvider, ({List<Booking> upcoming, List<Booking> history, List<Booking> pending, bool loading})>(
 selector: (_, provider) => (
 upcoming: provider.upcomingBookings,
 history: provider.historyBookings,
 pending: provider.pendingBookings,
 loading: provider.isLoading,
 ),
 builder: (context, data, child) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 if (data.loading) {
 return const Center(
 child: CircularProgressIndicator(color: VSPColors.accent),
 );
 }
 
 if (data.upcoming.isEmpty && data.history.isEmpty && data.pending.isEmpty) {
 return RefreshIndicator(
 onRefresh: () async {
 final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final userId = authProvider.currentUser?.uid;
 if (userId != null) {
 Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
 await Future.delayed(const Duration(seconds: 1));
 }
 },
 color: VSPColors.accent,
 backgroundColor: VSPColors.surface,
 child: SingleChildScrollView(
 keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
 physics: const AlwaysScrollableScrollPhysics(),
 child: Padding(
 padding: const EdgeInsets.symmetric(horizontal: 16),
 child: SizedBox(
 height: MediaQuery.of(context).size.height * 0.7,
 child: _buildEmptyState(),
 ),
 ),
 ),
 );
 }
 
 return RefreshIndicator(
 onRefresh: () async {
 final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
 final userId = authProvider.currentUser?.uid;
 if (userId != null) {
 Provider.of<BookingProvider>(context, listen: false).loadUserBookings(userId);
 await Future.delayed(const Duration(seconds: 1));
 }
 },
 color: VSPColors.accent,
 backgroundColor: VSPColors.surface,
 child: ListView(
 physics: const AlwaysScrollableScrollPhysics(),
 padding: VSPScrollPadding.forList(context, hasFloatingNavBar: true, top: VSPSpacing.md),
 children: [
 // ⏱ 1. Pending Booking Auto-Recovery Banner
 if (data.pending.isNotEmpty) ...[
 ...data.pending.map((pendingBooking) {
 return Container(
 margin: const EdgeInsets.only(bottom: VSPSpacing.md),
 padding: const EdgeInsets.all(14),
 decoration: BoxDecoration(
 color: const Color(0xFF18181B),
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: Colors.amber, width: 1.2),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Row(
 children: [
 const Icon(Iconsax.timer_1_copy, color: Colors.amber, size: 20),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isArabic ? 'لديك حجز معلق في انتظار السداد' : 'Pending Booking Awaiting Payment',
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
 ),
 ),
 IconButton(
 constraints: const BoxConstraints(),
 padding: EdgeInsets.zero,
 icon: const Icon(Iconsax.trash_copy, color: Colors.redAccent, size: 18),
 tooltip: isArabic ? 'إلغاء الحجز المعلق' : 'Cancel Pending Booking',
 onPressed: () async {
 final bp = Provider.of<BookingProvider>(context, listen: false);
 await bp.cancelBooking(pendingBooking.id);
 if (context.mounted) {
 final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
 if (auth.currentUser?.uid != null) {
 bp.loadUserBookings(auth.currentUser!.uid);
 }
 }
 },
 ),
 ],
 ),
 const SizedBox(height: 6),
 Text(
 isArabic
 ? 'الحجز لملعب "${pendingBooking.stadiumName}" مثبت لك مؤقتاً. يمكنك الاستعلام عن الدفع أو استكماله الآن.'
 : 'Booking held for "${pendingBooking.stadiumName}". Verify status or complete checkout now.',
 style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12, height: 1.4),
 ),
 const SizedBox(height: 12),
 Row(
 children: [
 Expanded(
 child: ElevatedButton.icon(
 onPressed: () async {
 final bp = Provider.of<BookingProvider>(context, listen: false);
 final updated = await bp.getBookingById(pendingBooking.id);
 if (context.mounted) {
 if (updated != null && (updated.status == BookingStatus.confirmed || updated.isPaid)) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isArabic ? ' تم تأكيد حجزك بنجاح!' : ' Booking Confirmed!'),
 backgroundColor: VSPColors.accent,
 ),
 );
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(isArabic ? 'لم يتم تأكيد السداد بعد، يرجى استكمال عملية التثبيت.' : 'Payment pending. Complete checkout.'),
 backgroundColor: Colors.amber,
 ),
 );
 }
 }
 },
 icon: const Icon(Iconsax.refresh_copy, size: 14, color: Colors.white),
 label: Text(
 isArabic ? 'استعلم ' : 'Check Status ',
 style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF27272A),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: ElevatedButton.icon(
 onPressed: () {
 final draft = BookingDraft(
 stadiumId: pendingBooking.stadiumId,
 stadiumName: pendingBooking.stadiumName,
 stadiumImageUrl: pendingBooking.stadiumImageUrl,
 ownerId: pendingBooking.ownerId,
 startTime: pendingBooking.startTime,
 endTime: pendingBooking.endTime,
 bookingType: pendingBooking.bookingType,
 totalPrice: pendingBooking.totalPrice,
 depositPaid: pendingBooking.depositPaid,
 needsDeposit: pendingBooking.depositPaid > 0,
 isPaid: false,
 isPrivate: pendingBooking.isPrivate,
 rentBall: pendingBooking.rentBall,
 );
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (ctx) => PaymentGatewayScreen(
 bookingDraft: draft,
 existingBookingId: pendingBooking.id,
 existingBooking: pendingBooking,
 ),
 ),
 );
 },
 icon: const Icon(Iconsax.card_copy, size: 14, color: Colors.black),
 label: Text(
 isArabic ? 'استكمل الدفع ' : 'Resume Checkout ',
 style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
 ),
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }),
 ],

 if (data.upcoming.isNotEmpty) ...[
 Text(
 l10n.upcoming,
 style: Theme.of(context).textTheme.titleLarge,
 ),
 const SizedBox(height: VSPSpacing.md),
 ...data.upcoming.asMap().entries.map((entry) {
 final index = entry.key;
 final booking = entry.value;
 return VSPFadeInItem(
 index: index,
 child: Padding(
 padding: const EdgeInsets.only(bottom: VSPSpacing.md),
 child: _BookingCard(
 booking: booking, 
 isHistory: false,
 myTeamId: _myTeamId,
 ),
 ),
 );
 }),
 const SizedBox(height: VSPSpacing.lg),
 ],

 if (data.history.isNotEmpty) ...[
 Text(
 l10n.history,
 style: Theme.of(context).textTheme.titleLarge,
 ),
 const SizedBox(height: VSPSpacing.md),
 ...data.history.asMap().entries.map((entry) {
 final index = entry.key;
 final booking = entry.value;
 return VSPFadeInItem(
 index: index + data.upcoming.length,
 child: Padding(
 padding: const EdgeInsets.only(bottom: VSPSpacing.md),
 child: _BookingCard(
 booking: booking, 
 isHistory: true,
 myTeamId: _myTeamId,
 ),
 ),
 );
 }),
 ],
 ],
 ),
 );
 },
 ),
 ),
 );
 }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return VSPEmptyState(
      icon: Iconsax.calendar_1_copy,
      title: l10n.noBookings,
      subtitle: l10n.noBookingsSubtitle,
      buttonText: l10n.exploreStadiums,
      onButtonPressed: () {
        if (playerHomeScreenKey.currentState != null) {
          playerHomeScreenKey.currentState?.switchToTab(0);
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }
}

class _RescheduleActionBanner extends StatefulWidget {
  final Booking booking;

  const _RescheduleActionBanner({required this.booking});

  @override
  State<_RescheduleActionBanner> createState() => _RescheduleActionBannerState();
}

class _RescheduleActionBannerState extends State<_RescheduleActionBanner> {
  bool _isLoading = false;

  Future<void> _respond(bool accept) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    try {
      final success = await Provider.of<BookingProvider>(context, listen: false).respondToReschedule(
        bookingId: widget.booking.id,
        accept: accept,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          VSPFeedback.showSuccess(
            context,
            accept
                ? (isArabic ? 'تمت الموافقة وتعديل توقيت الحجز بنجاح ' : 'Reschedule accepted successfully ')
                : (isArabic ? 'تم رفض الموعد وإلغاء الحجز وإعادة المبلغ 100% ' : 'Reschedule rejected & 100% refunded '),
          );
        } else if (accept) {
          VSPFeedback.showError(
            context,
            isArabic
                ? 'عذراً، هذا الموعد المقترح تم حجزه للاعب آخر أثناء الانتظار. تم إلغاء الحجز وإعادة أموالك بالكامل.'
                : 'Sorry, this slot was taken by another player in the meantime. Booking cancelled & fully refunded.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        VSPFeedback.showError(context, isArabic ? 'حدث خطأ أثناء معالجة الطلب' : 'Failed to respond to reschedule');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.clock_copy, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? ' اقتراح من المالك بنقل موعد المباراة:' : ' Pitch owner proposed a new match time:',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${isArabic ? "الموعد المقترح: " : "Proposed time: "}${AppDateFormatter.formatDayMonth(widget.booking.proposedStartTime!, Localizations.localeOf(context).languageCode)} • ${AppDateFormatter.formatTime(widget.booking.proposedStartTime!, Localizations.localeOf(context).languageCode)}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(
              child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.amber),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
                    onPressed: () => _respond(true),
                    child: Text(
                      isArabic ? ' موافقة على الموعد' : ' Accept New Time',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: VSPColors.error, foregroundColor: Colors.white),
                    onPressed: () => _respond(false),
                    child: Text(
                      isArabic ? ' رفض واسترداد كامل' : ' Reject & Refund',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
 final Booking booking;
 final bool isHistory;
 final String? myTeamId;

 const _BookingCard({
 required this.booking,
 required this.isHistory,
 this.myTeamId,
 });

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(VSPSpacing.md),
 decoration: BoxDecoration(
 color: isHistory 
 ? VSPColors.surface 
 : const Color(0xFF2D4B15),
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 boxShadow: VSPShadow.subtle,
 ),
 child: Column(
 children: [
 Row(
 crossAxisAlignment: CrossAxisAlignment.center,
 children: [
 Container(
 width: 56,
 height: 56,
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.textPrimary.withValues(alpha: 0.15), width: 1.5),
 ),
 child: ClipRRect(
 borderRadius: BorderRadius.circular(VSPRadius.md - 1),
 child: booking.stadiumImageUrl.isNotEmpty
 ? ShimmerImage(
 imageUrl: booking.stadiumImageUrl,
 width: 56,
 height: 56,
 fit: BoxFit.cover,
 )
 : Container(
 color: VSPColors.surface,
 child: const Icon(Iconsax.location_copy, color: VSPColors.accent),
 ),
 ),
 ),
 const SizedBox(width: VSPSpacing.sm),
 
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 booking.stadiumName,
 style: Theme.of(context).textTheme.titleMedium?.copyWith(
 color: VSPColors.textPrimary,
 fontWeight: FontWeight.w800,
 letterSpacing: 0.5,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 const SizedBox(height: VSPSpacing.xs),
 Row(
 children: [
 _buildTag(_getLocalizedBookingType(context, booking.bookingType)),
 if (booking.bookingType == BookingType.openJoin && booking.isPrivate) ...[
 const SizedBox(width: VSPSpacing.sm),
 _buildTag(l10n.private, color: VSPColors.warning),
 ],
 ],
 ),
 ],
 ),
 ),

                  if (booking.status == BookingStatus.cancelled) ...[
                    _buildStatusBadge(Localizations.localeOf(context).languageCode == 'ar' ? 'ملغي' : 'Cancelled', Colors.red),
                  ] else if (booking.status == BookingStatus.pending && !booking.isPaid) ...[
                    _buildStatusBadge(Localizations.localeOf(context).languageCode == 'ar' ? 'بانتظار السداد ⏳' : 'Pending Payment ⏳', Colors.amber),
                  ] else if (!isHistory) ...[
                    _buildStatusBadge(l10n.confirmed, VSPColors.accent),
                  ] else ...[
 if (booking.endTime.isAfter(DateTime.now()))
 _buildStatusBadge(l10n.inProgress, VSPColors.accent)
 else if (booking.bookingType == BookingType.challenge)
 _buildChallengeStatusBadge(context)
 else if (booking.status == BookingStatus.completed && (booking.matchResultStatus == MatchResultStatus.noResult || booking.matchResultStatus == MatchResultStatus.waitingOpponent))
 _buildStatusBadge(l10n.submitResult, VSPColors.warning)
 else
 _buildStatusBadge(l10n.completed, VSPColors.textSecondary),
 ],
 ],
 ),

 const SizedBox(height: VSPSpacing.md),
 
 Container(
 padding: const EdgeInsets.symmetric(vertical: VSPSpacing.sm, horizontal: VSPSpacing.md),
 decoration: BoxDecoration(
 color: VSPColors.background.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(12),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 _buildInfoColumn(context, l10n.date, booking.formattedDate),
 Container(width: 1, height: 24, color: VSPColors.divider.withValues(alpha: 0.1)),
 _buildInfoColumn(context, l10n.time, _formatTimeShort(booking.formattedTimeRange)),
 Container(width: 1, height: 24, color: VSPColors.divider.withValues(alpha: 0.1)),
 Directionality(
 textDirection: TextDirection.ltr,
 child: _buildInfoColumn(context, l10n.price, '${booking.totalPrice.toInt()} ${l10n.egCurrency}'),
 ),
 ],
 ),
 ),

 if (booking.bookingType == BookingType.challenge && booking.opponentTeamName != null) ...[
 const SizedBox(height: VSPSpacing.sm),
 Container(
 padding: const EdgeInsets.all(VSPSpacing.sm),
 decoration: BoxDecoration(
 color: VSPColors.warning.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 border: Border.all(color: VSPColors.warning.withValues(alpha: 0.5)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.cup_copy, color: VSPColors.warning, size: 20),
 const SizedBox(width: VSPSpacing.sm),
 Text(
 l10n.vsOpponent(booking.opponentTeamName ?? ""),
 style: const TextStyle(
 color: VSPColors.warning,
 fontWeight: FontWeight.bold,
 ),
 ),
 ],
 ),
 ),
 ],

 if (booking.rescheduleStatus == 'pending' && booking.proposedStartTime != null) ...[
 const SizedBox(height: VSPSpacing.sm),
 _RescheduleActionBanner(booking: booking),
 ],

  if (booking.bookingType == BookingType.matchup) ...[
    const SizedBox(height: VSPSpacing.md),
    VSPAnimatedButton(
      text: Localizations.localeOf(context).languageCode == 'ar' ? 'لوحة المواجهة والنتائج الحية' : 'Live Matchup Dashboard',
      color: VSPColors.accent,
      textColor: Colors.black,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchupLiveDashboardScreen(bookingId: booking.id),
          ),
        );
      },
    ),
  ],

 if (!isHistory) ...[
 const SizedBox(height: VSPSpacing.md),
 Row(
 children: [
 Expanded(
 child: Builder(
 builder: (context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final deadline = booking.startTime.subtract(const Duration(hours: 2));
 final bool canCancel = DateTime.now().isBefore(deadline);
 final bool bookingStarted = DateTime.now().isAfter(booking.startTime);
 // Determine tooltip/label for locked state
 final String lockedLabel = bookingStarted
 ? (isArabic ? 'بدأ الحجز' : 'Booking started')
 : (isArabic ? 'لا يمكن الإلغاء (أقل من ساعتين)' : 'Cannot cancel (< 2 hrs left)');
 return Tooltip(
 message: canCancel ? '' : lockedLabel,
 child: VSPAnimatedButton(
 text: l10n.cancel,
 color: canCancel ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.4),
 textColor: canCancel ? VSPColors.error : VSPColors.textSecondary.withValues(alpha: 0.5),
 onPressed: canCancel ? () => _showCancelDialog(context) : null,
 ),
 );
 }
 ),
 ),
 const SizedBox(width: VSPSpacing.sm),
 Expanded(
 child: VSPAnimatedButton(
 text: l10n.chat,
 onPressed: () {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (context) => ChatScreen(booking: booking),
 ),
 );
 },
 ),
 ),
 ],
 ),
 ],

 if (isHistory && booking.bookingType == BookingType.challenge && booking.opponentTeamId != null &&
 booking.endTime.isBefore(DateTime.now())) ...[
 const SizedBox(height: VSPSpacing.md),
 _buildChallengeResultAction(context),
 ],
 ],
 ),
 );
 }

 String _getLocalizedBookingType(BuildContext context, BookingType type) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 switch (type) {
 case BookingType.personal:
 return isArabic ? 'حجز عادي' : 'SOLO';
 case BookingType.openJoin:
 return isArabic ? 'تجميعي' : 'OPEN JOIN';
 case BookingType.team:
 return isArabic ? 'فريق' : 'TEAM';
 case BookingType.challenge:
 return isArabic ? 'تحدي' : 'CHALLENGE';
 case BookingType.matchup:
 return isArabic ? 'مواجهات' : 'MATCHUP';
 }
 }

 Widget _buildChallengeResultAction(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final currentTeamId = myTeamId ?? booking.playerTeamId;
 if (currentTeamId == null) return const SizedBox.shrink();

 final isHome = currentTeamId == booking.playerTeamId;

 // 1. لم يدخل أحد النتيجة بعد
 if (booking.matchResultStatus == MatchResultStatus.noResult) {
 return _buildAddResultButton(context, currentTeamId, isPrimaryPopping: true);
 }

 // 2. الكابتن الأول أدخل النتيجة وينتظر رد الطرف الثاني أو يوجد نزاع
 if (booking.matchResultStatus == MatchResultStatus.waitingOpponent || booking.matchResultStatus == MatchResultStatus.disputed) {
 if (booking.resultSubmittedByTeamId == currentTeamId) {
 // الكابتن الأول: يرى الانتظار وله خيار "تعديل النتيجة" في حال أخطأ
 return Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(8),
 border: Border.all(color: Colors.white12),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.clock_copy, color: VSPColors.warning, size: 16),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 booking.matchResultStatus == MatchResultStatus.disputed
 ? (isArabic ? 'النتيجة قيد النزاع ' : 'Result under dispute ')
 : (isArabic ? 'في انتظار تأكيد الخصم ' : 'Waiting opponent confirmation '),
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 ),
 OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white70,
 side: const BorderSide(color: Colors.white24),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
 visualDensity: VisualDensity.compact,
 ),
 icon: const Icon(Iconsax.edit_2_copy, size: 14),
 label: Text(
 isArabic ? 'تعديل' : 'Edit',
 style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
 ),
 onPressed: () {
 showDialog(
 context: context,
 builder: (context) => MatchResultModal(
 booking: booking,
 submittingTeamId: currentTeamId,
 onConfirm: (outcome, rating, review) async {
 final provider = Provider.of<BookingProvider>(context, listen: false);
 final success = await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: currentTeamId,
 outcome: outcome,
 rating: rating,
 review: review,
 );
 if (context.mounted && success) {
 VSPFeedback.showSuccess(context, isArabic ? 'تم تعديل النتيجة وإرسالها للخصم للموافقة ' : 'Result updated & sent to opponent ');
 }
 },
 ),
 );
 },
 ),
 ],
 ),
 );
 } else {
 // كابتن الفريق الثاني: يرى نتيجة الخصم ويوافق بضغطة واحدة أو يعترض (وتلغى الشكوى تلقائياً عند التأكيد)!
 final pending = booking.pendingOutcome;
 String claimText;
 MatchOutcome agreeOutcome;
 MatchOutcome disputeOutcome;

 if (pending == MatchOutcome.draw) {
 claimText = isArabic ? 'أدخل الخصم أن المباراة انتهت بالتعادل ' : 'Opponent reported a DRAW ';
 agreeOutcome = MatchOutcome.draw;
 disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
 } else if ((pending == MatchOutcome.homeWin && !isHome) || (pending == MatchOutcome.awayWin && isHome)) {
 claimText = isArabic ? 'أدخل الخصم أن فريقه فاز بالمباراة ' : 'Opponent reported THEY WON ';
 agreeOutcome = pending!;
 disputeOutcome = isHome ? MatchOutcome.homeWin : MatchOutcome.awayWin;
 } else {
 claimText = isArabic ? 'أدخل الخصم أن فريقك هو الفائز ' : 'Opponent reported YOU WON ';
 agreeOutcome = pending!;
 disputeOutcome = isHome ? MatchOutcome.awayWin : MatchOutcome.homeWin;
 }

 return Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(10),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Container(
 margin: const EdgeInsets.only(bottom: 8),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: VSPColors.warning.withValues(alpha: 0.1),
 borderRadius: BorderRadius.circular(6),
 border: Border.all(color: VSPColors.warning.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.clock_copy, color: VSPColors.warning, size: 14),
 const SizedBox(width: 6),
 Expanded(
 child: Text(
 isArabic
 ? ' يرجى تأكيد النتيجة خلال 24 ساعة؛ التجاهل يؤدي للاعتماد التلقائي وخصم 5 نقاط لعب نظيف.'
 : ' Please confirm score within 24h. Inaction auto-approves result & deducts 5 Fair-Play pts.',
 style: const TextStyle(color: VSPColors.warning, fontSize: 11, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 ),
 Text(
 claimText,
 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
 ),
 const SizedBox(height: 10),
 Row(
 children: [
 Expanded(
 child: ElevatedButton(
 style: ElevatedButton.styleFrom(
 backgroundColor: VSPColors.accent,
 foregroundColor: Colors.black,
 padding: const EdgeInsets.symmetric(vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
 ),
 onPressed: () async {
 final provider = Provider.of<BookingProvider>(context, listen: false);
 await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: currentTeamId,
 outcome: agreeOutcome,
 );
 if (context.mounted) {
 VSPFeedback.showSuccess(context, isArabic ? 'تم تأكيد النتيجة، إنهاء النزاع وتحديث ترتيب الدوري! ' : 'Result confirmed & dispute resolved!');
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
 padding: const EdgeInsets.symmetric(vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
 ),
 onPressed: () async {
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
 ],
 ),
 );
 }
 }

 return const SizedBox.shrink();
 }

 Widget _buildAddResultButton(BuildContext context, String currentTeamId, {bool isPrimaryPopping = false}) {
 final l10n = AppLocalizations.of(context)!;
 return VSPAnimatedButton(
 text: l10n.addResult,
 color: isPrimaryPopping ? VSPColors.warning : VSPColors.accent,
 textColor: isPrimaryPopping ? Colors.black : VSPColors.textPrimary,
 onPressed: () {
 showDialog(
 context: context,
 builder: (context) => MatchResultModal(
 booking: booking,
 submittingTeamId: currentTeamId,
 onConfirm: (outcome, rating, review) async {
 final provider = Provider.of<BookingProvider>(context, listen: false);
 
 final success = await provider.submitMatchResult(
 bookingId: booking.id,
 teamId: currentTeamId,
 outcome: outcome,
 rating: rating,
 review: review,
 );

 if (!context.mounted) return;
 
 if (success) {
 Navigator.pop(context);
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(l10n.resultSuccess),
 backgroundColor: VSPColors.accent,
 ),
 );
 } else {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(provider.errorMessage ?? l10n.resultFailed),
 backgroundColor: Colors.red,
 ),
 );
 }
 },
 ),
 );
 },
 );
 }

 Widget _buildChallengeStatusBadge(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final currentTeamId = myTeamId ?? booking.playerTeamId;
 if (currentTeamId == null) return const SizedBox.shrink();

 final isHome = currentTeamId == booking.playerTeamId;
 final isAway = currentTeamId == booking.opponentTeamId;
 
 if (!isHome && !isAway) return const SizedBox.shrink();

 if (booking.matchResultStatus == MatchResultStatus.confirmed) {
 final outcome = booking.finalOutcome;
 if (outcome == MatchOutcome.draw) {
 return _buildStatusBadge(l10n.draw, Colors.blue);
 } else if (outcome == MatchOutcome.homeWin) {
 final isWon = isHome;
 return _buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? Colors.amber : Colors.red);
 } else if (outcome == MatchOutcome.awayWin) {
 final isWon = isAway;
 return _buildStatusBadge(isWon ? l10n.win : l10n.loss, isWon ? Colors.amber : Colors.red);
 }
 return _buildStatusBadge(l10n.completed, VSPColors.textSecondary);
 } else if (booking.matchResultStatus == MatchResultStatus.disputed) {
 return _buildStatusBadge(l10n.disputed, VSPColors.warning);
 } else if (booking.matchResultStatus == MatchResultStatus.waitingOpponent) {
 return _buildStatusBadge(l10n.waitingOpponent, VSPColors.warning);
 } else if (booking.endTime.isBefore(DateTime.now())) {
 return _buildStatusBadge(l10n.submitResult, VSPColors.warning);
 }
 
 return const SizedBox.shrink();
 }

 Widget _buildTag(String text, {Color? color}) {
 return Text(
 text,
 style: TextStyle(
 color: color ?? Colors.white.withValues(alpha: 0.9),
 fontSize: 11,
 fontWeight: FontWeight.bold,
 letterSpacing: 0.5,
 ),
 );
 }

 Widget _buildStatusBadge(String text, Color color) {
 return Container(
 padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.sm, vertical: 6),
 decoration: BoxDecoration(
 color: color.withValues(alpha: 0.2),
 borderRadius: BorderRadius.circular(20),
 border: Border.all(color: color.withValues(alpha: 0.5)),
 ),
 child: Text(
 text,
 style: TextStyle(
 color: color,
 fontSize: 12,
 fontWeight: FontWeight.bold,
 ),
 ),
 );
 }

 Widget _buildInfoColumn(BuildContext context, String label, String value) {
 return Column(
 children: [
 Text(
 label.toUpperCase(),
 style: TextStyle(
 color: Colors.white.withValues(alpha: 0.5),
 fontSize: 10,
 fontWeight: FontWeight.w600,
 letterSpacing: 0.5,
 ),
 ),
 const SizedBox(height: VSPSpacing.xs),
 Text(
 value,
 style: Theme.of(context).textTheme.titleSmall?.copyWith(
 color: VSPColors.textPrimary,
 fontWeight: FontWeight.bold,
 ),
 ),
 ],
 );
 }

 String _formatTimeShort(String timeRange) {
 final parts = timeRange.split(' - ');
 if (parts.length == 2) {
 final start = parts[0].replaceAll(':00', '');
 final end = parts[1].replaceAll(':00', '');
 return '$start - $end';
 }
 return timeRange;
 }

 void _showCancelDialog(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final bool hasDeposit = booking.isDepositPaid && booking.depositPaid > 0;

 showDialog(
 context: context,
 builder: (context) => AlertDialog(
 backgroundColor: VSPColors.surface,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.xl)),
 title: Text(
 l10n.cancelBooking,
 style: Theme.of(context).textTheme.titleLarge,
 ),
 content: Column(
 mainAxisSize: MainAxisSize.min,
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 l10n.cancelBookingConfirm,
 style: Theme.of(context).textTheme.bodyMedium,
 ),
 // ── Direct Mobile Wallet / Bank account refund notification ──
 if (hasDeposit) ...[
 const SizedBox(height: VSPSpacing.md),
 Container(
 width: double.infinity,
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.4)),
 ),
 child: Row(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 const Icon(Iconsax.rotate_left_copy, color: VSPColors.accent, size: 18),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isArabic
 ? 'سيتم استرداد مبلغ العربون تلقائياً وإرجاعه إلى حسابك البنكي (InstaPay) أو محفظتك الإلكترونية التي دفعت منها خلال دقائق معدودة .'
 : 'The deposit will be automatically refunded directly to your mobile wallet or bank account linked to InstaPay within minutes .',
 style: const TextStyle(
 color: VSPColors.accent,
 fontSize: 12,
 height: 1.4,
 ),
 ),
 ),
 ],
 ),
 ),
 ],
 ],
 ),
 actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
 actions: [
 Row(
 children: [
 Expanded(
 child: PrimaryButton(
 text: l10n.keepBooking,
 height: 48,
 color: VSPColors.surfaceAlt,
 textColor: VSPColors.textPrimary,
 onPressed: () => Navigator.pop(context),
 ),
 ),
 const SizedBox(width: VSPSpacing.md),
 Expanded(
 child: PrimaryButton(
 text: l10n.cancel,
 height: 48,
 color: VSPColors.error,
 textColor: VSPColors.background,
 onPressed: () async {
 final provider = Provider.of<BookingProvider>(context, listen: false);
 final messenger = ScaffoldMessenger.of(context);
 messenger.showSnackBar(
 SnackBar(
 content: Text(l10n.cancelling),
 duration: const Duration(seconds: 1),
 ),
 );
 Navigator.pop(context);
 final success = await provider.cancelBooking(booking.id);
 if (success) {
 messenger.showSnackBar(
 SnackBar(
 content: Text(l10n.cancelSuccess),
 backgroundColor: VSPColors.warning,
 ),
 );
 } else {
 messenger.showSnackBar(
 SnackBar(
 content: Text(provider.errorMessage ?? l10n.cancelFailed),
 backgroundColor: VSPColors.error,
 ),
 );
 }
 },
 ),
 ),
 ],
 ),
 ],
 ),
 );
 }
}






