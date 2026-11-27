// LEGACY COMPATIBILITY LAYER
//
// Design System V2 lives in `vsp_design_tokens.dart`.
// Do not add new visual tokens here. Existing aliases remain temporarily
// to keep the large feature tree source-compatible during migration.
//
// Migration target: Primitive → Semantic → Component → Pattern → Screen.
import 'package:flutter/material.dart';
import 'vsp_design_tokens.dart';
export '../../constants/sport_positions.dart';

/// ⚠️ ممنوع استخدام Colors.green أو أي hex أخضر مباشر في أي مكان بالتطبيق.
/// الأخضر الوحيد المعتمد هو accent (#9FDF02) أو accentSoft.
/// أي خلفية دائرية محايدة لازم تستخدم iconBadgeBg.
class VSPColors {
  static const background = VSPDSSemanticColors.background;
  static const surface = VSPDSSemanticColors.surface;
  static const surfaceAlt = VSPDSSemanticColors.surfaceRaised;
  static const surfaceLight = surfaceAlt;
  static const accent = VSPDSSemanticColors.accent;
  static const primary = accent;
  static const accentSoft = VSPDSSemanticColors.accentSoft;
  static const accentMuted = VSPDSColors.voltGreenMuted;
  static const accentGlow = VSPDSColors.glassGlow;

  /// خلفية دائرية موحدة لأي أيقونة داخل شارة/badge/status circle
  static const iconBadgeBg = VSPDSSemanticColors.iconBadge;
  static const iconBadgeBgElevated = VSPDSSemanticColors.iconBadgeElevated;

  static const textPrimary = VSPDSSemanticColors.textPrimary;
  static const textSecondary = VSPDSSemanticColors.textSecondary;
  static const textMuted = VSPDSSemanticColors.textMuted;
  static const divider = VSPDSSemanticColors.border;
  static const inputFill = VSPDSSemanticColors.inputFill;
  static const error = VSPDSSemanticColors.error;
  static const success = VSPDSSemanticColors.success;
  static const warning = VSPDSSemanticColors.warning;
  static const info = VSPDSSemanticColors.info;
  static const Color whatsApp = VSPDSColors.whatsappGreen;
  static const Color proAccent = accent;
  static const Color proAccentSoft = accentSoft;

  // Aliased to clean surface tokens to completely eliminate legacy muddy olive tints
  static const cardGreen = surfaceAlt;
  static const cardDarkGreen = surface;
  static const white12 = VSPDSColors.white12;
  static const white38 = VSPDSColors.white38;
  static const white = VSPDSColors.white;

  // Podiums & Medals
  static const Color medalGold = VSPDSColors.gold;
  static const Color medalSilver = VSPDSColors.silver;
  static const Color medalBronze = VSPDSColors.bronze;

  static const Color borderLight = VSPDSColors.white12;
  static const Color borderAccent = VSPDSSemanticColors.accentBorder;
  static const Color borderMedium = VSPDSSemanticColors.borderMedium;
  static const Color glassSurface = VSPDSColors.glassSurface;
  static const Color glassSurfaceAlt = VSPDSColors.glassSurfaceAlt;
  static const Color glassBorder = VSPDSColors.glassBorder;
  static const Color glassBorderAccent = VSPDSColors.glassBorderAccent;
  static const Color glassGlow = VSPDSColors.glassGlow;
  static const double glassBlurSigma = VSPDSBlur.glassSigma;
  static const Color black80 = VSPDSColors.black80;
  static const Color white24 = VSPDSColors.white24;

  static const RadialGradient backgroundAura = VSPDSGradients.backgroundAura;
  static const LinearGradient surfaceGradient = VSPDSGradients.surface;
}

class VSPRadius {
  static const double xs = VSPDSRadius.xs;
  static const double sm = VSPDSRadius.sm;
  static const double md = VSPDSRadius.md;
  static const double lg = VSPDSRadius.lg;
  static const double xl = VSPDSRadius.xl;
  static const double full = VSPDSRadius.full;

  /// Centralized Component Tokens (aliased to VSPDSRadius)
  static const double button = VSPDSRadius.button;
  static const double card = VSPDSRadius.card;
  static const double input = VSPDSRadius.input;
  static const double chip = VSPDSRadius.chip;
  static const double dialog = VSPDSRadius.dialog;
  static const double bottomSheet = VSPDSRadius.bottomSheet;
  static const double sheet = bottomSheet;
}

class VSPSize {
  static const double inputHeight = VSPDSizes.inputHeight;
  static const double buttonHeight = VSPDSizes.buttonHeight;
}

class VSPSpacing {
  // Backward-compatible aliases mapped to VSPDSSpacing (preserving exact px values).
  static const double xs = VSPDSSpacing.xxs;
  static const double sm = VSPDSSpacing.xs;
  static const double md = VSPDSSpacing.sm;
  static const double lg = VSPDSSpacing.md;
  static const double xl = VSPDSSpacing.inputHorizontal;
  static const double xxl = VSPDSSpacing.lg;
  static const double xxxl = VSPDSSpacing.xl;

  // Canonical 8px visual grid
  static const double grid1 = VSPDSSpacing.xs;
  static const double grid2 = VSPDSSpacing.md;
  static const double grid3 = VSPDSSpacing.lg;
  static const double grid4 = VSPDSSpacing.xl;
  static const double page = VSPDSSpacing.pageHorizontal;
  static const double section = VSPDSSpacing.section;
  static const double actionGap = VSPDSSpacing.controlGap;
}

/// Shared geometry for the floating bottom navigation and content that must clear it.
/// Keeping these values in one place prevents nested Scaffolds from drifting apart.
/// @deprecated Use VSPDSBottomNavMetrics. Retained only as a source-compatible alias.
class VSPBottomNavBarMetrics {
  static const double height = VSPDSBottomNavMetrics.height;
  static const double bottomMargin = VSPDSBottomNavMetrics.bottomMargin;
  static const double contentClearance = VSPDSBottomNavMetrics.contentClearance;
  static const double fabBottomOffset = VSPDSBottomNavMetrics.fabBottomOffset;
}

class VSPStates {
  static const double disabledOpacity = VSPDSOpacity.disabled;
  static const double pressedOverlayOpacity = VSPDSOpacity.pressed;

  static Color disabled(Color base) => base.withValues(alpha: disabledOpacity);
  static Color pressedOverlay() =>
      VSPDSColors.white.withValues(alpha: pressedOverlayOpacity);
}

class VSPShadow {
  static const BoxShadow subtle = VSPDSElevation.subtle;
  static const BoxShadow medium = VSPDSElevation.medium;
  static const BoxShadow strong = VSPDSElevation.strong;

  static List<BoxShadow> get subtleList => [subtle];
  static List<BoxShadow> get mediumList => [medium];
  static List<BoxShadow> get strongList => [strong];
}

class VSPGlass {
  static bool get shouldUseBlur => VSPDSGlass.shouldUseBlur;

  static BoxDecoration bottomBarDecoration() =>
      VSPDSGlass.bottomBarDecoration();
}

class VSPTypography {
  static const TextStyle numericStyle = VSPDSTypography.numeric;
}

class VSPScrollPadding {
  static double bottom(
    BuildContext context, {
    bool hasFloatingNavBar = false,
    double extra = 8.0,
  }) =>
      VSPDSScrollPadding.bottom(
        context,
        hasFloatingNavBar: hasFloatingNavBar,
        extra: extra,
      );

  static EdgeInsets forList(
    BuildContext context, {
    bool hasFloatingNavBar = false,
    double horizontal = VSPDSSpacing.md,
    double top = VSPDSSpacing.md,
    double extra = 8.0,
  }) =>
      VSPDSScrollPadding.forList(
        context,
        hasFloatingNavBar: hasFloatingNavBar,
        horizontal: horizontal,
        top: top,
        extra: extra,
      );
}
