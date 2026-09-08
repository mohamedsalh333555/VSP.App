import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

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
    required this.onAddNoteTemplate,
    required this.onNext,
  });

  String _formatTime(TimeOfDay? time, String placeholder) {
    if (time == null) return placeholder;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

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

  Widget _buildTimeBox(String text, {bool isSelected = false}) {
    return Container(
      height: VSPSize.inputHeight,
      decoration: BoxDecoration(
        color: isSelected ? VSPColors.accentSoft : VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.input),
        border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.accent.withValues(alpha: 0.1)),
      ),
      child: Center(child: Text(text, style: TextStyle(color: isSelected ? VSPColors.accent : VSPColors.textPrimary))),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.location,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
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
                          locationController.text.isNotEmpty
                              ? locationController.text
                              : (isArabic ? 'اضغط لتحديد موقع الملعب على الخريطة ' : 'Tap to select stadium location on map '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: locationController.text.isNotEmpty ? Colors.white : VSPColors.textSecondary,
                            fontSize: 13,
                            fontWeight: locationController.text.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isLocationLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent),
                        )
                      else if (locationController.text.isNotEmpty)
                        const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 18)
                      else
                        Icon(isArabic ? Iconsax.arrow_left_2_copy : Iconsax.arrow_right_1_copy, color: VSPColors.textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(context, AppLocalizations.of(context)!.stadiumName, isArabic ? 'أدخل اسم ملعبك' : 'Enter Stadium Name', controller: nameController, maxLength: 50),
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
                AppLocalizations.of(context)!.sportTypeLabel,
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
                      AppLocalizations.of(context)!.selectSport,
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
            AppLocalizations.of(context)!.pricePerHour,
            '0.0',
            controller: priceController,
            maxLength: 7,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            context,
            AppLocalizations.of(context)!.playersTeam,
            isArabic ? 'اكتب رقم عدد الفريق الواحد' : 'Write the number of players for a single team',
            controller: capacityController,
            maxLength: 2,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          Text(AppLocalizations.of(context)!.workingHours, style: const TextStyle(color: VSPColors.textSecondary)),
          Row(children: [
            Expanded(child: GestureDetector(onTap: () => onSelectTime(true), child: _buildTimeBox(_formatTime(startTime, AppLocalizations.of(context)!.start), isSelected: startTime != null))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(onTap: () => onSelectTime(false), child: _buildTimeBox(_formatTime(endTime, AppLocalizations.of(context)!.end), isSelected: endTime != null))),
          ]),
          if (endTime != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Iconsax.info_circle_copy, color: VSPColors.accent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Builder(builder: (context) {
                    final selectedEndStr = _formatTime(endTime, '');
                    return Text(
                      isArabic
                          ? 'ملاحظة: اختيار وقت الإغلاق ($selectedEndStr) يعني أن الملعب يغلق فعلياً وينتهي آخر حجز في هذا الوقت.'
                          : 'Note: Selecting closing time ($selectedEndStr) means the pitch actually closes and the last booking ends at this time.',
                      style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11, height: 1.4),
                    );
                  }),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          // Break Time Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.setDailyBreak, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary)),
              Switch.adaptive(
                value: isSplitShift,
                onChanged: onToggleSplitShift,
                activeColor: VSPColors.accent,
              ),
            ],
          ),

          if (isSplitShift) ...[
            const SizedBox(height: 8),
            ...breakTimes.asMap().entries.map((entry) {
              final index = entry.key;
              final bt = entry.value;
              final bStart = bt['start'];
              final bEnd = bt['end'];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'فترة راحة ${index + 1}' : 'Break ${index + 1}',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (breakTimes.length > 1)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Iconsax.trash_copy, color: VSPColors.error, size: 20),
                          onPressed: () => onRemoveBreak(index),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: GestureDetector(onTap: () => onSelectBreakTime(index, true), child: _buildTimeBox(_formatTime(bStart, AppLocalizations.of(context)!.breakStart), isSelected: bStart != null))),
                    const SizedBox(width: 10),
                    Expanded(child: GestureDetector(onTap: () => onSelectBreakTime(index, false), child: _buildTimeBox(_formatTime(bEnd, AppLocalizations.of(context)!.breakEnd), isSelected: bEnd != null))),
                  ]),
                ],
              );
            }),
            const SizedBox(height: 12),
            Align(
              alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddBreak,
                icon: const Icon(Iconsax.add_circle_copy, color: VSPColors.accent, size: 18),
                label: Text(
                  isArabic ? 'إضافة فترة راحة أخرى' : 'Add Another Break',
                  style: const TextStyle(color: VSPColors.accent, fontSize: 13),
                ),
              ),
            ),
            if (!isSplitShiftValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VSPColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.sm),
                  border: Border.all(color: VSPColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.warning_2_copy, color: VSPColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'ساعات الراحة يجب أن تكون داخل مواعيد العمل الرسمية للملعب!'
                            : 'Break hours must fall strictly inside the opening and closing hours!',
                        style: const TextStyle(color: VSPColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

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
