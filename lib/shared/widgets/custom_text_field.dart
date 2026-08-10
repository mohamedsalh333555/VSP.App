import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// حقل إدخال نص مخصص بتصميم داكن
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
  });

  @override
  Widget build(BuildContext context) {
    final fieldWidget = TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: (keyboardType == TextInputType.emailAddress ||
              keyboardType == TextInputType.url ||
              keyboardType == TextInputType.phone)
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
                size: 20,
              )
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.input),
          borderSide: const BorderSide(
            color: VSPColors.divider,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.input),
          borderSide: const BorderSide(
            color: VSPColors.accent,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.input),
          borderSide: const BorderSide(
            color: VSPColors.error,
            width: 1,
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

    return SizedBox(
      height: VSPSize.inputHeight,
      child: fieldWidget,
    );
  }
}
