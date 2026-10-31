import 'package:flutter/material.dart';
import '../tokens/vsp_design_tokens.dart';

/// Canonical VSP primary action.
///
/// API is intentionally backward-compatible so feature screens can migrate
/// without changing business behavior or navigation.
class VSPPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final Color? textColor;
  final double? height;
  final List<Color>? gradientColors;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;

  const VSPPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
    this.height,
    this.gradientColors,
    this.width,
    this.padding,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedHeight = height ?? VSPDSizes.buttonHeight;
    final resolvedColor = color ?? VSPDSSemanticColors.accent;
    final resolvedTextColor = textColor ?? VSPDSColors.black;
    final isDisabled = onPressed == null || isLoading;
    final effectiveTextColor = isDisabled
        ? resolvedTextColor.withValues(
            alpha: resolvedTextColor.a * VSPDSOpacity.disabled,
          )
        : resolvedTextColor;
    final effectiveGradientColors = gradientColors?.map((gradientColor) {
      return isDisabled
          ? gradientColor.withValues(
              alpha: gradientColor.a * VSPDSOpacity.disabled,
            )
          : gradientColor;
    }).toList(growable: false);

    return SizedBox(
      height: resolvedHeight,
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VSPDSRadius.button),
          gradient: gradientColors == null
              ? null
              : LinearGradient(
                  colors: effectiveGradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: gradientColors == null
              ? (isDisabled
                  ? resolvedColor.withValues(alpha: VSPDSOpacity.disabled)
                  : resolvedColor)
              : null,
          boxShadow: isDisabled
              ? const <BoxShadow>[]
              : const <BoxShadow>[VSPDSComponentEffects.buttonShadow],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: effectiveTextColor,
            disabledForegroundColor:
                resolvedTextColor.withValues(alpha: VSPDSOpacity.disabled),
            elevation: VSPDSElevation.none,
            shadowColor: Colors.transparent,
            minimumSize: Size.zero,
            padding: padding ?? EdgeInsets.zero,
            shape: const StadiumBorder(),
            overlayColor: VSPDSColors.white12,
          ),
          child: isLoading
              ? SizedBox(
                  width: VSPDSizes.buttonProgress,
                  height: VSPDSizes.buttonProgress,
                  child: CircularProgressIndicator(
                    strokeWidth: VSPDSizes.progressStroke,
                    color: effectiveTextColor,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: VSPDSizes.iconMd, color: effectiveTextColor),
                      const SizedBox(width: VSPDSSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: VSPDSTypography.button.copyWith(
                          color: effectiveTextColor,
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
