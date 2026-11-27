// LEGACY COMPATIBILITY LAYER
//
// Design System V2 lives in `vsp_design_tokens.dart`.
// Do not add new visual tokens here. Existing aliases remain temporarily
// to keep the large feature tree source-compatible during migration.
//
// Migration target: Primitive → Semantic → Component → Pattern → Screen.
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/device_performance.dart';
import 'vsp_design_tokens.dart';

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
  static const Color borderMedium = Color(0x33262626);
  static const Color glassSurface = VSPDSColors.glassSurface;
  static const Color glassSurfaceAlt = VSPDSColors.glassSurfaceAlt;
  static const Color glassBorder = VSPDSColors.glassBorder;
  static const Color glassBorderAccent = VSPDSColors.glassBorderAccent;
  static const Color glassGlow = VSPDSColors.glassGlow;
  static const double glassBlurSigma = 16.0;
  static const Color black80 = VSPDSColors.black80;
  static const Color white24 = VSPDSColors.white24;

  static const RadialGradient backgroundAura = RadialGradient(
    center: Alignment(-0.4, -0.2),
    radius: 1.2,
    colors: [
      VSPDSColors.voltGreenSoft,
      VSPDSColors.zinc950,
    ],
    stops: [0.0, 0.7],
  );

  static const surfaceGradient = LinearGradient(
    colors: [VSPDSColors.zinc900, VSPDSColors.zinc800],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
  static const double disabledOpacity = 0.38;
  static const double pressedOverlayOpacity = 0.12;

  static Color disabled(Color base) => base.withValues(alpha: disabledOpacity);
  static Color pressedOverlay() => Colors.white.withValues(alpha: pressedOverlayOpacity);
}

class VSPShadow {
  static const BoxShadow subtle = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );
  static const BoxShadow medium = BoxShadow(
    color: Color(0x59000000),
    blurRadius: 20,
    offset: Offset(0, 8),
  );
  static const BoxShadow strong = BoxShadow(
    color: Color(0x73000000),
    blurRadius: 32,
    offset: Offset(0, 12),
  );

  static List<BoxShadow> get subtleList => [subtle];
  static List<BoxShadow> get mediumList => [medium];
  static List<BoxShadow> get strongList => [strong];
}

class VSPGlass {
  static bool get shouldUseBlur => DevicePerformance.tier != DeviceTier.low;

  static BoxDecoration bottomBarDecoration() {
    if (shouldUseBlur) {
      return const BoxDecoration(color: VSPColors.glassSurface);
    }
    return BoxDecoration(color: VSPColors.surface.withValues(alpha: 0.96));
  }
}

class VSPTypography {
  static const TextStyle numericStyle = TextStyle(
    fontFamily: 'Poppins',
    fontFamilyFallback: ['Tajawal', 'sans-serif'],
    fontFeatures: [FontFeature.tabularFigures()],
  );
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
  /// Calculates bottom padding for scroll views to scroll past floating navbar or bottom action bars cleanly.
  static double bottom(BuildContext context, {bool hasFloatingNavBar = false, double extra = 8.0}) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    if (hasFloatingNavBar) {
      // 64 navbar height + 12 bottom margin + safeArea inset + snug clearance (~96px)
      return VSPBottomNavBarMetrics.height + VSPBottomNavBarMetrics.bottomMargin + safeBottom + extra;
    }
    return safeBottom + extra;
  }

  static EdgeInsets forList(BuildContext context, {bool hasFloatingNavBar = false, double horizontal = 16.0, double top = 16.0, double extra = 8.0}) {
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom(context, hasFloatingNavBar: hasFloatingNavBar, extra: extra));
  }
}
