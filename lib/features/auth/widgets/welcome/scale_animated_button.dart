import 'dart:async';
import 'package:flutter/material.dart';

/// A reusable micro-animated button wrapper providing tactile scaling feedback and tap debouncing.
class ScaleAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const ScaleAnimatedButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<ScaleAnimatedButton> createState() => _ScaleAnimatedButtonState();
}

class _ScaleAnimatedButtonState extends State<ScaleAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _isDebouncing = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
      lowerBound: 0.94,
      upperBound: 1.0,
    )..value = 1.0;

    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted && !_isDebouncing) _controller.reverse();
      },
      onTapUp: (_) {
        if (mounted && !_isDebouncing) _controller.forward();
      },
      onTapCancel: () {
        if (mounted && !_isDebouncing) _controller.forward();
      },
      onTap: () {
        if (_isDebouncing) return;
        setState(() => _isDebouncing = true);
        widget.onPressed();
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _isDebouncing = false);
        });
      },
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
