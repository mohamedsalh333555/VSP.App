import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/egypt_governorates.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/widgets/shimmer_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Form section allowing captains to edit the team name, sport type, and team emblem/logo.
class TeamProfileForm extends StatelessWidget {
  final TextEditingController teamNameController;
  final String selectedSport;
  final XFile? selectedLogo;
  final String? teamLogoUrl;
  final bool isCaptain;
  final bool isArabic;
  final ValueChanged<String> onSportChanged;
  final VoidCallback onPickLogo;

  const TeamProfileForm({
    super.key,
    required this.teamNameController,
    required this.selectedSport,
    required this.selectedLogo,
    required this.teamLogoUrl,
    required this.isCaptain,
    required this.isArabic,
    required this.onSportChanged,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Team Name Input
        Text(l10n.teamName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: VSPSpacing.sm),
        _buildTextField(teamNameController, hint: l10n.enterTeamName, readOnly: !isCaptain),

        const SizedBox(height: VSPSpacing.md),

        // 2. Sports Type Dropdown
        Text(l10n.sportsType, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: VSPSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 44,
          decoration: BoxDecoration(
            color: VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            border: Border.all(color: VSPColors.divider, width: 0.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSport,
              isExpanded: true,
              dropdownColor: VSPColors.surface,
              icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
              items: VSPConstants.sports.map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  EgyptGovernorates.getLocalizedSport(s, isArabic),
                  style: const TextStyle(color: VSPColors.textPrimary),
                ),
              )).toList(),
              onChanged: !isCaptain ? null : (val) {
                if (val != null) onSportChanged(val);
              },
            ),
          ),
        ),

        const SizedBox(height: VSPSpacing.lg),

        // 3. Logo Upload & Preview
        _buildLogoSection(context, l10n),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? hint, bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.divider.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: const TextStyle(color: VSPColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.5), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context, AppLocalizations l10n) {
    final hasLogo = selectedLogo != null || (teamLogoUrl != null && teamLogoUrl!.isNotEmpty);
    final uploadBtn = PrimaryButton(
      text: l10n.uploadPhoto,
      height: 45,
      color: VSPColors.surfaceAlt,
      textColor: isCaptain ? VSPColors.textPrimary : VSPColors.textSecondary.withValues(alpha: 0.5),
      icon: Iconsax.export_3_copy,
      onPressed: !isCaptain ? null : onPickLogo,
    );

    if (!hasLogo) {
      return SizedBox(width: double.infinity, child: uploadBtn);
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: selectedLogo != null
              ? Image.file(File(selectedLogo!.path), width: 50, height: 50, fit: BoxFit.cover)
              : ShimmerImage(imageUrl: teamLogoUrl ?? '', width: 50, height: 50, borderRadius: 25),
        ),
        const SizedBox(width: VSPSpacing.md),
        Expanded(child: uploadBtn),
      ],
    );
  }
}
