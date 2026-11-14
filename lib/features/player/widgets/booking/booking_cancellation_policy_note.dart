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
        title: Text(
          isArabic ? 'سياسة إلغاء الحجز' : 'Booking cancellation policy',
          style: const TextStyle(
            fontSize: 13,
            color: VSPColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            isArabic
                ? 'حسب السياسة المعروضة في التطبيق، لا يُقبل الإلغاء قبل موعد المباراة بأقل من 6 ساعات، إلا خلال أول 20 دقيقة من إنشاء الحجز. يحدد الخادم أهلية الإلغاء والاسترداد حسب حالة الحجز.'
                : 'Under the policy displayed in the app, cancellation is unavailable within 6 hours of the match, except during the first 20 minutes after booking. The server determines cancellation and refund eligibility.',
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
