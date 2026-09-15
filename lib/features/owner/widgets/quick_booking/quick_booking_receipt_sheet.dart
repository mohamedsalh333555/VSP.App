import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/vsp_quick_booking_receipt_formatter.dart';
import '../../../../data/models.dart';
import '../../../../shared/widgets/primary_button.dart';

void showQuickBookingReceiptSheet({
  required BuildContext context,
  required Stadium stadium,
  required String bookingRef,
  required String customerName,
  required String customerPhone,
  required DateTime startTime,
  required DateTime endTime,
  required double totalPrice,
  required double paidAmount,
  required bool isAr,
}) {
  final receiptMsg = VSPQuickBookingReceiptFormatter.buildReceiptMessage(
    stadiumName: stadium.name,
    bookingRef: bookingRef,
    customerName: customerName,
    startTime: startTime,
    endTime: endTime,
    totalPrice: totalPrice,
    depositPaid: paidAmount,
    googleMapsUrl: stadium.googleMapsUrl,
    stadiumPhone: stadium.phone,
    isArabic: isAr,
  );

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      final bottomPadding = MediaQuery.of(sheetCtx).padding.bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.lg,
          VSPSpacing.lg,
          VSPSpacing.lg,
          bottomPadding > 0 ? bottomPadding + 12 : 24,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VSPColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: VSPColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              isAr ? 'تم تأكيد الحجز بنجاح!' : 'Booking Confirmed!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'هل تود إرسال إيصال وتفاصيل الحجز للكابتن $customerName عبر واتساب؟'
                  : 'Would you like to send WhatsApp confirmation receipt to $customerName?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: isAr ? 'إرسال إيصال الحجز عبر واتساب' : 'Send WhatsApp Receipt',
              height: 48,
              icon: Iconsax.message_copy,
              onPressed: () async {
                Navigator.pop(sheetCtx);
                await VSPQuickBookingReceiptFormatter.sendReceiptToCustomer(
                  context: context,
                  phone: customerPhone,
                  receiptMessage: receiptMsg,
                );
              },
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              text: isAr ? 'تم، إغلاق' : 'Done / Close',
              height: 48,
              color: VSPColors.surfaceAlt,
              textColor: Colors.white,
              onPressed: () => Navigator.pop(sheetCtx),
            ),
          ],
        ),
      );
    },
  );
}
