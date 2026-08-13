import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// مكون يضمن تطبيق مبدأ التقارب البصري (Gestalt Proximity - الصفحة 13 من كتاب UX Playbook)
/// بحيث يكون العنوان قريباً جداً من الحقل الخاص به (6px)، 
/// وتبتعد حقول الإدخال المختلفة عن بعضها بمسافة واضحة (20px).
class VSPFormFieldGroup extends StatelessWidget {
  final String label;
  final Widget field;
  final String? helperText;
  final double bottomMargin;

  const VSPFormFieldGroup({
    super.key,
    required this.label,
    required this.field,
    this.helperText,
    this.bottomMargin = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: VSPColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
          ),
          const SizedBox(height: 6.0),
          field,
          if (helperText != null) ...[
            const SizedBox(height: 4.0),
            Text(
              helperText!,
              style: const TextStyle(color: VSPColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
