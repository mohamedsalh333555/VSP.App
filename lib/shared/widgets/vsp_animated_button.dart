import 'package:flutter/material.dart';
import '../../core/ui/components/vsp_button.dart';

class VSPAnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? height;

  const VSPAnimatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.height,
  });

  @override
  State<VSPAnimatedButton> createState() => _VSPAnimatedButtonState();
}

class _VSPAnimatedButtonState extends State<VSPAnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: VSPPrimaryButton(
          text: widget.text,
          onPressed: widget.onPressed,
          isLoading: widget.isLoading,
          color: widget.color,
          textColor: widget.textColor,
          height: widget.height,
        ),
      ),
    );
  }
}
