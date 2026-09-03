import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../core/ui/tokens/vsp_tokens.dart';

/// زر الرجوع الموحد لتطبيق VSP (تصميم زجاجي دائري مع أنيميشن ولمس تفاعلي)
class VSPBackButton extends StatefulWidget {
 final VoidCallback? onTap;
 final Color? iconColor;
 final double size;
 final EdgeInsetsGeometry margin;

 const VSPBackButton({
 super.key,
 this.onTap,
 this.iconColor,
 this.size = 38.0,
 this.margin = EdgeInsets.zero,
 });

 @override
 State<VSPBackButton> createState() => _VSPBackButtonState();
}

class _VSPBackButtonState extends State<VSPBackButton>
 with SingleTickerProviderStateMixin {
 late AnimationController _controller;
 late Animation<double> _scale;

 @override
 void initState() {
 super.initState();
 _controller = AnimationController(
 duration: const Duration(milliseconds: 120),
 vsync: this,
 lowerBound: 0.90,
 upperBound: 1.0,
 )..value = 1.0;
 _scale = Tween<double>(begin: 1.0, end: 0.90).animate(_controller);
 }

 @override
 void dispose() {
 _controller.dispose();
 super.dispose();
 }

 @override
 Widget build(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';

 return Container(
 margin: widget.margin,
 child: ScaleTransition(
 scale: _scale,
 child: GestureDetector(
 onTapDown: (_) => _controller.reverse(),
 onTapUp: (_) => _controller.forward(),
 onTapCancel: () => _controller.forward(),
 onTap: () {
 HapticFeedback.lightImpact();
 if (widget.onTap != null) {
 widget.onTap!();
 } else {
 Navigator.maybePop(context);
 }
 },
 child: Container(
 width: widget.size,
 height: widget.size,
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 shape: BoxShape.circle,
 border: Border.all(
 color: VSPColors.glassBorder,
 width: 1,
 ),
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.25),
 blurRadius: 8,
 offset: const Offset(0, 2),
 ),
 ],
 ),
 child: Center(
 child: Icon(
 isArabic
 ? Iconsax.arrow_right_3_copy
 : Iconsax.arrow_left_2_copy,
 color: widget.iconColor ?? Colors.white,
 size: 15,
 ),
 ),
 ),
 ),
 ),
 );
 }
}
