import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;

  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          HapticFeedback.mediumImpact();
          onPressed?.call();
        },
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: textColor ?? VSPColors.background,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
