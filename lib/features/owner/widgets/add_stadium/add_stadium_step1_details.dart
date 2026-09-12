import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'add_stadium_step1_hours_section.dart';
import 'add_stadium_step1_location_field.dart';

class AddStadiumStep1Details extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController stadiumPhoneController;
  final TextEditingController priceController;
  final TextEditingController capacityController;
  final TextEditingController locationController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController notesController;
  final String? selectedSportType;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isSplitShift;
  final List<Map<String, TimeOfDay?>> breakTimes;
  final bool isSplitShiftValid;
  final bool isLocationLoading;
  final bool isEditing;
  final ValueChanged<String?> onSelectSport;
  final Function(bool isMainStart) onSelectTime;
  final ValueChanged<bool> onToggleSplitShift;
  final Function(int index, bool isStart) onSelectBreakTime;
  final VoidCallback onAddBreak;
  final ValueChanged<int> onRemoveBreak;
  final VoidCallback onOpenMapPicker;
  final VoidCallback onOpenManualPicker;
  final ValueChanged<String> onAddNoteTemplate;
  final VoidCallback onNext;

  const AddStadiumStep1Details({
    super.key,
    required this.nameController,
    required this.stadiumPhoneController,
    required this.priceController,
    required this.capacityController,
    required this.locationController,
    required this.lengthController,
    required this.widthController,
    required this.notesController,
    required this.selectedSportType,
    required this.startTime,
    required this.endTime,
    required this.isSplitShift,
    required this.breakTimes,
    required this.isSplitShiftValid,
    required this.isLocationLoading,
    required this.isEditing,
    required this.onSelectSport,
    required this.onSelectTime,
    required this.onToggleSplitShift,
    required this.onSelectBreakTime,
    required this.onAddBreak,
    required this.onRemoveBreak,
    required this.onOpenMapPicker,
    required this.onOpenManualPicker,
    required this.onAddNoteTemplate,
    required this.onNext,
  });

  String _getLocalizedSport(String sport, bool isAr) {
    if (!isAr) return sport;
    switch (sport) {
      case 'Football':
        return 'كرة القدم';
      case 'Basketball':
        return 'كرة السلة';
      case 'Volleyball':
        return 'الكرة الطائرة';
      case 'Padel':
        return 'بادل';
      case 'Handball':
        return 'كرة اليد';
      case 'Tennis':
        return 'تنس';
      default:
        return sport;
    }
  }

  Widget _buildTextField(
    BuildContext context,
    String label,
    String hint, {
    required TextEditingController controller,
    int maxLines = 1,
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
          keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          maxLength: maxLength,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        top: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md
            : (MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom + VSPSpacing.md
                : VSPSpacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single Unified Interactive Location Selector Field
          AddStadiumStep1LocationField(
            locationController: locationController,
            isEditing: isEditing,
            isLocationLoading: isLocationLoading,
            onOpenMapPicker: onOpenMapPicker,
            onOpenManualPicker: onOpenManualPicker,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            context,
            l10n.stadiumName,
            isArabic ? 'أدخل اسم ملعبك' : 'Enter Stadium Name',
            controller: nameController,
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            context,
            isArabic ? 'رقم هاتف الملعب' : 'Stadium Phone Number',
            '01xxxxxxxxx',
            controller: stadiumPhoneController,
            maxLength: 15,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          // Sport Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sportTypeLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: VSPColors.textSecondary,
                ),
              ),
              const SizedBox(height: VSPSpacing.xs),
              Container(
                height: VSPSize.inputHeight,
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.input),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSportType,
                    hint: Text(
                      l10n.selectSport,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: VSPColors.textSecondary,
                      ),
                    ),
                    dropdownColor: VSPColors.surface,
                    isExpanded: true,
                    items: VSPConstants.sports
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(_getLocalizedSport(e, isArabic), style: Theme.of(context).textTheme.bodyMedium),
                            ))
                        .toList(),
                    onChanged: onSelectSport,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            context,
            l10n.pricePerHour,
            '0.0',
            controller: priceController,
            maxLength: 7,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            context,
            l10n.playersTeam,
            isArabic ? 'اكتب رقم عدد الفريق الواحد' : 'Write the number of players for a single team',
            controller: capacityController,
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          // Working Hours & Daily Breaks
          AddStadiumStep1HoursSection(
            startTime: startTime,
            endTime: endTime,
            isSplitShift: isSplitShift,
            breakTimes: breakTimes,
            isSplitShiftValid: isSplitShiftValid,
            onSelectTime: onSelectTime,
            onToggleSplitShift: onToggleSplitShift,
            onSelectBreakTime: onSelectBreakTime,
            onAddBreak: onAddBreak,
            onRemoveBreak: onRemoveBreak,
          ),

          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _buildTextField(
                context,
                isArabic ? 'الطول (متر)' : 'Length',
                isArabic ? 'متر' : 'm',
                controller: lengthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                context,
                isArabic ? 'العرض (متر)' : 'Width',
                isArabic ? 'متر' : 'm',
                controller: widthController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ]),

          const SizedBox(height: 16),
          _buildTextField(
            context,
            isArabic ? 'ملاحظات وتعليمات الملعب' : 'Notes',
            isArabic
                ? 'مثال: الحضور قبل الموعد بـ 10 دقائق، الحفاظ على أرضية الملعب...'
                : 'Ex: We ensure a professional environment. Please arrive on time...',
            controller: notesController,
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (isArabic
                      ? ['الالتزام بالموعد', 'الحفاظ على النظافة', 'ممنوع التدخين', 'إحضار الكرة الخاصة بك']
                      : ['Punctuality', 'Cleanliness', 'No Smoking', 'Bring your own ball'])
                  .map((template) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(template, style: const TextStyle(fontSize: 12)),
                          backgroundColor: VSPColors.surface,
                          labelStyle: const TextStyle(color: VSPColors.accent),
                          onPressed: () => onAddNoteTemplate(template),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 30),
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
