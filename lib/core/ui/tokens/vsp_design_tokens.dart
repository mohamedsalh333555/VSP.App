import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/device_performance.dart';

/// VSP Design System V2
///
/// This file is the canonical visual foundation for the application.
/// Existing UI values were preserved as the baseline; new structural tokens
/// are intentionally centralized here before screen-by-screen migration.
///
/// Governance:
/// - Feature code must consume semantic/component tokens, not raw visual values.
/// - Legacy aliases remain available through vsp_tokens.dart during migration.
/// - Values marked [PROPOSED] are gaps inferred from the existing VSP visual
///   language and must be reviewed before being treated as permanent identity rules.
abstract final class VSPDSColors {
  // Primitive palette — preserved from the current VSP UI.
  static const Color zinc950 = Color(0xFF09090B);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc750 = Color(0xFF323238);

  static const Color voltGreen = Color(0xFF9FDF02);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color zinc100 = Color(0xFFE4E4E7);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color gray500 = Color(0xFF6B7280);

  static const Color red500 = Color(0xFFEF4444);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color blue500 = Color(0xFF3B82F6);

  static const Color whatsappGreen = Color(0xFF25D366);

  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // Alpha primitives derived from the same palette.
  static const Color voltGreenSoft = Color(0x1F9FDF02);
  static const Color voltGreenMuted = Color(0x339FDF02);
  static const Color voltGreenBorder = Color(0x409FDF02);

  static const Color white05 = Color(0x0DFFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white15 = Color(0x26FFFFFF);
  static const Color white08 = Color(0x14FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white38 = Color(0x61FFFFFF);

  static const Color black80 = Color(0xCC000000);

  static const Color glassSurface = Color(0x73141417);
  static const Color glassSurfaceAlt = Color(0x991C1C20);
  static const Color glassBorder = Color(0x26FFFFFF);
  static const Color glassBorderAccent = Color(0x409FDF02);
  static const Color glassGlow = Color(0x1F9FDF02);
}

abstract final class VSPDSSemanticColors {
  static const Color background = VSPDSColors.zinc950;
  static const Color surface = VSPDSColors.zinc900;
  static const Color surfaceRaised = VSPDSColors.zinc800;
  static const Color surfaceElevated = VSPDSColors.zinc750;
  static const Color inputFill = Color(0xFF1E1E22);

  static const Color accent = VSPDSColors.voltGreen;
  static const Color accentSoft = VSPDSColors.voltGreenSoft;
  static const Color accentBorder = VSPDSColors.voltGreenBorder;

  static const Color textPrimary = VSPDSColors.zinc100;
  static const Color textSecondary = VSPDSColors.zinc400;
  static const Color textMuted = VSPDSColors.gray500;

  static const Color border = Color(0xFF262626);
  static const Color borderSubtle = VSPDSColors.white05;

  static const Color error = VSPDSColors.red500;
  static const Color warning = VSPDSColors.amber500;
  static const Color info = VSPDSColors.blue500;
  static const Color success = VSPDSColors.voltGreen;

  static const Color iconBadge = VSPDSColors.zinc800;
  static const Color iconBadgeElevated = VSPDSColors.zinc750;

  static const Color overlay = VSPDSColors.black80;
  static const Color focusRing = VSPDSColors.voltGreen;
}

abstract final class VSPDSSpacing {
  // Canonical base rhythm: 4px increments, with the existing VSP values retained.
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  // Component/context aliases.
  static const double pageHorizontal = md;
  static const double pageVertical = md;
  static const double section = lg;
  static const double cardPadding = md;
  static const double controlGap = xs;
  static const double fieldGap = sm;
  static const double listGap = sm;

  // The existing design uses 20px for text-field horizontal padding.
  static const double inputHorizontal = 20.0;
  static const double navigationBottomPadding = 6.0;
}

abstract final class VSPDSizes {
  static const double touchTarget = 48.0;
  static const double iconXs = 14.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconCompact = 22.0;
  static const double iconLg = 24.0;
  static const double iconXl = 32.0;

  static const double inputHeight = 56.0;
  static const double buttonHeight = 56.0;
  static const double compactButtonHeight = 48.0;

  static const double statusIcon = 14.0;
  static const double textButtonMinHeight = 44.0;
  static const double buttonProgress = 22.0;
  static const double progressStroke = 2.0;
  static const double navigationItemHeight = 58.0;
  static const double navigationIcon = 20.0;
  static const double navigationIconSelected = 24.0;
  static const double notificationDot = 8.0;
  static const double navigationNotificationTop = -1.0;
  static const double navigationNotificationRight = -2.0;
  static const double emptyIconSize = 28.0;
  static const double emptyIconPadding = 16.0;
  static const double navigationBottomPadding = 6.0;
  static const double stateIconBox = 56.0;
  static const double stateLoadingIndicator = 28.0;
  static const double avatarSm = 40.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;

  // VSP Copilot identity geometry: two four-point sparks with different sizes.
  static const double aiIcon = 24.0;
  static const double aiIconLarge = 16.0;
  static const double aiIconSmall = 9.0;
}

abstract final class VSPDSRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double full = 999.0;

  static const double button = full;
  static const double card = lg;
  static const double input = md;
  static const double chip = sm;
  static const double dialog = xl;
  static const double bottomSheet = xl;
}

abstract final class VSPDSBorders {
  static const double hairline = 1.0;
  static const double standard = 1.0;
  static const double focus = 2.0;
  static const double fieldFocus = 1.5;

  static const BorderSide divider = BorderSide(
    color: VSPDSSemanticColors.border,
    width: standard,
  );

  static const BorderSide subtle = BorderSide(
    color: VSPDSSemanticColors.borderSubtle,
    width: standard,
  );

  static const BorderSide accent = BorderSide(
    color: VSPDSSemanticColors.accentBorder,
    width: standard,
  );

  static const BorderSide focusRing = BorderSide(
    color: VSPDSSemanticColors.focusRing,
    width: focus,
  );
}

abstract final class VSPDSElevation {
  static const double none = 0.0;

  // Preserved from the current VSP shadow hierarchy.
  static const double subtleBlur = 12.0;
  static const double subtleOffsetY = 4.0;
  static const double mediumBlur = 20.0;
  static const double mediumOffsetY = 8.0;
  static const double strongBlur = 32.0;
  static const double strongOffsetY = 12.0;
  static const double modal = 10.0;
  static const double snackbar = 8.0;

  static const Color shadow = VSPDSColors.black80;

  static const BoxShadow subtle = BoxShadow(
    color: Color(0x40000000),
    blurRadius: subtleBlur,
    offset: Offset(0, subtleOffsetY),
  );

  static const BoxShadow medium = BoxShadow(
    color: Color(0x59000000),
    blurRadius: mediumBlur,
    offset: Offset(0, mediumOffsetY),
  );

  static const BoxShadow strong = BoxShadow(
    color: Color(0x73000000),
    blurRadius: strongBlur,
    offset: Offset(0, strongOffsetY),
  );
}

abstract final class VSPDSComponentEffects {
  static const BoxShadow buttonShadow = BoxShadow(
    color: Color(0x2E9FDF02),
    blurRadius: 12.0,
    offset: Offset(0, 4),
  );

  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 16.0,
    spreadRadius: 0.0,
    offset: Offset(0, 4),
  );

  static const BoxShadow navigationNotificationGlow = BoxShadow(
    color: Color(0x59EF4444),
    blurRadius: 4.0,
    spreadRadius: 1.0,
  );

  static const BoxShadow glassShadow = BoxShadow(
    color: VSPDSColors.glassGlow,
    blurRadius: 16.0,
    spreadRadius: 0.0,
    offset: Offset(0, 4),
  );
}

abstract final class VSPDSOpacity {
  static const double disabled = 0.38;
  static const double pressed = 0.12;
  static const double secondaryText = 0.70;
  static const double navigationGlass = 0.94;

  // [PROPOSED] interaction values inferred from the current visual language.
  static const double selectedSurface = 0.10;
  static const double border = 0.30;
  static const double focus = 1.0;
}

abstract final class VSPDSTypography {
  static const String latinFont = 'Poppins';
  static const String arabicFont = 'Tajawal';
  static const List<String> fallback = <String>[arabicFont, 'sans-serif'];

  // Existing VSP visual scale promoted to tokens.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 30.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.5,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 25.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    letterSpacing: 0.5,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    height: 1.30,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 13.0,
    fontWeight: FontWeight.w400,
    height: 1.30,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w400,
    height: 1.30,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 17.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w600,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w600,
    height: 1.20,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 16.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static const TextStyle compactButton = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static const TextStyle navigationSelected = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w800,
    height: 1.10,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle navigationUnselected = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w500,
    height: 1.10,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle status = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 11.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 10.0,
    fontWeight: FontWeight.w600,
    height: 1.20,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle stateTitle = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 15.0,
    fontWeight: FontWeight.w800,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle stateMessage = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    height: 1.40,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle stateBody = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle modalTitle = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 18.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle modalBody = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle calendarHeadline = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle calendarDay = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 14.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle calendarWeekday = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textSecondary,
  );

  static const TextStyle compactLabel = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.textPrimary,
  );

  static const TextStyle actionLabel = TextStyle(
    fontFamily: arabicFont,
    fontFamilyFallback: fallback,
    fontSize: 13.0,
    fontWeight: FontWeight.w700,
    height: 1.20,
    color: VSPDSSemanticColors.accent,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: latinFont,
    fontFamilyFallback: fallback,
    fontFeatures: <FontFeature>[
      FontFeature.tabularFigures(),
    ],
  );
}

abstract final class VSPDSMotion {
  // [PROPOSED] centralized timings; current screen behavior remains unchanged
  // until individual components are migrated to these tokens.
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration emphasis = Duration(milliseconds: 350);
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Duration navigationSwitch = Duration(milliseconds: 180);
  static const Duration buttonDebounce = Duration(milliseconds: 1500);

  static const Curve standardCurve = Curves.easeOutCubic;
}

abstract final class VSPDSBlur {
  static const double glassSigma = 16.0;
  static const double navigationGlassSigma = 20.0;
}

abstract final class VSPDSLayout {
  // [PROPOSED] reserved for the responsive system once desktop/tablet screens
  // are audited. No existing screen is changed by these values yet.
  static const double maxContentWidth = 1200.0;
  static const double tabletBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
}

abstract final class VSPDSAccessibility {
  static const double minimumTapTarget = VSPDSizes.touchTarget;
  static const double focusStroke = VSPDSBorders.focus;
  static const double stateMaxWidth = 420.0;
  static const double progressStroke = VSPDSizes.progressStroke;
  static const bool supportsReducedMotion = true;
}

abstract final class VSPDSBottomNavMetrics {
  static const double height = 64.0;
  static const double bottomMargin = 12.0;
  static const double contentClearance = 8.0;
  static const double fabBottomOffset = height + bottomMargin;
}

abstract final class VSPDSGlass {
  static bool get shouldUseBlur => DevicePerformance.tier != DeviceTier.low;

  static BoxDecoration bottomBarDecoration() {
    if (shouldUseBlur) {
      return const BoxDecoration(
        color: VSPDSColors.glassSurface,
      );
    }
    return BoxDecoration(
      color: VSPDSSemanticColors.surface.withValues(
        alpha: 0.96,
      ),
    );
  }
}

abstract final class VSPDSScrollPadding {
  static double bottom(
    BuildContext context, {
    bool hasFloatingNavBar = false,
    double extra = 8.0,
  }) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    if (hasFloatingNavBar) {
      return VSPDSBottomNavMetrics.height +
          VSPDSBottomNavMetrics.bottomMargin +
          safeBottom +
          extra;
    }
    return safeBottom + extra;
  }

  static EdgeInsets forList(
    BuildContext context, {
    bool hasFloatingNavBar = false,
    double horizontal = VSPDSSpacing.md,
    double top = VSPDSSpacing.md,
    double extra = 8.0,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottom(
        context,
        hasFloatingNavBar: hasFloatingNavBar,
        extra: extra,
      ),
    );
  }
}

abstract final class VSPDSGradients {
  static const RadialGradient backgroundAura = RadialGradient(
    center: Alignment(-0.4, -0.2),
    radius: 1.2,
    colors: <Color>[
      VSPDSColors.voltGreenSoft,
      VSPDSColors.zinc950,
    ],
    stops: <double>[0.0, 0.7],
  );

  static const LinearGradient surface = LinearGradient(
    colors: <Color>[
      VSPDSColors.zinc900,
      VSPDSColors.zinc800,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
