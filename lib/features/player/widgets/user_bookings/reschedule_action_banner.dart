import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';

/// Banner shown on a booking card when the pitch owner has proposed a rescheduled match time.
class RescheduleActionBanner extends StatefulWidget {
  final Booking booking;

  const RescheduleActionBanner({
    super.key,
    required this.booking,
  });

  @override
  State<RescheduleActionBanner> createState() => _RescheduleActionBannerState();
}

class _RescheduleActionBannerState extends State<RescheduleActionBanner> {
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
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.clock_copy, color: VSPColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? ' اقتراح من المالك بنقل موعد المباراة:' : ' Pitch owner proposed a new match time:',
                  style: const TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
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
                child: CircularProgressIndicator(strokeWidth: 2.5, color: VSPColors.accent),
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
