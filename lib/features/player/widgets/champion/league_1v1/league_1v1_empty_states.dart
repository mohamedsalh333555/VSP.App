import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_design_tokens.dart';
import '../../../../../shared/widgets/primary_button.dart';
import '../champion_podium_components.dart';
import '../champion_empty_state.dart';

/// Displayed when a user does not have a home governorate set in their profile.
class League1v1NoGovernorateState extends StatelessWidget {
  final bool isArabic;

  const League1v1NoGovernorateState({
    super.key,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPDSSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: VSPDSizes.stateIconBox,
              height: VSPDSizes.stateIconBox,
              decoration: BoxDecoration(
                color: VSPDSColors.zinc800,
                borderRadius: BorderRadius.circular(VSPDSRadius.md),
                border: Border.all(color: VSPDSColors.zinc750),
              ),
              child: const Icon(Iconsax.location_slash_copy, size: VSPDSizes.emptyIconSize, color: VSPDSColors.zinc400),
            ),
            const SizedBox(height: VSPDSSpacing.md),
            Text(
              isArabic ? 'يرجى تحديد محافظتك من الملف الشخصي' : 'Please set your governorate in profile',
              textAlign: TextAlign.center,
              style: VSPDSTypography.titleMedium,
            ),
            const SizedBox(height: VSPDSSpacing.xs),
            Text(
              isArabic
                  ? 'حدد محافظتك لمشاهدة بطولات منطقتك والمشاركة بها'
                  : 'Set your home governorate to view and join local 1v1 tournaments',
              textAlign: TextAlign.center,
              style: VSPDSTypography.stateBody,
            ),
            const SizedBox(height: VSPDSSpacing.md),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: isArabic ? 'تحديد المحافظة الآن' : 'Set Governorate',
                icon: Iconsax.edit_2_copy,
                onPressed: () => context.push('/edit-profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displayed when there is no active 1v1 tournament in the selected location.
class League1v1NoTournamentState extends StatelessWidget {
  final String locationName;
  final bool isArabic;

  const League1v1NoTournamentState({
    super.key,
    required this.locationName,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return ChampionEmptyState(
      icon: Iconsax.user_copy,
      titleArabic: 'لا توجد بطولة واحد ضد واحد حالياً',
      titleEnglish: 'No active 1vs1 tournament',
      descriptionArabic:
          'لا توجد بطولة واحد ضد واحد نشطة حالياً في $locationName. ترقب إعلان البطولة القادمة.',
      descriptionEnglish:
          'There is no active 1vs1 tournament in $locationName right now. Stay tuned for the next tournament.',
    );
  }
}

/// Banner showing when a user is browsing 1v1 tournaments in a different governorate.
class League1v1GovernorateBanner extends StatelessWidget {
  final String selectedLocation;
  final String userGov;
  final bool isArabic;
  final VoidCallback onReturnToHomeGov;

  const League1v1GovernorateBanner({
    super.key,
    required this.selectedLocation,
    required this.userGov,
    required this.isArabic,
    required this.onReturnToHomeGov,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(VSPDSSpacing.md, VSPDSSpacing.xs, VSPDSSpacing.md, VSPDSSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: VSPDSSpacing.sm, vertical: VSPDSSpacing.xs),
      decoration: BoxDecoration(
        color: VSPDSSemanticColors.surface,
        borderRadius: BorderRadius.circular(VSPDSRadius.lg),
        border: Border.all(color: VSPDSSemanticColors.accentBorder),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.location_copy, color: VSPDSSemanticColors.accent, size: VSPDSizes.iconSm),
          const SizedBox(width: VSPDSSpacing.xs),
          Expanded(
            child: Text(
              isArabic
                  ? 'تتصفح بطولات: ${championTranslateItem(context, selectedLocation)}'
                  : 'Viewing: ${championTranslateItem(context, selectedLocation)}',
              style: VSPDSTypography.bodyMedium.copyWith(color: VSPDSSemanticColors.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: InkWell(
              onTap: onReturnToHomeGov,
              borderRadius: BorderRadius.circular(VSPDSRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VSPDSSpacing.sm,
                  vertical: VSPDSSpacing.sm,
                ),
                child: Center(
                  child: Text(
                    isArabic ? 'بطولاتي (${championTranslateItem(context, userGov)})' : 'My City (${championTranslateItem(context, userGov)})',
                    style: VSPDSTypography.actionLabel,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
