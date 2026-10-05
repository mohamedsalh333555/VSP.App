import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_design_tokens.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = widget.isLoading || _isDebouncing || widget.onPressed == null;
    return AbsorbPointer(
      absorbing: isButtonDisabled,
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? VSPDSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: isButtonDisabled ? null : () {
            HapticFeedback.mediumImpact();
            setState(() => _isDebouncing = true);
            widget.onPressed?.call();
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() => _isDebouncing = false);
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color ?? VSPDSSemanticColors.accent,
            foregroundColor: widget.textColor ?? VSPDSSemanticColors.background,
            shape: const StadiumBorder(),
            elevation: 0,
            disabledBackgroundColor: (widget.color ?? VSPDSSemanticColors.accent).withValues(alpha: VSPDSOpacity.disabled),
            disabledForegroundColor: (widget.textColor ?? VSPDSSemanticColors.background).withValues(alpha: VSPDSOpacity.disabled),
            overlayColor: VSPDSColors.white12,
            padding: widget.padding,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  height: VSPDSizes.iconLg,
                  width: VSPDSizes.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: VSPDSAccessibility.progressStroke,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      VSPDSSemanticColors.background,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: VSPDSizes.iconMd),
                      const SizedBox(width: VSPDSSpacing.xs),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.text,
                          style: VSPDSTypography.button.copyWith(
                            color: widget.textColor ?? VSPDSSemanticColors.background,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
