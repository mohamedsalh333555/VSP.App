import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class FilterPricePanel extends StatelessWidget {
  final RangeValues priceRange;
  final bool noDepositOnly;
  final double maxDbPrice;
  final bool isArabic;
  final String currency;
  final ValueChanged<RangeValues> onPriceChanged;
  final ValueChanged<bool> onNoDepositChanged;

  const FilterPricePanel({
    super.key,
    required this.priceRange,
    required this.noDepositOnly,
    required this.maxDbPrice,
    required this.isArabic,
    required this.currency,
    required this.onPriceChanged,
    required this.onNoDepositChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMax = maxDbPrice > 0 ? maxDbPrice : 2000.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isArabic ? 'السعر بالساعة' : 'Price / Hour',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            Text(
              '${priceRange.start.round()} - ${priceRange.end.round()} $currency',
              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isArabic
              ? 'الحد الأقصى يعتمد على أعلى سعر مسجل (${effectiveMax.round()} ج.م)'
              : 'Max based on registered stadiums (${effectiveMax.round()} EGP)',
          style: const TextStyle(color: VSPColors.textSecondary, fontSize: 10.5),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: VSPColors.accent,
            inactiveTrackColor: Colors.white10,
            thumbColor: VSPColors.accent,
            overlayColor: VSPColors.accent.withValues(alpha: 0.2),
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: RangeSlider(
            values: RangeValues(
              priceRange.start.clamp(0, effectiveMax),
              priceRange.end.clamp(0, effectiveMax),
            ),
            min: 0,
            max: effectiveMax,
            divisions: (effectiveMax / 50).clamp(1, 100).toInt(),
            labels: RangeLabels(
              priceRange.start.round().toString(),
              priceRange.end.round().toString(),
            ),
            onChanged: onPriceChanged,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(color: VSPColors.divider),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: noDepositOnly,
              activeColor: VSPColors.accent,
              checkColor: Colors.black,
              onChanged: (val) => onNoDepositChanged(val ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onNoDepositChanged(!noDepositOnly),
                child: Text(
                  isArabic ? 'ملاعب بدون عربون (دفع نقدي مباشر)' : 'No Deposit Required (Cash On Arrival)',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
