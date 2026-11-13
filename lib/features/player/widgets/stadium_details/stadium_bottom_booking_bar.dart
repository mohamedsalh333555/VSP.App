import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../booking_type_modal.dart';

/// Fixed bottom bar for StadiumDetailsScreen displaying hourly price, deposit info, and "Book Now" button.
class StadiumBottomBookingBar extends StatelessWidget {
  final Stadium stadium;
  final bool bookingEnabled;

  const StadiumBottomBookingBar({
    super.key,
    required this.stadium,
    this.bookingEnabled = true,
  });

  String _formatAmount(double value) {
    if (!value.isFinite || value < 0) return '—';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final hasDeposit = stadium.needsDeposit && stadium.depositAmount > 0.0;

    final priceDetails = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.pricePerHour,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: VSPColors.textSecondary,
              ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          // Text.rich respects the user's accessibility text scaling.
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${_formatAmount(stadium.basePrice)} ',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                TextSpan(
                  text: isArabic ? 'ج.م' : 'EGP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            softWrap: true,
          ),
        ),
        AnimatedSwitcher(
          duration: VSPDSMotion.standard,
          child: hasDeposit
              ? Row(
                  key: const ValueKey('deposit'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.lock_copy,
                      color: VSPColors.accent,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${isArabic ? 'عربون: ' : 'Deposit: '}${_formatAmount(stadium.depositAmount)} ${isArabic ? 'ج.م' : 'EGP'}',
                        softWrap: true,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: VSPColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                )
              : Text(
                  isArabic ? 'لا يوجد عربون مطلوب' : 'No deposit required',
                  key: const ValueKey('cash'),
                  softWrap: true,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: VSPColors.textSecondary,
                        fontSize: 10,
                      ),
                ),
        ),
      ],
    );

    final bookingAction = PrimaryButton(
      text: isArabic ? 'احجز الآن' : 'Book Now',
      onPressed: bookingEnabled
          ? () {
              unawaited(
                AnalyticsService.logBookingStarted(venueId: stadium.id),
              );
              BookingTypeModal.show(context, stadium);
            }
          : null,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        VSPSpacing.lg,
        VSPSpacing.md,
        VSPSpacing.lg,
        VSPSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Narrow screens and enlarged text need a full-width booking CTA.
            final enlargedText =
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final stackAction = constraints.maxWidth < 360 || enlargedText;
            if (stackAction) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  priceDetails,
                  const SizedBox(height: VSPSpacing.sm),
                  bookingAction,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: priceDetails),
                const SizedBox(width: VSPSpacing.md),
                Expanded(flex: 2, child: bookingAction),
              ],
            );
          },
        ),
      ),
    );
  }
}
