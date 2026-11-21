import 'package:flutter/material.dart';

import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Summarises the existing client-visible cancellation policy before checkout.
/// This is informational; the server remains the authority for eligibility
/// and refunds. Keep wording in sync with booking cancellation error copy.
class BookingCancellationPolicyNote extends StatelessWidget {
  const BookingCancellationPolicyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: VSPColors.textSecondary,
        collapsedIconColor: VSPColors.textSecondary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'سياسة إلغاء الحجز' : 'Booking cancellation policy',
              style: const TextStyle(
                fontSize: 13,
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic
                  ? 'يمكنك الإلغاء قبل موعد المباراة بأكثر من 6 ساعات، أو خلال أول 20 دقيقة من الحجز.'
                  : 'Cancel more than 6 hours before kickoff, or within the first 20 minutes after booking.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: VSPColors.textSecondary,
              ),
            ),
          ],
        ),
        children: [
          Text(
            isArabic
                ? 'بعد مرور أول 20 دقيقة، لا يُقبل الإلغاء إذا كان متبقيًا 6 ساعات أو أقل على موعد المباراة. يحدد الخادم أهلية الإلغاء ومبلغ الاسترداد حسب حالة الحجز والدفع؛ وقد يظل الاسترداد الإلكتروني قيد المعالجة.'
                : 'After the first 20 minutes, cancellation is unavailable when 6 hours or less remain before kickoff. The server determines cancellation and refund eligibility based on booking and payment status; an online refund may still be pending.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: VSPColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
