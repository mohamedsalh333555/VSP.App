import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/components/vsp_button.dart';

/// 🛡️ SECURITY: Thread-safe animated button with built-in debounce/throttle.
///
/// Prevents button-spamming concurrency attacks by enforcing a strict 2000ms
/// cooldown between taps. When `isLoading` is true, ALL touch gestures are
/// rejected via `AbsorbPointer`.
class VSPAnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? height;

  /// Cooldown duration in milliseconds after each press.
  /// Default: 2000ms to prevent duplicate API calls during high latency.
  final int cooldownMs;

  const VSPAnimatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.height,
    this.cooldownMs = 2000,
  });

  @override
  State<VSPAnimatedButton> createState() => _VSPAnimatedButtonState();
}

class _VSPAnimatedButtonState extends State<VSPAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  /// 🛡️ Throttle state: tracks whether the button is in cooldown period.
  bool _isCoolingDown = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;

    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (mounted) _controller.reverse();
  }

  void _onTapUp(_) {
    if (mounted) _controller.forward();
  }

  void _onTapCancel() {
    if (mounted) _controller.forward();
  }

  /// 🛡️ SECURITY BARRIER: Debounced tap handler.
  /// Wraps the original onPressed callback with a strict cooldown period.
  void _handleThrottledTap() {
    // Reject if already loading or in cooldown
    if (widget.isLoading || _isCoolingDown || widget.onPressed == null) return;

    // Activate cooldown
    setState(() => _isCoolingDown = true);

    // Execute the original callback
    widget.onPressed!();

    // Start cooldown timer
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(Duration(milliseconds: widget.cooldownMs), () {
      if (mounted) {
        setState(() => _isCoolingDown = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ AbsorbPointer: When isLoading is true, reject ALL further touch gestures
    return AbsorbPointer(
      absorbing: widget.isLoading || _isCoolingDown,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scale,
          child: VSPPrimaryButton(
            text: widget.text,
            onPressed: _handleThrottledTap,
            isLoading: widget.isLoading,
            color: widget.color,
            textColor: widget.textColor,
            height: widget.height,
          ),
        ),
      ),
    );
  }
}
