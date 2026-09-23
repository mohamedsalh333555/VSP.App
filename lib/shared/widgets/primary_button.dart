import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

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
        height: widget.height ?? VSPSize.buttonHeight,
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
            backgroundColor: widget.color ?? VSPColors.accent,
            foregroundColor: widget.textColor ?? VSPColors.background,
            shape: const StadiumBorder(),
            elevation: 0,
            disabledBackgroundColor: VSPStates.disabled(widget.color ?? VSPColors.accent),
            disabledForegroundColor: VSPStates.disabled(widget.textColor ?? VSPColors.background),
            overlayColor: VSPStates.pressedOverlay(),
            padding: widget.padding,
          ),
          child: widget.isLoading
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
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.text,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: widget.textColor ?? VSPColors.background,
                            fontSize: 16,
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
