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
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
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
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.enabled,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      enabled: enabled,
      autofocus: autofocus,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary.withValues(alpha: 0.5),
            ),
        filled: true,
        fillColor: VSPColors.surface,
        counterText: "",
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: VSPColors.textSecondary,
              )
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: BorderSide(
            color: VSPColors.accent.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: const BorderSide(
            color: VSPColors.accent,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: const BorderSide(
            color: VSPColors.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VSPSpacing.md,
          vertical: VSPSpacing.md,
        ),
      ),
    );
  }
}
