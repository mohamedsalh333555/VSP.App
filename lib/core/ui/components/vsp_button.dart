import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

class VSPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? height;
  final List<Color>? gradientColors;
  final Widget? icon;

  const VSPPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.height,
    this.gradientColors,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? VSPSize.buttonHeight;
    final bool hasCustomColor = color != null;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.full),
        gradient: hasCustomColor
            ? null
            : LinearGradient(
                colors: gradientColors ?? [
                  VSPColors.accent,
                  VSPColors.accent,
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
          backgroundColor: Colors.transparent,
          foregroundColor: textColor ?? Colors.black,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: fontName,
                      fontFamilyFallback: fallbackFonts,
                      color: textColor ?? Colors.black,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class VSPSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? height;
  final Widget? icon;

  const VSPSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.height,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? VSPSize.buttonHeight;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(
          color: VSPColors.borderLight,
          width: 1.0,
        ),
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: VSPColors.textPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VSPColors.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: fontName,
                      fontFamilyFallback: fallbackFonts,
                      color: VSPColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class VSPOutlinedButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;
  final double? height;
  final Widget? icon;

  const VSPOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor,
    this.textColor,
    this.height,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? 44;
    final Color borderC = borderColor ?? VSPColors.accent;
    final Color textC = textColor ?? borderC;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, h),
        side: BorderSide(color: borderC, width: 1.2),
        shape: const StadiumBorder(),
        foregroundColor: textC,
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: fontName,
              fontFamilyFallback: fallbackFonts,
              color: textC,
            ),
          ),
        ],
      ),
    );
  }
}

class VSPActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isOutlined;
  final IconData? icon;

  const VSPActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.color = VSPColors.accent,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNeon = color == VSPColors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isOutlined
              ? VSPColors.surfaceAlt.withValues(alpha: 0.6)
              : (isNeon ? VSPColors.accent : color.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(VSPRadius.sm),
          border: Border.all(
            color: isOutlined ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
            width: 1.0,
          ),
          boxShadow: (!isOutlined && isNeon)
              ? [
                  BoxShadow(
                    color: VSPColors.accent.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isOutlined ? VSPColors.textSecondary : (isNeon ? Colors.black : color),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isOutlined ? VSPColors.textPrimary : (isNeon ? Colors.black : color),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}