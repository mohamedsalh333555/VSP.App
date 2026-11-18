import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Single OTP digit box with paste and backspace detection.
class OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  /// One-based field position for accessible six-digit verification input.
  final int? digitPosition;
  final double width;
  final ValueChanged<String> onChanged;
  final void Function(KeyEvent) onKey;

  const OtpBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    this.digitPosition,
    this.width = 46,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = controller.text.isNotEmpty;
    final inputBox = Container(
      width: width,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(
          color: hasError
              ? VSPColors.error
              : (isFilled ? VSPColors.accent : VSPColors.divider),
          width: isFilled || hasError ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: VSPColors.accent.withValues(alpha: 0.15),
                  blurRadius: 8,
                )
              ]
            : [],
      ),
      child: Focus(
        onKeyEvent: (node, event) {
          onKey(event);
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          maxLength: 6, // allow paste of full code
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: VSPColors.textPrimary,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );

    if (digitPosition == null) return inputBox;
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    return Semantics(
      label: isArabic
          ? 'رمز التحقق، الرقم $digitPosition من 6'
          : 'Verification code digit $digitPosition of 6',
      child: inputBox,
    );
  }
}
