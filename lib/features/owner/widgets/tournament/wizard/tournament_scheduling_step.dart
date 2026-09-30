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
  final bool isEditing;
  final List<String>? editableFields;

  const TournamentSchedulingStep({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onSelectStartDate,
    required this.onSelectEndDate,
    required this.durationController,
    required this.prizeController,
    this.isEditing = false,
    this.editableFields,
  });

  bool get _isDatesEditable =>
      !isEditing || editableFields == null || editableFields!.contains('start_date');
  bool get _isDurationEditable =>
      !isEditing || editableFields == null || editableFields!.contains('match_duration');
  bool get _isPrizeEditable =>
      !isEditing || editableFields == null || editableFields!.contains('grand_prize');

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildDateChip(BuildContext context, DateTime? date, String placeholder, {bool enabled = true}) {
    final isSelected = date != null;
    return Container(
      height: VSPSize.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: enabled ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(
          color: enabled ? VSPColors.divider : VSPColors.divider.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isSelected ? '${date.day}/${date.month}/${date.year}' : placeholder,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? (isSelected ? Colors.white : VSPColors.textSecondary)
                      : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
          Icon(
            enabled ? Iconsax.calendar_1_copy : Iconsax.lock_copy,
            color: enabled
                ? (isSelected ? Colors.white : VSPColors.textSecondary)
                : VSPColors.textSecondary,
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
    bool enabled = true,
  }) {
    return SizedBox(
      height: VSPSize.inputHeight,
      child: TextField(
        controller: controller,
        readOnly: !enabled,
        keyboardType: keyboardType,
        textDirection: (keyboardType == TextInputType.phone ||
                keyboardType == TextInputType.number ||
                (keyboardType != null && keyboardType.toString().contains('number')))
            ? TextDirection.ltr
            : null,
        inputFormatters: inputFormatters,
        cursorColor: VSPColors.accent,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: enabled ? Colors.white : VSPColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
        decoration: InputDecoration(
          filled: true,
          fillColor: enabled ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: '',
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
          suffixIcon: !enabled
              ? const Icon(Iconsax.lock_copy, color: VSPColors.textSecondary, size: 16)
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: BorderSide(
              color: enabled ? VSPColors.divider : VSPColors.divider.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            borderSide: BorderSide(
              color: enabled ? VSPColors.accent : VSPColors.divider,
              width: 1.0,
            ),
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
        if (!_isDatesEditable || !_isPrizeEditable || !_isDurationEditable) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VSPRadius.md),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.lock_1_copy, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'الحقول المقفولة (التواريخ أو الجوائز) لا يمكن تعديلها بعد اعتماد اللائحة وبدء التسجيل حفاظاً على التزامات البطولة.'
                        : 'Locked fields (dates or prizes) cannot be changed after registration begins to protect tournament commitments.',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        _buildLabel(context, l10n.startDateLabel),
        GestureDetector(
          onTap: _isDatesEditable ? onSelectStartDate : null,
          child: _buildDateChip(
            context,
            startDate,
            isAr ? 'اختر تاريخ بدء البطولة' : 'Select tournament start date',
            enabled: _isDatesEditable,
          ),
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, l10n.endDateLabel),
        GestureDetector(
          onTap: _isDatesEditable ? onSelectEndDate : null,
          child: _buildDateChip(
            context,
            endDate,
            isAr ? 'اختر تاريخ انتهاء البطولة' : 'Select tournament end date',
            enabled: _isDatesEditable,
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
          enabled: _isDurationEditable,
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, l10n.grandPrizeLabel),
        _buildTextField(
          context,
          prizeController,
          hint: isAr ? 'أدخل قيمة الجائزة الكبرى (مثال: 5000)' : 'Enter grand prize (e.g. 5000)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: _isPrizeEditable,
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
