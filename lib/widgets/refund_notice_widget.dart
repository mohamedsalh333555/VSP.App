import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/refund_info.dart';

class RefundNoticeWidget extends StatelessWidget {
  final RefundInfo refundInfo;
  final String amountFormatted;

  const RefundNoticeWidget({
    super.key,
    required this.refundInfo,
    required this.amountFormatted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n == null || Localizations.localeOf(context).languageCode == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final noticeText = l10n != null
        ? refundInfo.localizedNoticeText(
            l10n,
            isArabic ? 'المبلغ' : 'Payment',
            amountFormatted,
          )
        : refundInfo.refundNoticeText(amountFormatted);

    final etaText = l10n != null ? refundInfo.localizedEtaText(l10n) : refundInfo.etaText;
    final timelineLabel = isArabic ? 'المدة المتوقعة' : 'Expected timeline';

    final Color color = _channelColor(refundInfo.channel);
    final Color textColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1F2937);
    final Color subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _channelIcon(refundInfo.channel),
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noticeText,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Iconsax.clock_copy,
                      size: 13,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$timelineLabel: $etaText',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _channelColor(RefundChannel channel) => switch (channel) {
    RefundChannel.wallet => const Color(0xFF10B981), // Green / Emerald
    RefundChannel.card   => const Color(0xFF3B82F6), // Blue
    RefundChannel.cash   => const Color(0xFFF59E0B), // Orange / Amber
  };

  String _channelIcon(RefundChannel channel) => switch (channel) {
    RefundChannel.wallet => '',
    RefundChannel.card   => '',
    RefundChannel.cash   => '',
  };
}
