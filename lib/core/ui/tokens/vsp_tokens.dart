// LEGACY COMPATIBILITY LAYER
//
// All visual values now resolve to Design System V2. Keep these names only
// while feature files migrate; do not define new values in this file.
//
// Migration target: Primitive → Semantic → Component → Pattern → Screen.
import 'package:flutter/material.dart';
import 'vsp_design_tokens.dart';

// Re-export the canonical navigation geometry through the legacy token facade
// so existing feature imports resolve the single source of truth.
export 'vsp_design_tokens.dart' show VSPBottomNavMetrics;

/// Backward-compatible aliases. VSP DS V2 is the only visual source of truth.
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
  static const Color black = VSPDSColors.black;
  static const Color transparent = VSPDSColors.transparent;
  static const Color white05 = VSPDSColors.white05;
  static const Color white08 = VSPDSColors.white08;
  static const Color white10 = VSPDSColors.white10;
  static const Color white15 = VSPDSColors.white15;
  static const Color white24 = VSPDSColors.white24;
  static const Color white38 = VSPDSColors.white38;
  static const Color whatsApp = VSPDSColors.whatsappGreen;
  static const Color proAccent = accent;
  static const Color proAccentSoft = accentSoft;
  static const cardGreen = surfaceAlt;
  static const cardDarkGreen = surface;
  static const white12 = VSPDSColors.white12;
  static const white38 = VSPDSColors.white38;
  static const white = VSPDSColors.white;
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
  static const double button = VSPDSRadius.button;
  static const double card = VSPDSRadius.card;
  static const double input = VSPDSRadius.input;
  static const double chip = VSPDSRadius.chip;
  static const double dialog = VSPDSRadius.dialog;
  static const double bottomSheet = VSPDSRadius.bottomSheet;
  static const double sheet = bottomSheet;
}

class VSPSize {
  static const double touchTarget = VSPDSizes.touchTarget;
  static const double iconXs = VSPDSizes.iconXs;
  static const double iconSm = VSPDSizes.iconSm;
  static const double iconMd = VSPDSizes.iconMd;
  static const double iconCompact = VSPDSizes.iconCompact;
  static const double iconLg = VSPDSizes.iconLg;
  static const double iconXl = VSPDSizes.iconXl;
  static const double inputHeight = VSPDSizes.inputHeight;
  static const double buttonHeight = VSPDSizes.buttonHeight;
  static const double compactButtonHeight = VSPDSizes.compactButtonHeight;
  static const double statusIcon = VSPDSizes.statusIcon;
  static const double textButtonMinHeight = VSPDSizes.textButtonMinHeight;
  static const double buttonProgress = VSPDSizes.buttonProgress;
  static const double progressStroke = VSPDSizes.progressStroke;
  static const double navigationItemHeight = VSPDSizes.navigationItemHeight;
  static const double navigationIcon = VSPDSizes.navigationIcon;
  static const double navigationIconSelected = VSPDSizes.navigationIconSelected;
  static const double notificationDot = VSPDSizes.notificationDot;
  static const double navigationNotificationTop = VSPDSizes.navigationNotificationTop;
  static const double navigationNotificationRight = VSPDSizes.navigationNotificationRight;
  static const double emptyIconSize = VSPDSizes.emptyIconSize;
  static const double emptyIconPadding = VSPDSizes.emptyIconPadding;
  static const double navigationBottomPadding = VSPDSizes.navigationBottomPadding;
  static const double stateIconBox = VSPDSizes.stateIconBox;
  static const double stateLoadingIndicator = VSPDSizes.stateLoadingIndicator;
  static const double avatarSm = VSPDSizes.avatarSm;
  static const double avatarMd = VSPDSizes.avatarMd;
  static const double avatarLg = VSPDSizes.avatarLg;
  static const double aiIcon = VSPDSizes.aiIcon;
  static const double aiIconLarge = VSPDSizes.aiIconLarge;
  static const double aiIconSmall = VSPDSizes.aiIconSmall;
}

class VSPSpacing {
  // Exact legacy numeric values, expressed through canonical V2 spacing tokens.
  static const double xs = VSPDSSpacing.xxs;
  static const double sm = VSPDSSpacing.xs;
  static const double md = VSPDSSpacing.sm;
  static const double lg = VSPDSSpacing.md;
  static const double xl = VSPDSSpacing.compact;
  static const double xxl = VSPDSSpacing.lg;
  static const double xxxl = VSPDSSpacing.xl;
  static const double grid1 = VSPDSSpacing.xs;
  static const double grid2 = VSPDSSpacing.md;
  static const double grid3 = VSPDSSpacing.lg;
  static const double grid4 = VSPDSSpacing.xl;
  static const double page = grid2;
  static const double section = grid3;
  static const double actionGap = grid1;
}

/// Legacy compatibility alias. New code must use VSPBottomNavMetrics.
@Deprecated('Use VSPBottomNavMetrics')
class VSPBottomNavBarMetrics {
  static const double height = VSPBottomNavMetrics.height;
  static const double bottomMargin = VSPBottomNavMetrics.bottomMargin;
  static const double contentClearance = VSPBottomNavMetrics.contentClearance;
  static const double fabBottomOffset = VSPBottomNavMetrics.fabBottomOffset;
}

class VSPStates {
  static const double disabledOpacity = VSPDSOpacity.disabled;
  static const double pressedOverlayOpacity = VSPDSOpacity.pressed;

  static Color disabled(Color base) =>
      base.withValues(alpha: disabledOpacity);

  static Color pressedOverlay() => VSPDSColors.white12;
}

class VSPShadow {
  static const BoxShadow subtle = VSPDSElevation.subtle;
  static const BoxShadow medium = VSPDSElevation.medium;
  static const BoxShadow strong = VSPDSElevation.strong;

  static List<BoxShadow> get subtleList => <BoxShadow>[subtle];
  static List<BoxShadow> get mediumList => <BoxShadow>[medium];
  static List<BoxShadow> get strongList => <BoxShadow>[strong];
}

class VSPGlass {
  static bool get shouldUseBlur => VSPDSGlass.shouldUseBlur;

  static BoxDecoration bottomBarDecoration() =>
      VSPDSGlass.bottomBarDecoration();
}

class VSPTypography {
  static const TextStyle displayLarge = VSPDSTypography.displayLarge;
  static const TextStyle displayMedium = VSPDSTypography.displayMedium;
  static const TextStyle displaySmall = VSPDSTypography.displaySmall;
  static const TextStyle headlineLarge = VSPDSTypography.headlineLarge;
  static const TextStyle headlineMedium = VSPDSTypography.headlineMedium;
  static const TextStyle headlineSmall = VSPDSTypography.headlineSmall;
  static const TextStyle titleLarge = VSPDSTypography.titleLarge;
  static const TextStyle titleMedium = VSPDSTypography.titleMedium;
  static const TextStyle titleSmall = VSPDSTypography.titleSmall;
  static const TextStyle bodyLarge = VSPDSTypography.bodyLarge;
  static const TextStyle bodyMedium = VSPDSTypography.bodyMedium;
  static const TextStyle bodySmall = VSPDSTypography.bodySmall;
  static const TextStyle labelLarge = VSPDSTypography.labelLarge;
  static const TextStyle labelMedium = VSPDSTypography.labelMedium;
  static const TextStyle button = VSPDSTypography.button;
  static const TextStyle compactButton = VSPDSTypography.compactButton;
  static const TextStyle navigationSelected = VSPDSTypography.navigationSelected;
  static const TextStyle navigationUnselected = VSPDSTypography.navigationUnselected;
  static const TextStyle numericStyle = VSPDSTypography.numeric;
}

class VSPConstants {
 /// Centralized Active Sports Control
 /// Currently: Football only. Future sports (e.g. 'Padel') can be enabled here.
 static const List<String> activeSports = ['Football'];
 static const List<String> sports = activeSports;
}

class SportPosition {
 final String code;
 final String nameAr;
 final String nameEn;
 const SportPosition({required this.code, required this.nameAr, required this.nameEn});
}

class SportPositionsRegistry {
 static const Map<String, List<SportPosition>> positions = {
 'Football': [
 SportPosition(code: 'GK', nameAr: 'حارس مرمى', nameEn: 'Goalkeeper'),
 SportPosition(code: 'DF', nameAr: 'مدافع', nameEn: 'Defender'),
 SportPosition(code: 'MF', nameAr: 'وسط', nameEn: 'Midfielder'),
 SportPosition(code: 'FW', nameAr: 'مهاجم', nameEn: 'Forward'),
 ],
 'Padel': [
 SportPosition(code: 'Drive', nameAr: 'يمين (Drive)', nameEn: 'Drive'),
 SportPosition(code: 'Revés', nameAr: 'يسار (Revés)', nameEn: 'Revés'),
 SportPosition(code: 'All-Round', nameAr: 'شامل (All-Round)', nameEn: 'All-Round'),
 ],
 'Basketball': [
 SportPosition(code: 'PG', nameAr: 'صانع ألعاب (PG)', nameEn: 'Point Guard'),
 SportPosition(code: 'SG', nameAr: 'مدافع مسدد (SG)', nameEn: 'Shooting Guard'),
 SportPosition(code: 'SF', nameAr: 'جناح (SF)', nameEn: 'Small Forward'),
 SportPosition(code: 'PF', nameAr: 'لاعب هجوم قوي (PF)', nameEn: 'Power Forward'),
 SportPosition(code: 'C', nameAr: 'لاعب ارتكاز (C)', nameEn: 'Center'),
 ],
 'Volleyball': [
 SportPosition(code: 'Setter', nameAr: 'مُعِد', nameEn: 'Setter'),
 SportPosition(code: 'Spiker', nameAr: 'ضارب', nameEn: 'Spiker'),
 SportPosition(code: 'Libero', nameAr: 'ليبرو', nameEn: 'Libero'),
 SportPosition(code: 'Blocker', nameAr: 'حائط صد', nameEn: 'Blocker'),
 ],
 'Handball': [
 SportPosition(code: 'GK', nameAr: 'حارس مرمى', nameEn: 'Goalkeeper'),
 SportPosition(code: 'Wing', nameAr: 'جناح', nameEn: 'Wing'),
 SportPosition(code: 'Back', nameAr: 'ظهير', nameEn: 'Back'),
 SportPosition(code: 'Pivot', nameAr: 'دائرة', nameEn: 'Pivot'),
 SportPosition(code: 'Playmaker', nameAr: 'صانع ألعاب', nameEn: 'Playmaker'),
 ],
 };

 static String getDefaultPosition(String sport) {
 switch (sport) {
 case 'Padel':
 return 'All-Round';
 case 'Basketball':
 return 'SF';
 case 'Volleyball':
 return 'Spiker';
 case 'Handball':
 return 'Wing';
 case 'Football':
 default:
 return 'FW';
 }
 }

 static List<SportPosition> getPositionsForSport(String sport) {
 return positions[sport] ?? positions['Football']!;
 }
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
