import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../champion_podium_components.dart';

/// Hero header card showcasing tournament title, governorate, status, date, countdown, and seat capacity.
class League1v1HeroCard extends StatelessWidget {
  final String tourneyName;
  final String? governorate;
  final String status;
  final String? scheduledAt;
  final int registeredCount;
  final int targetCount;
  final int remainingCount;
  final double progress;
  final bool isArabic;

  const League1v1HeroCard({
    super.key,
    required this.tourneyName,
    required this.governorate,
    required this.status,
    required this.scheduledAt,
    required this.registeredCount,
    required this.targetCount,
    required this.remainingCount,
    required this.progress,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2614), VSPColors.surface],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: VSPColors.accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourneyName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (governorate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Iconsax.location_copy, size: 13, color: VSPColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            championTranslateItem(context, governorate.toString()),
                            style: const TextStyle(
                              color: VSPColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'registration_open' ? const Color(0xFF14301A) : const Color(0xFF332B10),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                  border: Border.all(
                    color: status == 'registration_open' ? const Color(0xFF22C55E) : const Color(0xFFEAB308),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  status == 'registration_open'
                      ? (isArabic ? 'التسجيل متاح' : 'Open')
                      : (isArabic ? 'التسجيل مغلق' : 'Closed'),
                  style: TextStyle(
                    color: status == 'registration_open' ? const Color(0xFF4ADE80) : const Color(0xFFFDE047),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date & Countdown Badges
          if (scheduledAt != null) ...[
            Row(
              children: [
                const Icon(Iconsax.calendar_1_copy, size: 16, color: VSPColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatScheduledDate(scheduledAt),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Iconsax.clock_copy, size: 16, color: VSPColors.accent),
                const SizedBox(width: 8),
                Text(
                  calculateCountdown(scheduledAt),
                  style: const TextStyle(color: VSPColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Capacity Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'المقاعد المحجوزة' : 'Seats Reserved',
                style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
              ),
              Text(
                '$registeredCount / $targetCount ($remainingCount ${isArabic ? "متبقي" : "left"})',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: VSPColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(VSPColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  static String formatScheduledDate(String? rawIso) {
    if (rawIso == null) return 'قريباً';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final dayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthNames = [
        '',
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر'
      ];
      final dayName = dayNames[dt.weekday - 1];
      final monthName = monthNames[dt.month];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dayName، ${dt.day} $monthName - $hour:$min $period';
    } catch (_) {
      return rawIso;
    }
  }

  static String calculateCountdown(String? rawIso) {
    if (rawIso == null) return '';
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'انطلقت الفعالية الآن ⏱️';
      if (diff.inDays > 0) {
        final hours = diff.inHours % 24;
        return 'متبقي ${diff.inDays} يوم و $hours ساعة';
      }
      if (diff.inHours > 0) {
        final mins = diff.inMinutes % 60;
        return 'متبقي ${diff.inHours} ساعة و $mins دقيقة';
      }
      return 'متبقي ${diff.inMinutes} دقيقة';
    } catch (_) {
      return '';
    }
  }
}
