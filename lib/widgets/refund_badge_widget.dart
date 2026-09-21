import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../core/ui/tokens/vsp_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/refund_info.dart';

class RefundBadgeWidget extends StatelessWidget {
  final RefundInfo refundInfo;

  const RefundBadgeWidget({super.key, required this.refundInfo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n == null || Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeText = l10n != null ? refundInfo.localizedBadgeText(l10n) : refundInfo.badgeText;
    final etaText = l10n != null ? refundInfo.localizedEtaText(l10n) : refundInfo.etaText;
    final copyToastText = l10n?.refIdCopied ?? 'تم نسخ رقم الإيصال';
    final Color channelColor = _channelColor(refundInfo.channel);

    final Color refTextColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF4B5563);
    final Color hintTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // البادج الرئيسي
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: channelColor.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: channelColor.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: channelColor,
            ),
          ),
        ),

        // رقم الإيصال (لو موجود)
        if (refundInfo.hasReference) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: refundInfo.refundTransactionId!),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Iconsax.tick_circle_copy, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(copyToastText),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.receipt_item_copy,
                  size: 13,
                  color: hintTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Ref: #${refundInfo.refundTransactionId}',
                  style: TextStyle(
                    fontSize: 11,
                    color: refTextColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Iconsax.copy_copy,
                  size: 11,
                  color: hintTextColor.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ],

        // الوقت المتوقع (لبطاقات البنك فقط)
        if (refundInfo.channel == RefundChannel.card) ...[
          const SizedBox(height: 4),
          Text(
            '$etaText ${isArabic ? 'للظهور في بنكك' : 'to reflect in your bank'}',
            style: TextStyle(
              fontSize: 11,
              color: hintTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Color _channelColor(RefundChannel channel) => switch (channel) {
    RefundChannel.wallet => const Color(0xFF10B981), // Green
    RefundChannel.card   => const Color(0xFF3B82F6), // Blue
    RefundChannel.cash   => VSPColors.accent, // Primary Green
  };
}
