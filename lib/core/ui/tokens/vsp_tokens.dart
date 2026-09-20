import 'package:flutter/material.dart';

class VSPColors {
 static const background = Color(0xFF09090B); // Deep matte Zinc 950 (100% Solid)
 static const surface = Color(0xFF18181B); // Zinc 900 (100% Solid Opaque)
 static const surfaceAlt = Color(0xFF27272A); // Zinc 800 (100% Solid Opaque)
 static const surfaceLight = Color(0xFF1D241D); 
 static const accent = Color(0xFF9FDF02); 
 static const accentSoft = Color(0x1F9FDF02);
 static const accentMuted = Color(0x339FDF02);
 static const accentGlow = Color(0x1F9FDF02);
 static const textPrimary = Color(0xFFE4E4E7);
 static const textSecondary = Color(0xFFA1A1AA);
 static const textMuted = Color(0xFF6B7280);
 static const divider = Color(0xFF262626);
 static const inputFill = Color(0xFF1E1E22);
 static const error = Color(0xFFEF4444);
 static const success = Color(0xFF22C55E);
 static const warning = Color(0xFFA1A1AA);
 static const info = Color(0xFF3B82F6);
 static const cardGreen = Color(0xFF2D4B15);
 static const cardDarkGreen = Color(0xFF1E330E);
 static const white12 = Color(0x1FFFFFFF);
 static const white38 = Color(0x61FFFFFF);
 static const white = Color(0xFFFFFFFF);
 
 static const Color borderLight = Color(0x1FFFFFFF); 
 static const Color borderAccent = Color(0x409FDF02);
 static const Color borderMedium = Color(0x33262626); 
 static const Color glassSurface = Color(0x73141417); 
 static const Color glassSurfaceAlt = Color(0x991C1C20); 
 static const Color glassBorder = Color(0x26FFFFFF); 
 static const Color glassBorderAccent = Color(0x409FDF02); 
 static const Color glassGlow = Color(0x1F9FDF02); 
 static const double glassBlurSigma = 16.0; 
 static const Color black80 = Color(0xCC000000); 
 static const Color white24 = Color(0x3DFFFFFF); 

 static const RadialGradient backgroundAura = RadialGradient(
 center: Alignment(-0.4, -0.2),
 radius: 1.2,
 colors: [
 Color(0xFF1E330E),
 Color(0xFF09090B),
 ],
 stops: [0.0, 0.7],
 );

 static const surfaceGradient = LinearGradient(
 colors: [Color(0xFF18181B), Color(0xFF27272A)],
 begin: Alignment.topLeft,
 end: Alignment.bottomRight,
 );
}

class VSPRadius {
 static const double xs = 4.0;
 static const double sm = 8.0;
 static const double md = 16.0; 
 static const double lg = 24.0; 
 static const double xl = 32.0; 
 static const double full = 999.0;

 /// Centralized Component Tokens
 /// Modifying any token below instantly updates all matching components across the entire app!
 static const double button = full; // All primary, secondary, and social buttons
 static const double card = lg; // All stadium cards, team cards, match cards, containers
 static const double input = md; // All text fields and input boxes
 static const double chip = sm; // All filter chips, tags, position badges
 static const double dialog = xl; // All popup dialogs and modals
 static const double bottomSheet = xl; // All bottom sheets
}

class VSPSize {
 /// Standard Unified Height (56.0px) for All Single-Line Input Fields
 static const double inputHeight = 56.0;

 /// Standard Unified Height (56.0px) for All Primary, Secondary & Social Buttons
 static const double buttonHeight = 56.0;
}

class VSPSpacing {
 static const double xs = 4.0;
 static const double sm = 8.0;
 static const double md = 20.0; 
 static const double lg = 32.0; 
 static const double xl = 32.0;
 static const double xxl = 48.0;
}

class VSPShadow {
 static List<BoxShadow> get subtle => [
 BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6)),
 ];
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
      return 64.0 + 12.0 + safeBottom + extra;
    }
    return safeBottom + extra;
  }

  static EdgeInsets forList(BuildContext context, {bool hasFloatingNavBar = false, double horizontal = 16.0, double top = 16.0, double extra = 8.0}) {
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom(context, hasFloatingNavBar: hasFloatingNavBar, extra: extra));
  }
}
