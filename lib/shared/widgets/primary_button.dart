import 'package:flutter/material.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;

  final double? width;
  final EdgeInsetsGeometry? padding;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? VSPColors.accent,
          foregroundColor: textColor ?? VSPColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
          elevation: 0,
          disabledBackgroundColor: VSPColors.surface,
          padding: padding,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    VSPColors.background,
                  ),
                ),
              )
            : Text(
                text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: textColor ?? VSPColors.background,
                  fontSize: 16, // Keeping 16 as it was specifically requested or set before, but using theme as base
                ),
              ),
      ),
    );
  }
}
