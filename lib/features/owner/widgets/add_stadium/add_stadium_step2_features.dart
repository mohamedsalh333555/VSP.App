import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

class AddStadiumStep2Features extends StatelessWidget {
  final TextEditingController seatsController;
  final TextEditingController ballPriceController;
  final TextEditingController depositController;
  final String? selectedBathOption;
  final bool? cafeteria;
  final bool? garage;
  final bool? changingRoom;
  final bool? hasBall;
  final bool requireDeposit;
  final ValueChanged<bool> onUpdateBathOption;
  final ValueChanged<bool> onUpdateCafeteria;
  final ValueChanged<bool> onUpdateGarage;
  final ValueChanged<bool> onUpdateChangingRoom;
  final ValueChanged<bool> onUpdateHasBall;
  final ValueChanged<bool> onUpdateRequireDeposit;
  final VoidCallback onNext;

  const AddStadiumStep2Features({
    super.key,
    required this.seatsController,
    required this.ballPriceController,
    required this.depositController,
    required this.selectedBathOption,
    required this.cafeteria,
    required this.garage,
    required this.changingRoom,
    required this.hasBall,
    required this.requireDeposit,
    required this.onUpdateBathOption,
    required this.onUpdateCafeteria,
    required this.onUpdateGarage,
    required this.onUpdateChangingRoom,
    required this.onUpdateHasBall,
    required this.onUpdateRequireDeposit,
    required this.onNext,
  });

  Widget _buildTextField(
    BuildContext context,
    String label,
    String hint, {
    required TextEditingController controller,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        CustomTextField(
          controller: controller,
          hintText: hint,
          keyboardType: keyboardType ?? TextInputType.text,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }

  Widget _optionBtn(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? VSPColors.accent : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.xl),
        ),
        child: Text(text, style: TextStyle(color: selected ? Colors.black : VSPColors.textPrimary)),
      ),
    );
  }

  Widget _buildYesNoSection(BuildContext context, String label, bool? value, ValueChanged<bool> onChanged) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            _optionBtn(isArabic ? 'نعم' : 'Yes', value == true, () => onChanged(true)),
            const SizedBox(width: 10),
            _optionBtn(isArabic ? 'لا' : 'No', value != null && value == false, () => onChanged(false)),
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
      ),
      child: Column(
        children: [
          _buildYesNoSection(context, AppLocalizations.of(context)!.bathrooms, selectedBathOption == null ? null : selectedBathOption == 'Yes', onUpdateBathOption),
          const SizedBox(height: 20),
          _buildYesNoSection(context, AppLocalizations.of(context)!.cafeteria, cafeteria, onUpdateCafeteria),
          const SizedBox(height: 20),
          _buildYesNoSection(context, AppLocalizations.of(context)!.garage, garage, onUpdateGarage),
          const SizedBox(height: 20),
          _buildYesNoSection(context, AppLocalizations.of(context)!.changingRoom, changingRoom, onUpdateChangingRoom),
          const SizedBox(height: 20),
          _buildTextField(
            context,
            AppLocalizations.of(context)!.seatCount,
            '0',
            controller: seatsController,
            maxLength: 5,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: 30),
          const Divider(color: VSPColors.divider),
          const SizedBox(height: 20),

          Align(
            alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)!.amenities, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          _buildYesNoSection(context, AppLocalizations.of(context)!.ballAvailableLabel, hasBall, onUpdateHasBall),

          if (hasBall == true) ...[
            const SizedBox(height: 16),
            _buildTextField(
              context,
              isArabic ? 'سعر تأجير الكرة (ج.م)' : 'Ball Rental Price (EGP)',
              '0.0',
              controller: ballPriceController,
              maxLength: 5,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
            ),
          ],
          const SizedBox(height: 40),
          PrimaryButton(
            text: isArabic ? 'متابعة' : 'Continue',
            onPressed: onNext,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}
