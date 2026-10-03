import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import '../../../core/repositories/match_repository.dart';
import '../../../core/services/sharing_service.dart';

import 'chat_screen.dart';
import 'player_home_screen.dart';
import 'bookings_screen.dart';
import '../../../core/utils/vsp_match_invite_formatter.dart';

class BookingSuccessScreen extends StatefulWidget {
 final Booking booking;

 const BookingSuccessScreen({
 super.key,
 required this.booking,
 });

 @override
 State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
 with SingleTickerProviderStateMixin {
 late ConfettiController _confettiController;
 late AnimationController _checkController;
 late Animation<double> _scaleAnimation;

 @override
 void initState() {
 super.initState();

 // 1. Setup Confetti
 _confettiController = ConfettiController(duration: const Duration(seconds: 3));

 // 2. Setup Checkmark Animation
 _checkController = AnimationController(
 duration: const Duration(milliseconds: 800),
 vsync: this,
 );
 _scaleAnimation = CurvedAnimation(
 parent: _checkController,
 curve: Curves.elasticOut,
 );
 _checkController.forward();

 // 3. Trigger Confetti & Haptics
 Future.delayed(const Duration(milliseconds: 500), () {
 if (mounted) {
 _confettiController.play();
 HapticFeedback.heavyImpact();
 }
 });
 }

 @override
 void dispose() {
 _confettiController.dispose();
 _checkController.dispose();
 super.dispose();
 }

 void _copyLink() {
 final shareContent = AppLocalizations.of(context)!.shareBookingMessage(widget.booking.stadiumName, widget.booking.id);
 Clipboard.setData(ClipboardData(text: shareContent));
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(AppLocalizations.of(context)!.bookingRefCopied),
 backgroundColor: VSPColors.accent,
 behavior: SnackBarBehavior.floating,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.sm)),
 duration: const Duration(seconds: 1),
 ),
 );
 }

 @override
 Widget build(BuildContext context) {
 final l10n = AppLocalizations.of(context)!;
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 final shortRef = widget.booking.id.length >= 8 
 ? widget.booking.id.substring(0, 8).toUpperCase() 
 : widget.booking.id.toUpperCase();

 final isDeposit = widget.booking.paymentStatus == 'partially_paid' ||
     (widget.booking.depositPaid > 0 && widget.booking.depositPaid < widget.booking.totalPrice);

 final paymentMethodText = widget.booking.paymentMethod.toLowerCase() == 'cash'
 ? (isArabic ? 'دفع نقداً' : 'Cash')
 : isDeposit
     ? (isArabic ? 'دفع عربون إلكتروني' : 'Online Deposit')
     : (isArabic ? 'دفع إلكتروني كامل' : 'Full Online Payment');

 final formattedPriceAndPayment = isArabic
 ? '${widget.booking.totalPrice.toInt()} ج.م • $paymentMethodText'
 : '${widget.booking.totalPrice.toInt()} EGP • $paymentMethodText';

 return PopScope(
 canPop: false,
 onPopInvokedWithResult: (didPop, result) {
 if (didPop) return;
 Navigator.of(context).popUntil((route) => route.isFirst);
 },
 child: VSPScaffold(
 backgroundColor: VSPColors.background,
 body: SafeArea(
 child: Stack(
 alignment: Alignment.topCenter,
 children: [
 // Main Content Centered
 Center(
 child: SingleChildScrollView(
 physics: const BouncingScrollPhysics(),
 padding: const EdgeInsets.symmetric(vertical: VSPSpacing.xl),
 child: Container(
 margin: const EdgeInsets.symmetric(horizontal: VSPSpacing.lg),
 padding: const EdgeInsets.all(VSPSpacing.xl),
 decoration: BoxDecoration(
 color: VSPColors.surface,
 borderRadius: BorderRadius.circular(VSPRadius.xl),
 border: Border.all(color: VSPColors.divider, width: 0.5),
 ),
 child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
 // Animated Icon
 ScaleTransition(
 scale: _scaleAnimation,
 child: Container(
 width: 84,
 height: 84,
 decoration: BoxDecoration(
 shape: BoxShape.circle,
 border: Border.all(color: VSPColors.accent, width: 3.5),
 color: VSPColors.accent.withValues(alpha: 0.1),
 ),
 child: const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 48),
 ),
 ),
 const SizedBox(height: 20),
 
 // Title
 Text(
 l10n.bookingSuccess,
 textAlign: TextAlign.center,
 style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 22),
 ),
 
 const SizedBox(height: 12),

 Container(
   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
   decoration: BoxDecoration(
     color: VSPColors.accentSoft,
     borderRadius: BorderRadius.circular(VSPRadius.full),
     border: Border.all(color: VSPColors.borderAccent),
   ),
   child: Row(
     mainAxisSize: MainAxisSize.min,
     children: [
       const Icon(Iconsax.verify_copy, color: VSPColors.accent, size: 15),
       const SizedBox(width: 6),
       Text(
         isArabic ? 'الحجز مؤكد' : 'Booking confirmed',
         style: const TextStyle(
           color: VSPColors.accent,
           fontWeight: FontWeight.w800,
           fontSize: 12,
         ),
       ),
     ],
   ),
 ),

 const SizedBox(height: 20),
 
 // Booking Details Summary (Receipt Summary Card)
 Container(
 padding: const EdgeInsets.all(VSPSpacing.md),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
 ),
 child: Column(
 children: [
 _buildDetailRow(
 Iconsax.building_copy, 
 isArabic ? 'الملعب' : 'Stadium', 
 widget.booking.stadiumName,
 ),
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.calendar_1_copy, 
 isArabic ? 'التاريخ' : 'Date', 
 widget.booking.formattedDate,
 ),
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.clock_copy, 
 isArabic ? 'التوقيت' : 'Time Slot', 
 widget.booking.formattedTimeRange,
 isDirectionalText: true,
 ),
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.wallet_1_copy, 
 isArabic ? 'طريقة الدفع' : 'Payment', 
 formattedPriceAndPayment,
 ),
 if (widget.booking.depositPaid > 0) ...[
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.card_pos_copy, 
 isArabic ? 'العربون المدفوع أونلاين' : 'Online Deposit Paid', 
 isArabic ? '${widget.booking.depositPaid.toInt()} ج.م ' : '${widget.booking.depositPaid.toInt()} EGP ',
 ),
 if (widget.booking.totalPrice > widget.booking.depositPaid) ...[
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.money_send_copy, 
 isArabic ? 'المتبقي وسداده كاش بالملعب' : 'Remaining Pay at Pitch', 
 isArabic 
 ? '${(widget.booking.totalPrice - widget.booking.depositPaid).toInt()} ج.م ' 
 : '${(widget.booking.totalPrice - widget.booking.depositPaid).toInt()} EGP ',
 ),
 const Divider(color: VSPColors.divider, height: 16),
 Container(
 margin: const EdgeInsets.only(top: 4),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.12),
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 16),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isArabic
 ? 'تنبيه: تم سداد العربون فقط. يرجى سداد المبلغ المتبقي (${(widget.booking.totalPrice - widget.booking.depositPaid).toInt()} ج.م) نقداً عند شباك الملعب.'
 : 'Notice: Deposit only paid. Please pay the remaining balance (${(widget.booking.totalPrice - widget.booking.depositPaid).toInt()} EGP) in cash at the pitch.',
 style: const TextStyle(color: VSPColors.accent, fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 ),
 ],
 ] else if (widget.booking.paymentMethod.toLowerCase() == 'cash') ...[
 const Divider(color: VSPColors.divider, height: 16),
 Container(
 margin: const EdgeInsets.only(top: 4),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: VSPColors.warning.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(VSPRadius.sm),
 border: Border.all(color: VSPColors.warning.withValues(alpha: 0.4)),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.info_circle_copy, color: VSPColors.warning, size: 16),
 const SizedBox(width: 8),
 Expanded(
 child: Text(
 isArabic
 ? 'تنبيه: يلزم سداد كامل المبلغ (${widget.booking.totalPrice.toInt()} ج.م) نقداً عند شباك الملعب قبل النزول.'
 : 'Notice: Full payment (${widget.booking.totalPrice.toInt()} EGP) must be paid in cash at the pitch before the match.',
 style: const TextStyle(color: VSPColors.warning, fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 ),
 ],
 if (widget.booking.bookingType == BookingType.challenge) ...[
 const Divider(color: VSPColors.divider, height: 16),
 _buildDetailRow(
 Iconsax.cup_copy, 
 isArabic ? 'التحدي ضد' : 'VS Opponent', 
 widget.booking.opponentTeamName ?? (isArabic ? 'فريق المنافس' : 'Opponent Team'),
 ),
 ],
 ],
 ),
 ),
 
 const SizedBox(height: VSPSpacing.lg),
 
 // Booking Reference Box (Cleaned & Shortened)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
 ),
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Row(
 children: [
 const Icon(Iconsax.tag_copy, color: VSPColors.accent, size: 16),
 const SizedBox(width: 6),
 Text(
 isArabic ? 'مرجع الحجز: ' : 'Ref #: ',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 Directionality(
 textDirection: TextDirection.ltr,
 child: Text(
 shortRef,
 style: const TextStyle(
 color: VSPColors.accent,
 fontWeight: FontWeight.bold,
 fontSize: 14,
 letterSpacing: 1.2,
 ),
 ),
 ),
 ],
 ),
 InkWell(
 onTap: _copyLink,
 borderRadius: BorderRadius.circular(VSPRadius.xs),
 child: Container(
 padding: const EdgeInsets.all(8),
 decoration: BoxDecoration(
 color: VSPColors.accent,
 borderRadius: BorderRadius.circular(VSPRadius.xs),
 ),
 child: const Icon(Iconsax.copy_copy, color: VSPColors.background, size: 16),
 ),
 ),
 ],
 ),
 ),
 
 const SizedBox(height: 24),

 // Primary next step: My Bookings
 SizedBox(
   width: double.infinity,
   child: PrimaryButton(
     text: l10n.myBookings,
     height: 52,
     onPressed: () {
       if (playerHomeScreenKey.currentState != null) {
         Navigator.of(context).popUntil((route) => route.isFirst);
         playerHomeScreenKey.currentState?.switchToTab(3);
       } else {
         Navigator.of(context).popUntil((route) => route.isFirst);
         Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingsScreen()));
       }
     },
   ),
 ),
 const SizedBox(height: VSPSpacing.md),

 // Secondary coordination action
 SizedBox(
   width: double.infinity,
   child: OutlinedButton(
     onPressed: () {
       Navigator.push(
         context,
         MaterialPageRoute(builder: (_) => ChatScreen(booking: widget.booking)),
       );
     },
     style: OutlinedButton.styleFrom(
       minimumSize: const Size(double.infinity, 50),
       foregroundColor: VSPColors.accent,
       side: const BorderSide(color: VSPColors.borderAccent),
       shape: const StadiumBorder(),
     ),
     child: Text(
       isArabic ? 'التواصل مع مالك الملعب' : 'Chat with Stadium Owner',
       style: const TextStyle(fontWeight: FontWeight.w800),
     ),
   ),
 ),
 const SizedBox(height: VSPSpacing.sm),

 TextButton.icon(
   onPressed: () async {
     if (widget.booking.isOpenJoin) {
       final credentials = await MatchRepository().getCollectiveInviteCredentials(widget.booking.id);
       if (!context.mounted) return;
       final token = credentials?['invite_token']?.toString();
       final code = credentials?['invite_code']?.toString();
       if (token != null && token.isNotEmpty && code != null && code.isNotEmpty) {
         await SharingService.shareCollectiveInvite(
           inviteToken: token,
           inviteCode: code,
           stadiumName: widget.booking.stadiumName,
           date: widget.booking.formattedDate + ' - ' + widget.booking.formattedTimeRange,
           hostName: widget.booking.hostName ?? (isArabic ? 'المنشئ' : 'Host'),
         );
       } else {
         VSPFeedback.showInfo(context, isArabic ? 'يمكن مشاركة الدعوة بعد تأكيد الحجز.' : 'The invite can be shared after the booking is confirmed.');
       }
       return;
     }

     final inviteMessage = VSPMatchInviteFormatter.buildInviteMessage(
       stadiumName: widget.booking.stadiumName,
       bookingId: widget.booking.id,
       startTime: widget.booking.startTime,
       endTime: widget.booking.endTime,
       currentPlayers: widget.booking.currentPlayers,
       maxPlayers: widget.booking.maxPlayers,
       totalPrice: widget.booking.totalPrice,
       isArabic: isArabic,
     );
     await VSPMatchInviteFormatter.shareToWhatsApp(
       context: context,
       message: inviteMessage,
     );
   },
   icon: const Icon(Iconsax.message_copy, size: 18),
   label: Text(
     widget.booking.isOpenJoin
         ? (isArabic ? 'مشاركة دعوة التجميعية' : 'Share collective invite')
         : (isArabic ? 'مشاركة تفاصيل الماتش' : 'Share match details'),
     style: const TextStyle(fontWeight: FontWeight.w700),
   ),
   style: TextButton.styleFrom(foregroundColor: VSPColors.textSecondary),
 ),
 const SizedBox(height: VSPSpacing.xs),

 SizedBox(
   width: double.infinity,
   child: TextButton(
     onPressed: () {
       Navigator.of(context).popUntil((route) => route.isFirst);
     },
     child: Text(
       l10n.home,
       style: const TextStyle(
         color: VSPColors.textSecondary,
         fontWeight: FontWeight.w700,
       ),
     ),
   ),
 ),
 ],
 ),
 ),
 ),
 ),
 
 // Confetti Animation Overlay (Optimized UX)
 RepaintBoundary(
 child: ConfettiWidget(
 confettiController: _confettiController,
 blastDirection: pi / 2, // Down
 maxBlastForce: 10,
 minBlastForce: 3,
 emissionFrequency: 0.03,
 numberOfParticles: 10,
 gravity: 0.2,
 colors: const [
 VSPColors.accent,
 VSPColors.white,
 ],
 ),
 ),
 ],
 ),
 ),
 ),
 );
 }

 Widget _buildDetailRow(IconData icon, String label, String value, {bool isDirectionalText = false}) {
 return Row(
 children: [
 Icon(icon, color: VSPColors.accent, size: 18),
 const SizedBox(width: 10),
 Text(
 '$label: ',
 style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
 ),
 Expanded(
 child: isDirectionalText
 ? Directionality(
 textDirection: TextDirection.ltr,
 child: Text(
 value,
 textAlign: TextAlign.end,
 style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
 ),
 )
 : Text(
 value,
 textAlign: TextAlign.end,
 style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
 overflow: TextOverflow.ellipsis,
 ),
 ),
 ],
 );
 }
}


