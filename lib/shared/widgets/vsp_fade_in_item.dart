import 'package:flutter/material.dart';

class VSPFadeInItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration? delay;

  const VSPFadeInItem({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 400),
    this.delay,
  });

  @override
  State<VSPFadeInItem> createState() => _VSPFadeInItemState();
}

class _VSPFadeInItemState extends State<VSPFadeInItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Use explicit delay if provided, otherwise fall back to index-based stagger
    final effectiveDelay = widget.delay ?? Duration(milliseconds: widget.index * 50);
    Future.delayed(effectiveDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
