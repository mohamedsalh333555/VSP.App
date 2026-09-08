import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';
import '../../radial_tick_gauge_painter.dart';

/// Hero card for Pro Insights featuring a custom radial tick dial gauge and 2-column comparative metrics.
class InsightsRadialHeroCard extends StatelessWidget {
  final double currentRevenue;
  final double previousRevenue;
  final double revenueChange;
  final double ringProgress;
  final double maxCapacityRevenue;
  final String periodLabel;
  final String comparisonLabel;
  final bool isArabic;

  const InsightsRadialHeroCard({
    super.key,
    required this.currentRevenue,
    required this.previousRevenue,
    required this.revenueChange,
    required this.ringProgress,
    required this.maxCapacityRevenue,
    required this.periodLabel,
    required this.comparisonLabel,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = revenueChange > 0;
    final bool isNegative = revenueChange < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Column(
        children: [
          // Radial Tick Dial Gauge
          SizedBox(
            width: 172,
            height: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(172, 172),
                  painter: RadialTickGaugePainter(
                    progress: ringProgress.clamp(0.0, 1.0),
                    activeColor: VSPColors.accent,
                    inactiveColor: const Color(0xFF27272A),
                    totalTicks: 52,
                    tickLength: 13.5,
                    strokeWidth: 2.3,
                  ),
                ),
                // Center Stats
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currentRevenue.toStringAsFixed(0),
                        style: const TextStyle(
                          color: VSPColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic ? 'جنيه $periodLabel' : 'EGP $periodLabel',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Balanced 2-Column Micro-Stats Strip
          Row(
            children: [
              // 1. Comparison with previous period
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Iconsax.trend_up_copy
                            : (isNegative ? Iconsax.trend_down_copy : Iconsax.minus_copy),
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPositive
                                  ? '+${revenueChange.toStringAsFixed(1)}% ${isArabic ? "نمو" : "Growth"}'
                                  : (isNegative
                                      ? '-${revenueChange.abs().toStringAsFixed(1)}% ${isArabic ? "تراجع" : "Drop"}'
                                      : (isArabic ? 'أداء مستقر' : 'Stable')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} ج.م'
                                  : '$comparisonLabel: ${previousRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Maximum capacity for the period
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.flash_1_copy,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? '${(ringProgress * 100).toInt()}% إشغال'
                                  : '${(ringProgress * 100).toInt()}% Occupancy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isArabic
                                  ? 'القصوى: ${maxCapacityRevenue.toStringAsFixed(0)} ج.م'
                                  : 'Max: ${maxCapacityRevenue.toStringAsFixed(0)} EGP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
