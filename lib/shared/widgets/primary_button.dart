import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/components/vsp_button.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

/// Backward-compatible shared button adapter.
///
/// Keeps the existing debounce and haptic behavior while delegating all
/// visual rendering to the canonical VSPPrimaryButton component.
class PrimaryButton extends StatefulWidget {
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
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isDebouncing = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading || _isDebouncing || widget.onPressed == null) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isDebouncing = true);
    try {
      widget.onPressed?.call();
    } finally {
      // Always release the debounce state, even if a synchronous callback
      // throws before it can start its own async operation.
      _debounceTimer?.cancel();
      _debounceTimer = Timer(VSPDSMotion.buttonDebounce, () {
        if (mounted) {
          setState(() => _isDebouncing = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        widget.isLoading || _isDebouncing || widget.onPressed == null;

    return VSPPrimaryButton(
      text: widget.text,
      onPressed: isDisabled ? null : _handleTap,
      isLoading: widget.isLoading,
      color: widget.color,
      textColor: widget.textColor ?? VSPDSSemanticColors.background,
      width: widget.width,
      height: widget.height ?? VSPDSizes.buttonHeight,
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: VSPDSSpacing.md),
      icon: widget.icon,
    );
  }
}
