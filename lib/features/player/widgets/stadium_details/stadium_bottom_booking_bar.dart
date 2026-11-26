import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../booking_type_modal.dart';

/// Fixed bottom bar for StadiumDetailsScreen displaying hourly price, deposit info, and "Book Now" button.
class StadiumBottomBookingBar extends StatelessWidget {
  final Stadium stadium;

  const StadiumBottomBookingBar({
    super.key,
    required this.stadium,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.fromLTRB(VSPSpacing.lg, VSPSpacing.md, VSPSpacing.lg, VSPSpacing.lg),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pricePerHour,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${stadium.basePrice.toStringAsFixed(0)} ',
                              style: Theme.of(context).textTheme.displayLarge,
                            ),
                            TextSpan(
                              text: isArabic ? 'ج.م' : 'EGP',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Iconsax.card_pos_copy, color: VSPColors.accent, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? 'دفع إلكتروني فوري 100%' : '100% Instant Online Payment',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: VSPColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: VSPSpacing.lg),
                Expanded(
                  child: PrimaryButton(
                    text: isArabic ? 'احجز الآن' : 'Book Now',
                    onPressed: () => BookingTypeModal.show(context, stadium),
                  ),
                ),
              ],
            ),          ],
        ),
      ),
    );
  }
}
