import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';
import '../../core/services/logger_service.dart';

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
    return Semantics(
      button: true,
      label: isArabic ? 'نسخ رقم الهاتف' : 'Copy phone number',
      hint: isArabic ? 'اضغط مطولاً لنسخ الرقم' : 'Long press to copy the number',
      child: InkWell(
        onLongPress: () async {
          try {
            await Clipboard.setData(ClipboardData(text: phone));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Iconsax.copy_copy, color: VSPColors.black, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'تم نسخ رقم الهاتف: $phone' : 'Phone number copied: $phone',
                      style: const TextStyle(color: VSPColors.black, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                backgroundColor: VSPColors.accent,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
              ),
            );
          } catch (e, stack) {
            VSPLogger.e('Could not copy phone number to clipboard', e, stack);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isArabic ? 'تعذر نسخ رقم الهاتف. حاول مرة أخرى.' : 'Could not copy the phone number. Try again.',
                ),
              ),
            );
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: VSPSize.touchTarget,
            minHeight: VSPSize.touchTarget,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: isArabic ? 'اضغط مطولاً للنسخ' : 'Long press to copy',
              child: Text(
                phone,
                style: style ??
                    const TextStyle(
                      color: VSPColors.textPrimary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
