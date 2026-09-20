import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/vsp_tokens.dart';

class VSPPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final List<Color>? gradientColors;
  final Widget? icon;
  final IconData? iconData;
  final bool enableDebounce;

  const VSPPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.gradientColors,
    this.icon,
    this.iconData,
    this.enableDebounce = true,
  });

  @override
  State<VSPPrimaryButton> createState() => _VSPPrimaryButtonState();
}

class _VSPPrimaryButtonState extends State<VSPPrimaryButton> {
  bool _isDebouncing = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handlePress() {
    if (widget.enableDebounce) {
      HapticFeedback.mediumImpact();
      setState(() => _isDebouncing = true);
      widget.onPressed?.call();
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _isDebouncing = false);
        }
      });
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height ?? VSPSize.buttonHeight;
    final double w = widget.width ?? double.infinity;
    final bool hasCustomColor = widget.color != null;
    final bool isButtonDisabled = widget.isLoading || _isDebouncing || widget.onPressed == null;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    final Color effectiveTextColor = widget.textColor ?? Colors.black;

    return AbsorbPointer(
      absorbing: isButtonDisabled,
      child: Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPRadius.full),
          gradient: hasCustomColor
              ? null
              : LinearGradient(
                  colors: widget.gradientColors ?? [
                    VSPColors.accent,
                    VSPColors.accent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: hasCustomColor ? widget.color : null,
          boxShadow: [
            BoxShadow(
              color: (widget.color ?? VSPColors.accent).withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isButtonDisabled ? null : _handlePress,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: effectiveTextColor,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: effectiveTextColor,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      widget.icon!,
                      const SizedBox(width: 8),
                    ] else if (widget.iconData != null) ...[
                      Icon(
                        widget.iconData,
                        size: VSPIconSize.md,
                        color: effectiveTextColor,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: VSPTypography.buttonFontSize,
                            fontWeight: FontWeight.w800,
                            fontFamily: fontName,
                            fontFamilyFallback: fallbackFonts,
                            color: effectiveTextColor,
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

class VSPSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final IconData? iconData;

  const VSPSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
    this.icon,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? VSPSize.buttonHeight;
    final double w = width ?? double.infinity;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    return Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: VSPColors.surfaceAlt,
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(
          color: VSPColors.borderLight,
          width: VSPBorder.widthDefault,
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
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
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
                  ] else if (iconData != null) ...[
                    Icon(
                      iconData,
                      size: VSPIconSize.md,
                      color: VSPColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: VSPTypography.buttonFontSize,
                          fontWeight: FontWeight.w700,
                          fontFamily: fontName,
                          fontFamilyFallback: fallbackFonts,
                          color: VSPColors.textPrimary,
                        ),
                      ),
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
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final IconData? iconData;

  const VSPOutlinedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.borderColor,
    this.textColor,
    this.width,
    this.height,
    this.padding,
    this.icon,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height ?? 44;
    final Color borderC = borderColor ?? VSPColors.accent;
    final Color textC = textColor ?? borderC;
    const fontName = 'Poppins';
    const fallbackFonts = ['Tajawal', 'sans-serif'];

    return SizedBox(
      width: width,
      height: h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, h),
          side: BorderSide(color: borderC, width: 1.2),
          shape: const StadiumBorder(),
          foregroundColor: textC,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 6),
            ] else if (iconData != null) ...[
              Icon(
                iconData,
                size: VSPIconSize.sm,
                color: textC,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: VSPTypography.buttonFontSize,
                    fontWeight: FontWeight.w700,
                    fontFamily: fontName,
                    fontFamilyFallback: fallbackFonts,
                    color: textC,
                  ),
                ),
              ),
            ),
          ],
        ),
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