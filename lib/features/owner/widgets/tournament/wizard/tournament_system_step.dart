import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class TournamentSystemStep extends StatelessWidget {
  final String selectedType;
  final String selectedTeams;
  final ValueChanged<String> onTeamsChanged;
  final int numberOfGroups;
  final ValueChanged<int> onGroupsChanged;
  final int qualifyingPerGroup;
  final ValueChanged<int> onQualifyingChanged;
  final bool isTwoLegs;
  final ValueChanged<bool> onTwoLegsChanged;

  const TournamentSystemStep({
    super.key,
    required this.selectedType,
    required this.selectedTeams,
    required this.onTeamsChanged,
    required this.numberOfGroups,
    required this.onGroupsChanged,
    required this.qualifyingPerGroup,
    required this.onQualifyingChanged,
    required this.isTwoLegs,
    required this.onTwoLegsChanged,
  });

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDropdown(BuildContext context, List<String> items, String value, Function(String?) onChanged) {
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: VSPColors.surface,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'إعدادات وقواعد البطولة ' : 'Tournament Rules & Format ',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),

        _buildLabel(context, AppLocalizations.of(context)!.maxTeamsLabel),
        _buildDropdown(
          context,
          ['4', '8', '16', '32'],
          selectedTeams,
          (v) {
            if (v != null) onTeamsChanged(v);
          },
        ),
        const SizedBox(height: 16),

        // إعدادات خاصة بالمجموعات والدوري
        if (selectedType == 'GroupsAndKnockout') ...[
          _buildLabel(context, isArabic ? 'عدد المجموعات:' : 'Number of Groups:'),
          _buildDropdown(
            context,
            ['2', '4', '8'],
            numberOfGroups.toString(),
            (v) {
              if (v != null) onGroupsChanged(int.parse(v));
            },
          ),
          const SizedBox(height: 12),
          _buildLabel(context, isArabic ? 'المتأهلين من كل مجموعة:' : 'Qualifiers per Group:'),
          _buildDropdown(
            context,
            ['1', '2'],
            qualifyingPerGroup.toString(),
            (v) {
              if (v != null) onQualifyingChanged(int.parse(v));
            },
          ),
          const SizedBox(height: 12),
        ],

        if (selectedType == 'League') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'ذهاب وإياب' : 'Home & Away',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Switch.adaptive(
                value: isTwoLegs,
                onChanged: onTwoLegsChanged,
                activeColor: VSPColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}
