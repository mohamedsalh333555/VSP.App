import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';

class CopyablePhoneText extends StatelessWidget {
  final String phone;
  final TextStyle? style;

  const CopyablePhoneText({
    super.key,
    required this.phone,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: phone));
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.copy, color: Colors.black, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'تم نسخ رقم الهاتف: $phone' : 'Phone number copied: $phone',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: VSPColors.accent,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
            ),
          );
        }
      },
      child: Tooltip(
        message: isArabic ? 'اضغط مطولاً للنسخ' : 'Long press to copy',
        child: Text(
          phone,
          style: style ?? const TextStyle(color: VSPColors.textPrimary, decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
