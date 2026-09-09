import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';

class AddStadiumStep1LocationField extends StatelessWidget {
  final TextEditingController locationController;
  final bool isEditing;
  final bool isLocationLoading;
  final VoidCallback onOpenMapPicker;

  const AddStadiumStep1LocationField({
    super.key,
    required this.locationController,
    required this.isEditing,
    required this.isLocationLoading,
    required this.onOpenMapPicker,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = locationController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.location,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: VSPColors.textSecondary,
              ),
        ),
        const SizedBox(height: VSPSpacing.xs),
        GestureDetector(
          onTap: (isEditing || isLocationLoading) ? null : onOpenMapPicker,
          child: Container(
            width: double.infinity,
            height: VSPSize.inputHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.input),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  isEditing ? Iconsax.lock_copy : Iconsax.location_copy,
                  color: VSPColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasLocation
                        ? locationController.text
                        : (isArabic
                            ? 'اضغط لتحديد موقع الملعب على الخريطة '
                            : 'Tap to select stadium location on map '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasLocation ? Colors.white : VSPColors.textSecondary,
                      fontSize: 13,
                      fontWeight: hasLocation ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isLocationLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VSPColors.accent,
                    ),
                  )
                else if (hasLocation)
                  const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 18)
                else
                  Icon(
                    isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy,
                    color: VSPColors.textSecondary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
