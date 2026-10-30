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
    widget.onPressed?.call();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(VSPDSMotion.standard * 6, () {
      if (mounted) {
        setState(() => _isDebouncing = false);
      }
    });
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
      textColor: widget.textColor,
      width: widget.width,
      height: widget.height ?? VSPDSizes.buttonHeight,
      padding: widget.padding,
      icon: widget.icon,
    );
  }
}
