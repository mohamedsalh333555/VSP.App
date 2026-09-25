import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'booking_sheet_whatsapp_utils.dart';

/// Past/completed branch of [BookingSheetBottomActions].
class BookingSheetPastPanel extends StatelessWidget {
  final Booking booking;
  final bool isArabic;
  final VoidCallback? onConfirmCashPayment;
  final bool isSaving;

  const BookingSheetPastPanel({
    super.key,
    required this.booking,
    required this.isArabic,
    this.onConfirmCashPayment,
    this.isSaving = false,
  });

  @override
  Widget build(BuildContext context) {
    final remainingCash = (booking.totalPrice - booking.depositPaid).clamp(0.0, 999999.0);
    final isHybrid = booking.depositPaid > 0 && booking.depositPaid < booking.totalPrice;
    final isPendingCash = !booking.isPaid && (booking.paymentStatus != 'paid');

    final String cashBtnText = isHybrid
        ? (isArabic
            ? 'تأكيد استلام المتبقي (${remainingCash.toInt()} ج.م) كاش '
            : 'Confirm Remaining (${remainingCash.toInt()} EGP) Cash ')
        : (isArabic
            ? 'تأكيد استلام كامل المبلغ (${booking.totalPrice.toInt()} ج.م) كاش '
            : 'Confirm Full Cash (${booking.totalPrice.toInt()} EGP) ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isPendingCash && onConfirmCashPayment != null) ...[
          SizedBox(
            width: double.infinity,
            height: VSPSize.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : onConfirmCashPayment,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Iconsax.money_send_copy, size: 18),
              label: Text(
                cashBtnText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (isPendingCash) ...[
          SizedBox(
            width: double.infinity,
            height: VSPSize.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () =>
                  BookingSheetWhatsAppUtils.launchWhatsAppSupport(booking, isArabic),
              icon: const Icon(Iconsax.user_remove_copy, size: 18),
              label: Text(
                isArabic
                    ? 'تسجيل عدم حضور اللاعب (No-Show) '
                    : 'Report Player No-Show ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.warning.withValues(alpha: 0.15),
                foregroundColor: VSPColors.warning,
                side: const BorderSide(color: VSPColors.warning, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: VSPSize.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: () => BookingSheetWhatsAppUtils.sendWhatsAppReceipt(
                      context, booking, isArabic),
                  icon: const Icon(Iconsax.document_text_copy, size: 18),
                  label: Text(
                    isArabic ? 'إرسال الوصل ' : 'Send Receipt ',
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.success.withValues(alpha: 0.15),
                    foregroundColor: VSPColors.success,
                    side: const BorderSide(color: VSPColors.success, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: VSPSize.buttonHeight,
                child: PrimaryButton(
                  text: isArabic ? 'إغلاق ' : 'Close ',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Upcoming cash-pending branch of [BookingSheetBottomActions].
class BookingSheetCashPanel extends StatelessWidget {
  final Booking booking;
  final bool isSaving;
  final bool isDeleting;
  final bool isArabic;
  final VoidCallback onConfirmCashPayment;
  final VoidCallback onCancelBooking;

  const BookingSheetCashPanel({
    super.key,
    required this.booking,
    required this.isSaving,
    required this.isDeleting,
    required this.isArabic,
    required this.onConfirmCashPayment,
    required this.onCancelBooking,
  });

  @override
  Widget build(BuildContext context) {
    final remainingCash = (booking.totalPrice - booking.depositPaid).clamp(0.0, 999999.0);
    final isHybrid = booking.depositPaid > 0 && booking.depositPaid < booking.totalPrice;
    final String cashBtnText = isHybrid
        ? (isArabic
            ? 'تأكيد استلام المتبقي (${remainingCash.toInt()} ج.م) كاش بالملعب '
            : 'Confirm Remaining (${remainingCash.toInt()} EGP) Cash at Pitch ')
        : (isArabic
            ? 'تأكيد استلام كامل المبلغ (${booking.totalPrice.toInt()} ج.م) كاش بالملعب '
            : 'Confirm Full Cash (${booking.totalPrice.toInt()} EGP) at Pitch ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: VSPSize.buttonHeight,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : onConfirmCashPayment,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Iconsax.money_send_copy, size: 18),
            label: Text(
              cashBtnText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VSPColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VSPRadius.md)),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: VSPSize.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final phone = booking.playerPhone ?? '';
                    if (phone.isNotEmpty) {
                      launchUrl(Uri.parse(
                          'https://wa.me/${phone.replaceAll('+', '').replaceAll(' ', '')}'));
                    } else {
                      BookingSheetWhatsAppUtils.launchWhatsAppSupport(
                          booking, isArabic);
                    }
                  },
                  icon: const Icon(Iconsax.message_copy, size: 16),
                  label: Text(
                    isArabic ? 'تأكيد عبر واتساب ' : 'Confirm via WhatsApp ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.info,
                    side: const BorderSide(color: VSPColors.info),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: VSPSize.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: isDeleting ? null : onCancelBooking,
                  icon: const Icon(Iconsax.close_circle_copy, size: 16),
                  label: Text(
                    isArabic ? 'إلغاء الحجز ' : 'Cancel Slot ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VSPColors.error,
                    side: const BorderSide(color: VSPColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Default/edit branch of [BookingSheetBottomActions].
class BookingSheetDefaultPanel extends StatelessWidget {
  final Booking? booking;
  final bool isEdit;
  final bool isUpcomingOnlinePaid;
  final bool isSaving;
  final bool isArabic;
  final VoidCallback onConfirmBooking;

  const BookingSheetDefaultPanel({
    super.key,
    required this.booking,
    required this.isEdit,
    required this.isUpcomingOnlinePaid,
    required this.isSaving,
    required this.isArabic,
    required this.onConfirmBooking,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isEdit && booking != null) ...[
          SizedBox(
            width: double.infinity,
            height: VSPSize.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => BookingSheetWhatsAppUtils.sendWhatsAppReceipt(
                  context, booking!, isArabic),
              icon: const Icon(Iconsax.document_text_copy, size: 18),
              label: Text(
                isArabic
                    ? 'إرسال وصل الحجز الإلكتروني '
                    : 'Send WhatsApp Digital Receipt ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.success.withValues(alpha: 0.15),
                foregroundColor: VSPColors.success,
                side: const BorderSide(color: VSPColors.success, width: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: VSPSize.buttonHeight,
                child: PrimaryButton(
                  text: (isEdit && isUpcomingOnlinePaid)
                      ? (isArabic ? 'إبلاغ الدعم (واتساب)' : 'Report Issue')
                      : l10n.cancelBtn,
                  color: VSPColors.surfaceAlt,
                  textColor: (isEdit && isUpcomingOnlinePaid)
                      ? VSPColors.warning
                      : VSPColors.textPrimary,
                  onPressed: isSaving
                      ? null
                      : () {
                          if (isEdit && isUpcomingOnlinePaid && booking != null) {
                            BookingSheetWhatsAppUtils.launchWhatsAppSupport(
                                booking!, isArabic);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                ),
              ),
            ),
            if (!isUpcomingOnlinePaid) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: VSPSize.buttonHeight,
                  child: PrimaryButton(
                    text: isEdit ? l10n.update : l10n.confirmBtn,
                    isLoading: isSaving,
                    onPressed: isSaving ? null : onConfirmBooking,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
