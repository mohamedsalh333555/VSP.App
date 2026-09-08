import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

/// Reusable framed progress bar item with title, percentage, formatted amount, and custom color.
class FramedMetricProgressBar extends StatelessWidget {
  final String title;
  final double amount;
  final double percentage;
  final Color color;
  final bool isArabic;
  final String? unit;

  const FramedMetricProgressBar({
    super.key,
    required this.title,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.isArabic,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final displayUnit = unit ?? (isArabic ? 'ج.م' : 'EGP');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${percentage.toStringAsFixed(0)}%)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${amount.toStringAsFixed(0)} $displayUnit',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (percentage / 100.0).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: const Color(0xFF27272A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// Card showing revenue breakdown by collection method: Digital/Online vs Cash on arrival.
class InsightsRevenueSourcesCard extends StatelessWidget {
  final double digitalRevenue;
  final double digitalPct;
  final double cashRevenue;
  final double cashPct;
  final bool isArabic;

  const InsightsRevenueSourcesCard({
    super.key,
    required this.digitalRevenue,
    required this.digitalPct,
    required this.cashRevenue,
    required this.cashPct,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.wallet_3_copy, size: 15, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'طرق التحصيل والإيراد' : 'COLLECTION & PAYMENT METHODS',
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FramedMetricProgressBar(
            title: isArabic ? 'دفع إلكتروني ورقمي' : 'Digital & Online',
            amount: digitalRevenue,
            percentage: digitalPct,
            color: VSPColors.accent,
            isArabic: isArabic,
          ),
          const SizedBox(height: 14),
          FramedMetricProgressBar(
            title: isArabic ? 'تحصيل كاش ونقدي' : 'Cash on Arrival',
            amount: cashRevenue,
            percentage: cashPct,
            color: Colors.white70,
            isArabic: isArabic,
          ),
        ],
      ),
    );
  }
}
