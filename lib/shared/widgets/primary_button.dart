import 'package:flutter/material.dart';
import '../../core/ui/components/vsp_button.dart';

/// Backward-compatible Facade delegating to [VSPPrimaryButton].
/// Single source of truth: handles tokens, debouncing, haptics, width, and padding centrally.
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
    return VSPPrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      color: color,
      textColor: textColor,
      width: width,
      height: height,
      padding: padding,
      iconData: icon,
    );
  }
}

