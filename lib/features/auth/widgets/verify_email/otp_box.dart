import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

/// Single OTP digit box with paste and backspace detection.
class OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final void Function(KeyEvent) onKey;

  const OtpBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = controller.text.isNotEmpty;
    return Container(
      width: 46,
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
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: onKey,
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
  }
}
