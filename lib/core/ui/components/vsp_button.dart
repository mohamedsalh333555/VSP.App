import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tokens/vsp_tokens.dart';

class VSPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? height;
  final List<Color>? gradientColors;

  const VSPPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.height,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? 56;
    final bool hasCustomColor = color != null;
    final fontName = GoogleFonts.titilliumWeb().fontFamily;
    final tajawalFamily = GoogleFonts.tajawal().fontFamily;
    
    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        gradient: hasCustomColor 
            ? null 
            : LinearGradient(
                colors: gradientColors ?? [
                  VSPColors.accent,          // Volt Green Solid
                  VSPColors.accent,          // توحيد الأخضر الفولت الصاخب دون تشظي لوني
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasCustomColor ? color : null,
        boxShadow: [
          BoxShadow(
            color: (color ?? VSPColors.accent).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Transparent to show parent container gradient
          foregroundColor: textColor ?? Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor ?? Colors.black,
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontName,
                  fontFamilyFallback: [tajawalFamily ?? 'Tajawal', 'sans-serif'],
                  color: textColor ?? Colors.black,
                ),
              ),
      ),
    );
  }
}