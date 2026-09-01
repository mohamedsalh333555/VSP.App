import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/vsp_feedback.dart';
import '../../core/utils/app_date_formatter.dart';
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
    if (duration.isNegative) return isArabic ? 'جارية الآن' : 'Live Now';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatMatchTimeRange(DateTime start, DateTime end, String locale) {
    final startFormatted = AppDateFormatter.formatTime(start, locale);
    final endFormatted = AppDateFormatter.formatTime(end, locale);
    return '$startFormatted - $endFormatted';
  }

  void _shareMatchReminderWhatsApp(BuildContext context, Booking booking, bool isArabic, String locale) async {
    final stadiumName = booking.stadiumName.isNotEmpty ? booking.stadiumName : (isArabic ? 'الملعب' : 'Stadium');
    final timeStr = _formatMatchTimeRange(booking.startTime, booking.endTime, locale);
    final message = isArabic
        ? 'تذكير بمباراتنا القادمة:\n• الملعب: $stadiumName\n• الموعد: $timeStr\n• يرجى التواجد في الموعد المحدد.\nتم الحجز عبر تطبيق VSP'
        : 'Match Reminder:\n• Pitch: $stadiumName\n• Time: $timeStr\n• Please be on time.\nBooked via VSP App';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          VSPFeedback.showError(
            context,
            isArabic ? 'تعذر فتح تطبيق واتساب.' : 'Could not launch WhatsApp.',
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

    final locale = Localizations.localeOf(context).languageCode;
    final isArabic = locale == 'ar';
    final isLiveNow = _now.isAfter(nextMatch.startTime) && _now.isBefore(nextMatch.endTime);
    final remainingDuration = nextMatch.startTime.difference(_now);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onNavigate != null) {
          widget.onNavigate!(3); // Navigate to Bookings tab
        }
      },
      borderRadius: BorderRadius.circular(VSPRadius.xl),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.xl),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              VSPColors.surface,
              VSPColors.surfaceAlt,
            ],
          ),
          border: Border.all(
            color: isLiveNow
                ? VSPColors.accent
                : VSPColors.accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: VSPColors.accent.withValues(alpha: isLiveNow ? 0.2 : 0.08),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Status, Stadium Name & Countdown Pill
            Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VSPColors.accent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isLiveNow ? Iconsax.flash_1_copy : Iconsax.radar_2_copy,
                      color: VSPColors.accent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLiveNow
                            ? (isArabic ? 'مباراة جارية الآن' : 'Match Live Now')
                            : (isArabic ? 'المباراة القادمة' : 'Upcoming Match'),
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextMatch.stadiumName.isNotEmpty
                            ? nextMatch.stadiumName
                            : (isArabic ? 'ملعب VSP' : 'VSP Stadium'),
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
                // Sleek Digital Countdown Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: VSPColors.background,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: isLiveNow
                          ? VSPColors.accent
                          : VSPColors.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.timer_1_copy,
                        size: 13,
                        color: VSPColors.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatRemainingTime(remainingDuration, isArabic),
                        style: const TextStyle(
                          color: VSPColors.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Cohesive Match Details Bar (Time Range & Match Type)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: VSPColors.divider.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Iconsax.clock_copy,
                    size: 15,
                    color: VSPColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatMatchTimeRange(nextMatch.startTime, nextMatch.endTime, locale),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(VSPRadius.sm),
                    ),
                    child: Text(
                      nextMatch.bookingType == BookingType.challenge
                          ? (isArabic ? 'تحدي فرق' : 'Challenge')
                          : (isArabic ? 'حجز خماسي' : '5v5 Match'),
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Balanced Dual Action Buttons
            Row(
              children: [
                // Location Button
                Expanded(
                  child: InkWell(
                    onTap: () => _openGoogleMapsDirections(context, nextMatch, isArabic),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: VSPColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(
                          color: VSPColors.divider,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Iconsax.location_copy,
                            size: 15,
                            color: VSPColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isArabic ? 'اللوكيشن والاتجاهات' : 'Directions',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Squad WhatsApp Share Button
                Expanded(
                  child: InkWell(
                    onTap: () => _shareMatchReminderWhatsApp(context, nextMatch, isArabic, locale),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: VSPColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        border: Border.all(
                          color: VSPColors.accent.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Iconsax.share_copy,
                            size: 15,
                            color: VSPColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isArabic ? 'تذكير الفريق' : 'Share Squad',
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
