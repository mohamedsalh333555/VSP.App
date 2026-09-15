import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class TournamentSchedulingStep extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final VoidCallback onSelectStartDate;
  final VoidCallback onSelectEndDate;
  final TextEditingController durationController;
  final TextEditingController prizeController;

  const TournamentSchedulingStep({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.durationController,
    required this.prizeController,
  });

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDateChip(BuildContext context, DateTime? date, String placeholder) {
    final isSelected = date != null;
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(
          color: isSelected ? VSPColors.divider : VSPColors.divider,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isSelected ? '${date.day}/${date.month}/${date.year}' : placeholder,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
          Icon(
            Iconsax.calendar_1_copy,
            color: isSelected ? Colors.white : VSPColors.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: VSPSize.inputHeight,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textDirection: (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number ||
                (keyboardType != null && keyboardType.toString().contains('number')))
            ? TextDirection.ltr
            : null,
        inputFormatters: inputFormatters,
        cursorColor: VSPColors.accent,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          filled: true,
          fillColor: VSPColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: '',
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: const BorderSide(color: VSPColors.divider, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: const BorderSide(color: VSPColors.accent, width: 1.0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(context, l10n.startDateLabel),
        GestureDetector(
          onTap: onSelectStartDate,
          child: _buildDateChip(
            context,
            startDate,
            isAr ? 'اختر تاريخ بدء البطولة' : 'Select tournament start date',
          ),
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, l10n.endDateLabel),
        GestureDetector(
          onTap: onSelectEndDate,
          child: _buildDateChip(
            context,
            endDate,
            isAr ? 'اختر تاريخ انتهاء البطولة' : 'Select tournament end date',
          ),
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, l10n.matchDurationLabel),
        _buildTextField(
          context,
          durationController,
          hint: isAr ? 'مدة المباراة بالدقائق (مثال: 30)' : 'Match duration (e.g. 30)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, l10n.grandPrizeLabel),
        _buildTextField(
          context,
          prizeController,
          hint: isAr ? 'أدخل قيمة الجائزة الكبرى (مثال: 5000)' : 'Enter grand prize (e.g. 5000)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
