import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../data/models.dart';

/// رادار العد التنازلي الحي للمباراة في الشاشة الرئيسية (Live Match Radar Widget)
class LiveMatchRadarWidget extends StatefulWidget {
 final Function(int, {Map<String, dynamic>? arguments})? onNavigate;

 const LiveMatchRadarWidget({super.key, this.onNavigate});

 @override
 State<LiveMatchRadarWidget> createState() => _LiveMatchRadarWidgetState();
}

class _LiveMatchRadarWidgetState extends State<LiveMatchRadarWidget>
 with SingleTickerProviderStateMixin {
 late AnimationController _pulseController;
 late Animation<double> _pulseAnimation;
 Timer? _countdownTimer;
 DateTime _now = DateTime.now();

 @override
 void initState() {
 super.initState();
 _pulseController = AnimationController(
 vsync: this,
 duration: const Duration(milliseconds: 1500),
 )..repeat(reverse: true);

 _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
 CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
 );

 _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
 if (mounted) {
 setState(() => _now = DateTime.now());
 }
 });
 }

 @override
 void dispose() {
 _pulseController.dispose();
 _countdownTimer?.cancel();
 super.dispose();
 }

 Booking? _findNextActiveMatch(List<Booking> bookings) {
 if (bookings.isEmpty) return null;

 final todayMatches = bookings.where((b) {
 if (b.status == BookingStatus.cancelled) return false;
 
 // المباراة جارية حالياً
 final isLive = _now.isAfter(b.startTime) && _now.isBefore(b.endTime);
 
 // أو المباراة تبدأ خلال 6 ساعات القادمة من اليوم
 final diff = b.startTime.difference(_now);
 final isUpcomingSoon = diff.inSeconds > 0 && diff.inHours < 6;

 return isLive || isUpcomingSoon;
 }).toList();

 if (todayMatches.isEmpty) return null;

 // فرز الأقرب زمناً
 todayMatches.sort((a, b) => a.startTime.compareTo(b.startTime));
 return todayMatches.first;
 }

 String _formatRemainingTime(Duration duration, bool isArabic) {
 if (duration.isNegative) return isArabic ? 'جارية الآن ' : 'Live Now ';
 final hours = duration.inHours.toString().padLeft(2, '0');
 final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
 final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
 return '$hours:$minutes:$seconds';
 }

 void _shareMatchReminderWhatsApp(BuildContext context, Booking booking, bool isArabic) async {
 final stadiumName = booking.stadiumName.isNotEmpty ? booking.stadiumName : (isArabic ? 'الملعب' : 'Stadium');
 final timeStr = booking.formattedTimeRange;
 final message = isArabic
 ? 'تذكير بمباراتنا القادمة:\nالملعب: $stadiumName\nالموعد: $timeStr\nيرجى التواجد في الموعد المحدد.\nتم الحجز عبر تطبيق VSP'
 : 'Match Reminder:\nPitch: $stadiumName\nTime: $timeStr\nPlease be on time.\nBooked via VSP App';

 final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
 try {
 if (await canLaunchUrl(uri)) {
 await launchUrl(uri, mode: LaunchMode.externalApplication);
 } else {
 if (context.mounted) {
 VSPFeedback.showError(
 context,
 isArabic ? 'تعذر فتح واتساب.' : 'Could not launch WhatsApp.',
 );
 }
 }
 } catch (e) {
 if (context.mounted) {
 VSPFeedback.showError(context, 'Error: $e');
 }
 }
 }

 void _openGoogleMapsDirections(BuildContext context, Booking booking, bool isArabic) async {
 final stadiumName = booking.stadiumName;
 final query = Uri.encodeComponent('$stadiumName ملاعب');
 final mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

 try {
 if (await canLaunchUrl(mapsUrl)) {
 await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
 } else {
 if (context.mounted) {
 VSPFeedback.showError(
 context,
 isArabic ? 'تعذر فتح خرائط Google.' : 'Could not open Google Maps.',
 );
 }
 }
 } catch (e) {
 if (context.mounted) {
 VSPFeedback.showError(context, 'Error: $e');
 }
 }
 }

 @override
 Widget build(BuildContext context) {
 final auth = context.watch<AuthProvider>();
 if (!auth.isAuthenticated || auth.isOwner) {
 return const SizedBox.shrink();
 }

 final bookingProvider = context.watch<BookingProvider>();
 final nextMatch = _findNextActiveMatch(bookingProvider.upcomingBookings);

 if (nextMatch == null) {
 return const SizedBox.shrink();
 }

 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final isLiveNow = _now.isAfter(nextMatch.startTime) && _now.isBefore(nextMatch.endTime);
 final remainingDuration = nextMatch.startTime.difference(_now);

 return Container(
 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
 decoration: BoxDecoration(
 borderRadius: BorderRadius.circular(VSPRadius.lg),
 gradient: LinearGradient(
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 colors: [
 isLiveNow ? const Color(0xFF1E3A1A) : const Color(0xFF1A2634),
 VSPColors.surface,
 ],
 ),
 border: Border.all(
 color: isLiveNow ? VSPColors.accent : const Color(0xFF3B82F6).withValues(alpha: 0.5),
 width: 1.5,
 ),
 boxShadow: [
 BoxShadow(
 color: (isLiveNow ? VSPColors.accent : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
 blurRadius: 16,
 spreadRadius: 2,
 ),
 ],
 ),
 child: Padding(
 padding: const EdgeInsets.all(14),
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 // 1. Radar Header & Countdown
 Row(
 children: [
 ScaleTransition(
 scale: _pulseAnimation,
 child: Container(
 padding: const EdgeInsets.all(6),
 decoration: BoxDecoration(
 color: (isLiveNow ? VSPColors.accent : Colors.amber).withValues(alpha: 0.2),
 shape: BoxShape.circle,
 ),
 child: Icon(
 isLiveNow ? Iconsax.flash_1_copy : Iconsax.radar_2_copy,
 color: isLiveNow ? VSPColors.accent : Colors.amber,
 size: 18,
 ),
 ),
 ),
 const SizedBox(width: 8),
 Expanded(
 child: Column(
 crossAxisAlignment: CrossAxisAlignment.start,
 children: [
 Text(
 isLiveNow
 ? (isArabic ? ' المباراة جارية الآن!' : ' Match is LIVE NOW!')
 : (isArabic ? ' رادار المباراة القادمة' : ' Live Upcoming Match Radar'),
 style: TextStyle(
 color: isLiveNow ? VSPColors.accent : Colors.amber,
 fontWeight: FontWeight.w900,
 fontSize: 13,
 ),
 ),
 Text(
 nextMatch.stadiumName.isNotEmpty ? nextMatch.stadiumName : (isArabic ? 'ملعب VSP' : 'VSP Stadium'),
 style: const TextStyle(
 color: Colors.white,
 fontWeight: FontWeight.bold,
 fontSize: 15,
 ),
 maxLines: 1,
 overflow: TextOverflow.ellipsis,
 ),
 ],
 ),
 ),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
 decoration: BoxDecoration(
 color: Colors.black.withValues(alpha: 0.5),
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(
 color: (isLiveNow ? VSPColors.accent : Colors.white30).withValues(alpha: 0.3),
 ),
 ),
 child: Row(
 mainAxisSize: MainAxisSize.min,
 children: [
 Icon(
 Iconsax.timer_1_copy,
 size: 13,
 color: isLiveNow ? VSPColors.accent : VSPColors.textSecondary,
 ),
 const SizedBox(width: 4),
 Text(
 _formatRemainingTime(remainingDuration, isArabic),
 style: TextStyle(
 color: isLiveNow ? VSPColors.accent : Colors.white,
 fontWeight: FontWeight.w900,
 fontSize: 12,
 fontFamily: 'monospace',
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 const SizedBox(height: 10),

 // 2. Info Row (Time + Type)
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
 decoration: BoxDecoration(
 color: Colors.white.withValues(alpha: 0.05),
 borderRadius: BorderRadius.circular(8),
 ),
 child: Row(
 children: [
 const Icon(Iconsax.clock_copy, size: 14, color: VSPColors.textSecondary),
 const SizedBox(width: 6),
 Text(
 nextMatch.formattedTimeRange,
 style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 const Spacer(),
 Container(
 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
 decoration: BoxDecoration(
 color: VSPColors.accent.withValues(alpha: 0.15),
 borderRadius: BorderRadius.circular(4),
 ),
 child: Text(
 nextMatch.bookingType == BookingType.challenge
 ? (isArabic ? 'تحدي فرق' : 'Challenge')
 : (isArabic ? 'حجز خماسي' : '5v5 Booking'),
 style: const TextStyle(color: VSPColors.accent, fontSize: 10, fontWeight: FontWeight.bold),
 ),
 ),
 ],
 ),
 ),
 const SizedBox(height: 12),

 // 3. Action Buttons
 Row(
 children: [
 // Google Maps Button
 Expanded(
 child: OutlinedButton.icon(
 style: OutlinedButton.styleFrom(
 foregroundColor: Colors.white,
 side: const BorderSide(color: VSPColors.divider),
 padding: const EdgeInsets.symmetric(vertical: 8),
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 backgroundColor: VSPColors.surfaceAlt,
 ),
 icon: const Icon(Iconsax.location_copy, size: 14, color: VSPColors.accent),
 label: Text(
 isArabic ? 'اللوكيشن' : 'Map',
 style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 onPressed: () => _openGoogleMapsDirections(context, nextMatch, isArabic),
 ),
 ),
 const SizedBox(width: 8),

 // WhatsApp Squad Reminder Button
 Expanded(
 child: ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.2),
 foregroundColor: const Color(0xFF25D366),
 padding: const EdgeInsets.symmetric(vertical: 8),
 elevation: 0,
 shape: RoundedRectangleBorder(
 borderRadius: BorderRadius.circular(8),
 side: const BorderSide(color: Color(0xFF25D366), width: 0.8),
 ),
 ),
 icon: const Icon(Iconsax.messages_2_copy, size: 14),
 label: Text(
 isArabic ? 'تذكير الفريق' : 'WhatsApp',
 style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
 ),
 onPressed: () => _shareMatchReminderWhatsApp(context, nextMatch, isArabic),
 ),
 ),
 const SizedBox(width: 8),

 // Details Button
 IconButton(
 visualDensity: VisualDensity.compact,
 style: IconButton.styleFrom(
 backgroundColor: VSPColors.surfaceAlt,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
 ),
 icon: const Icon(Iconsax.arrow_left_2_copy, size: 16, color: Colors.white),
 tooltip: isArabic ? 'عرض الحجوزات' : 'View Bookings',
 onPressed: () {
 if (widget.onNavigate != null) {
 widget.onNavigate!(3); // Navigate to Bookings Tab (index 3)
 }
 },
 ),
 ],
 ),
 ],
 ),
 ),
 );
 }
}
