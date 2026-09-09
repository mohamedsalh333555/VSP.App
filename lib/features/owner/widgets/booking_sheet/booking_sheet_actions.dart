import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/booking_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import 'booking_sheet_action_panels.dart';

export 'booking_sheet_action_panels.dart';

/// Banner shown when a booking is currently ongoing, offering quick +30 min extension.
class OngoingMatchBanner extends StatelessWidget {
  final Booking booking;
  final bool isSaving;
  final VoidCallback onExtendMatch;

  const OngoingMatchBanner({
    super.key,
    required this.booking,
    required this.isSaving,
    required this.onExtendMatch,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VSPColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Iconsax.timer_start_copy, color: VSPColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'المباراة جارية الآن ' : 'Match Ongoing Now ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onExtendMatch,
            icon: const Icon(Iconsax.add_circle_copy, size: 14),
            label: Text(
              isArabic ? 'تمديد (+30د) ⏱' : 'Extend (+30m) ⏱',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick action buttons for upcoming online paid bookings (Reschedule & Emergency Close).
class UpcomingOnlinePaidActions extends StatelessWidget {
  final Booking booking;

  const UpcomingOnlinePaidActions({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Iconsax.clock_copy, size: 16),
              label: Text(
                isArabic ? 'ترحيل موعد ' : 'Reschedule ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: booking.startTime.add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (pickedDate == null || !context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(booking.startTime),
                );
                if (pickedTime == null || !context.mounted) return;
                final newStart = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                final duration = booking.endTime.difference(booking.startTime);
                final newEnd = newStart.add(duration);

                final ok = await Provider.of<BookingProvider>(context, listen: false)
                    .requestReschedule(
                  bookingId: booking.id,
                  newStartTime: newStart,
                  newEndTime: newEnd,
                );
                if (ok && context.mounted) {
                  VSPFeedback.showSuccess(
                    context,
                    isArabic
                        ? 'تم إرسال اقتراح الموعد الجديد للاعب بنجاح '
                        : 'Reschedule proposal sent to player ',
                  );
                  if (booking.playerPhone != null && booking.playerPhone!.isNotEmpty) {
                    launchUrl(Uri.parse('tel:${booking.playerPhone}'));
                  }
                  Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: VSPColors.error,
                side: const BorderSide(color: VSPColors.error),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Iconsax.danger_copy, size: 16),
              label: Text(
                isArabic ? 'إغلاق طارئ ' : 'Emergency Close ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () async {
                final res = await Provider.of<BookingProvider>(context, listen: false)
                    .requestEmergencyClosure(
                  stadiumId: booking.stadiumId,
                  ownerId: booking.ownerId,
                  reason: 'عطل طارئ وصيانة بالملعب',
                  durationHours: 24,
                );
                if (context.mounted) {
                  if (res['success'] == true) {
                    VSPFeedback.showSuccess(
                      context,
                      isArabic
                          ? 'تم إغلاق الملعب مؤقتاً وتحويل طلبات الاسترداد للأدمن '
                          : 'Stadium temporarily closed for emergency ',
                    );
                    Navigator.pop(context);
                  } else {
                    VSPFeedback.showError(
                      context,
                      res['message'] ?? 'فشل طلب الإغلاق الطارئ',
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action buttons for the booking sheet modal, adapting to booking payment and lifecycle state.
class BookingSheetBottomActions extends StatelessWidget {
  final Booking? booking;
  final bool isEdit;
  final bool isPastCompleted;
  final bool isUpcomingPendingCash;
  final bool isUpcomingOnlinePaid;
  final bool isSaving;
  final bool isDeleting;
  final VoidCallback onConfirmCashPayment;
  final VoidCallback onCancelBooking;
  final VoidCallback onConfirmBooking;

  const BookingSheetBottomActions({
    super.key,
    required this.booking,
    required this.isEdit,
    required this.isPastCompleted,
    required this.isUpcomingPendingCash,
    required this.isUpcomingOnlinePaid,
    required this.isSaving,
    required this.isDeleting,
    required this.onConfirmCashPayment,
    required this.onCancelBooking,
    required this.onConfirmBooking,
  });

  @override
  Widget build(BuildContext context) {
    if (isPastCompleted && booking != null) {
      return BookingSheetPastPanel(
        booking: booking!,
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
      );
    }
    if (isUpcomingPendingCash && booking != null) {
      return BookingSheetCashPanel(
        booking: booking!,
        isSaving: isSaving,
        isDeleting: isDeleting,
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
        onConfirmCashPayment: onConfirmCashPayment,
        onCancelBooking: onCancelBooking,
      );
    }
    return BookingSheetDefaultPanel(
      booking: booking,
      isEdit: isEdit,
      isUpcomingOnlinePaid: isUpcomingOnlinePaid,
      isSaving: isSaving,
      isArabic: Localizations.localeOf(context).languageCode == 'ar',
      onConfirmBooking: onConfirmBooking,
    );
  }
}

