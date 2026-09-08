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
    final hasDeposit = stadium.depositAmount > 0.0;

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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: hasDeposit
                          ? Row(
                              key: const ValueKey('deposit'),
                              children: [
                                const Icon(Iconsax.lock_copy, color: VSPColors.accent, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  '${isArabic ? 'عربون: ' : 'Deposit: '}${stadium.depositAmount.toInt()} ${isArabic ? 'ج.م' : 'EGP'}',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: VSPColors.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('cash'),
                              children: [
                                Text(
                                  isArabic ? 'ادفع نقداً في الملعب' : 'Pay cash at stadium',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: VSPColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ),
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
            ),
          ],
        ),
      ),
    );
  }
}
