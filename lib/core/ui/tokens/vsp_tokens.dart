import 'package:flutter/material.dart';

class VSPColors {
  static const background = Color(0xFF09090B); // Deep matte Zinc 950
  static const surface = Color(0xFF18181B);    // Zinc 900
  static const surfaceAlt = Color(0xFF27272A); // Zinc 800
  static const accent = Color(0xFF9FDF02);     
  static const accentSoft = Color(0x1F9FDF02);
  static const textPrimary = Color(0xFFE4E4E7);
  static const textSecondary = Color(0xFFA1A1AA);
  static const divider = Color(0xFF262626);
  static const inputFill = Color(0xFF232A23);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
  static const cardGreen = Color(0xFF2D4B15);
  static const cardDarkGreen = Color(0xFF1E330E);
  static const white12 = Color(0x1FFFFFFF);
  static const white38 = Color(0x61FFFFFF);
  static const white = Color(0xFFFFFFFF);
  
  static const Color accentGlow = Color(0x1F9FDF02); 
  static const Color borderLight = Color(0x1FFFFFFF); // 12% opacity translucent stroke
  static const Color borderMedium = Color(0x33262626); 
  static const Color glassSurface = Color(0x73141417); // Premium 45% dark frosted glass
  static const Color glassSurfaceAlt = Color(0x991C1C20); // 60% translucent surface
  static const Color glassBorder = Color(0x26FFFFFF); // 15% translucent white border
  static const Color glassBorderAccent = Color(0x409FDF02); // Translucent neon border stroke
  static const Color glassGlow = Color(0x1F9FDF02); // Glass neon glow
  static const double glassBlurSigma = 16.0; // High quality frosted blur
  static const Color black80 = Color(0xCC000000); 
  static const Color white24 = Color(0x3DFFFFFF); 
}

class VSPRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0; // Smoother
  static const double lg = 24.0; // Premium Elite standard
  static const double xl = 32.0; // Ultra smooth
  static const double full = 999.0;
}

class VSPSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 20.0; // More breathing room
  static const double lg = 32.0; // More breathing room
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class VSPShadow {
  static List<BoxShadow> get subtle => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6)),
  ];
}

class VSPConstants {
  static const List<String> sports = ['Football', 'Basketball', 'Volleyball', 'Padel', 'Handball'];
}
