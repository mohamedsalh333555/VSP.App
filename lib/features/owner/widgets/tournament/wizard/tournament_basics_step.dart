import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../../core/ui/tokens/vsp_tokens.dart';

class TournamentBasicsStep extends StatefulWidget {
  final TextEditingController nameController;
  final String selectedSport;
  final List<String> availableSports;
  final ValueChanged<String> onSportChanged;
  final TextEditingController feeController;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final bool isEditing;
  final String? preselectedType;

  const TournamentBasicsStep({
    super.key,
    required this.nameController,
    required this.selectedSport,
    required this.availableSports,
    required this.onSportChanged,
    required this.feeController,
    required this.selectedType,
    required this.onTypeChanged,
    required this.isEditing,
    this.preselectedType,
  });

  @override
  State<TournamentBasicsStep> createState() => _TournamentBasicsStepState();
}

class _TournamentBasicsStepState extends State<TournamentBasicsStep> {
  late bool _showAllFormats;

  @override
  void initState() {
    super.initState();
    // Collapse full format selector if user already preselected format or is editing
    _showAllFormats = widget.preselectedType == null && !widget.isEditing;
  }

  IconData _getFormatIcon(String type) {
    switch (type) {
      case 'League':
        return Iconsax.award_copy;
      case 'GroupsAndKnockout':
        return Iconsax.security_safe_copy;
      case 'Cup':
      default:
        return Iconsax.cup_copy;
    }
  }

  String _getFormatTitle(String type, bool isAr) {
    switch (type) {
      case 'League':
        return isAr ? 'دوري نقاط كامل' : 'Full League';
      case 'GroupsAndKnockout':
        return isAr ? 'مجموعات ثم تصفيات' : 'Groups & Knockout';
      case 'Cup':
      default:
        return isAr ? 'خروج المغلوب (كأس)' : 'Knockout (Cup)';
    }
  }

  Widget _buildFormatOptionCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isAr,
  }) {
    final isSelected = widget.selectedType == type;
    return InkWell(
      onTap: () => widget.onTypeChanged(type),
      borderRadius: BorderRadius.circular(VSPRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.12) : VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? VSPColors.accent : VSPColors.textSecondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? VSPColors.accent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VSPColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(VSPRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      isAr ? 'مُحدد' : 'Selected',
                      style: const TextStyle(
                        color: VSPColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool autofocus = false,
    String? suffixText,
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
        autofocus: autofocus,
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
          suffixIcon: suffixText != null
              ? UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      suffixText,
                      style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, List<String> items, String value, Function(String?) onChanged) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
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
          value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          dropdownColor: VSPColors.surface,
          icon: const Icon(Iconsax.arrow_down_1_copy, color: VSPColors.accent, size: 16),
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          items: items.map((item) {
            String label = item;
            if (isAr) {
              if (item == 'Football') {
                label = 'كرة القدم';
              } else if (item == 'Basketball') {
                label = 'كرة السلة';
              } else if (item == 'Padel') {
                label = 'بادل';
              } else if (item == 'Volleyball') {
                label = 'كرة الطائرة';
              } else if (item == 'Tennis') {
                label = 'تنس';
              }
            }
            return DropdownMenuItem(value: item, child: Text(label));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. نظام البطولة (مختصر وأنيق إذا كان محدداً مسبقاً)
        if (!_showAllFormats) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VSPColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(_getFormatIcon(widget.selectedType), color: VSPColors.accent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'نظام البطولة المختار' : 'Selected Format',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getFormatTitle(widget.selectedType, isAr),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showAllFormats = true),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: VSPColors.accent,
                  ),
                  child: Text(
                    isAr ? 'تغيير' : 'Change',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'اختر نظام البطولة' : 'Choose Tournament Format',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (widget.preselectedType != null || widget.isEditing)
                GestureDetector(
                  onTap: () => setState(() => _showAllFormats = false),
                  child: Text(
                    isAr ? 'إخفاء' : 'Hide',
                    style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // خروج المغلوب (Cup)
          _buildFormatOptionCard(
            type: 'Cup',
            title: isAr ? 'خروج المغلوب' : 'Knockout',
            subtitle: isAr ? 'الخاسر يخرج فوراً. أعداد الفرق: 4، 8، 16، 32' : 'Single elimination. 4, 8, 16, 32 teams.',
            icon: Iconsax.cup_copy,
            isAr: isAr,
          ),
          const SizedBox(height: 10),

          // دوري كامل (League)
          _buildFormatOptionCard(
            type: 'League',
            title: isAr ? 'دوري نقاط كامل' : 'Full League',
            subtitle: isAr ? 'كل الفرق تلعب ضد بعضها. الترتيب بأعلى النقاط' : 'Round-Robin system. Winner with most points.',
            icon: Iconsax.award_copy,
            isAr: isAr,
          ),
          const SizedBox(height: 10),

          // مجموعات وتصفيات (Groups + Knockout)
          _buildFormatOptionCard(
            type: 'GroupsAndKnockout',
            title: isAr ? 'مجموعات ثم تصفيات' : 'Groups & Knockout',
            subtitle: isAr ? 'تقسيم لمجموعات ثم تصعيد المتأهلين للتصفيات' : 'Group stage followed by Knockout bracket.',
            icon: Iconsax.security_safe_copy,
            isAr: isAr,
          ),
        ],

        const SizedBox(height: 24),
        const Divider(color: VSPColors.divider, height: 1),
        const SizedBox(height: 20),

        // 2. البيانات الأساسية للبطولة
        _buildLabel(context, isAr ? 'اسم البطولة' : 'Tournament Name'),
        _buildTextField(
          context,
          widget.nameController,
          hint: isAr ? 'مثال: كأس الأبطال' : 'e.g. Star Cup',
          autofocus: !widget.isEditing,
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, isAr ? 'نوع الرياضة' : 'Sport Type'),
        _buildDropdown(
          context,
          widget.availableSports,
          widget.selectedSport,
          (v) {
            if (v != null) widget.onSportChanged(v);
          },
        ),
        const SizedBox(height: VSPSpacing.md),

        _buildLabel(context, isAr ? 'رسوم الاشتراك (ج.م)' : 'Entry Fee (EGP)'),
        _buildTextField(
          context,
          widget.feeController,
          hint: isAr ? 'أدخل رسوم الاشتراك (مثال: 300)' : 'Enter entry fee (e.g. 300)',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixText: isAr ? 'ج.م' : 'EGP',
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
