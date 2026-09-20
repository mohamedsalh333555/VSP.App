import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// حقل إدخال نص مخصص بتصميم داكن مع دعم التحقق المباشر (Inline Live Validation)
class CustomTextField extends StatelessWidget {
  final String? hintText;
  final String? errorText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int? maxLength;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool? enabled;
  final bool autofocus;
  final bool? isValid;
  final bool showLiveValidation;

  const CustomTextField({
    super.key,
    this.hintText,
    this.errorText,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLength,
    this.maxLines = 1,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled,
    this.autofocus = false,
    this.isValid,
    this.showLiveValidation = true,
  });

  bool _computeValidity(String text) {
    if (isValid != null) return isValid!;
    if (!showLiveValidation) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    if (keyboardType == TextInputType.emailAddress) {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      return emailRegex.hasMatch(trimmed);
    } else if (keyboardType == TextInputType.phone) {
      final clean = trimmed.replaceAll(RegExp(r'[\s-]'), '');
      final phoneRegex = RegExp(r'^(01[0125][0-9]{8}|(\+?201)[0125][0-9]{8})$');
      return phoneRegex.hasMatch(clean);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasValidInput = _computeValidity(controller.text);

        Widget? effectiveSuffix = suffixIcon;
        if (effectiveSuffix == null && hasValidInput && errorText == null) {
          effectiveSuffix = const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Iconsax.tick_circle_copy,
              color: VSPColors.success,
              size: VSPIconSize.md,
            ),
          );
        }

        final fieldWidget = TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: (keyboardType == TextInputType.emailAddress ||
                  keyboardType == TextInputType.url ||
                  keyboardType == TextInputType.phone ||
                  keyboardType == TextInputType.number ||
                  keyboardType.toString().contains('number'))
              ? TextDirection.ltr
              : null,
          obscureText: obscureText,
          maxLines: maxLines,
          validator: validator,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          enabled: enabled,
          autofocus: autofocus,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            errorText: errorText,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: VSPColors.textSecondary.withValues(alpha: 0.5),
                ),
            filled: true,
            fillColor: VSPColors.surfaceAlt,
            counterText: "",
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: VSPColors.textSecondary,
                    size: VSPIconSize.md,
                  )
                : null,
            suffixIcon: effectiveSuffix != null
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: effectiveSuffix,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.input),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.input),
              borderSide: const BorderSide(
                color: VSPColors.divider,
                width: VSPBorder.widthDefault,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.input),
              borderSide: const BorderSide(
                color: VSPColors.accent,
                width: VSPBorder.widthMedium,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.input),
              borderSide: const BorderSide(
                color: VSPColors.error,
                width: VSPBorder.widthDefault,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        );

        if (maxLines != null && maxLines! > 1) {
          return fieldWidget;
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: VSPSize.inputHeight),
          child: fieldWidget,
        );
      },
    );
  }
}
