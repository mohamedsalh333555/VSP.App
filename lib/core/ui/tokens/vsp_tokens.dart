import 'package:flutter/material.dart';

class VSPColors {
  // Deep Cyber Black Background
  static const background = Color(0xFF080B08); 

  // Dark Translucent Surface (الأسطح الداكنة الشفافة)
  static const surface = Color(0xCC131813);       // 80% opacity dark green-gray
  static const surfaceLight = Color(0xFF1D241D);  // Solid element background
  static const surfaceGlass = Color(0x801A211A);  // Frosted Glass
  static const surfaceAlt = Color(0xFF1E241D);

  // Accent Colors (الأخضر النيون المطابق للصورة)
  static const accent = Color(0xFF86E535);        // Electric Homex Green
  static const accentMuted = Color(0x3386E535);   // 20% Accent for subtles
  static const accentGlow = Color(0x1F86E535);
  static const accentSoft = Color(0x1F86E535);

  // Background Ambient Glow Color (السر في إضاءة الخلفية)
  static const ambientGlow = Color(0xFF183B14);

  // Text Colors
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  // Borders (إطارات دقيقة جداً ومضيئة)
  static const borderLight = Color(0x1AFFFFFF);   // 10% White
  static const borderAccent = Color(0x4086E535);  // Subtle Green Glow Border
  static const borderMedium = Color(0x33262626);

  // Legacy & Glassmorphism Compatibility Tokens
  static const Color glassSurface = Color(0x801A211A);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color black80 = Color(0xCC000000);
  static const Color white12 = Color(0x1FFFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white38 = Color(0x61FFFFFF);
  static const Color divider = Color(0xFF262626);
  static const Color inputFill = Color(0xFF1D241D);
  static const Color cardGreen = Color(0xFF1C4516);
  static const Color cardDarkGreen = Color(0xFF183B14);
  static const Color white = Color(0xFFFFFFFF);

  // Status Colors
  static const error = Color(0xFFFF4D4D);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // Dynamic Radial Gradients
  static const RadialGradient backgroundAura = RadialGradient(
    center: Alignment(-0.4, -0.2),
    radius: 1.2,
    colors: [
      Color(0xFF1C4516), // الإضاءة الخضراء في الخلفية
      Color(0xFF080B08), // السواد التام
    ],
    stops: [0.0, 0.7],
  );

  static const surfaceGradient = LinearGradient(
    colors: [Color(0xCC182018), Color(0xCC0D120D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF86E535), Color(0xFF65B820)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassBorderGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF), 
      Color(0x05FFFFFF), 
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentBorderGradient = LinearGradient(
    colors: [
      Color(0x8086E535), 
      Color(0x1086E535),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VSPRadius {
  static const double xs = 6.0;
  static const double sm = 12.0;
  static const double md = 20.0; 
  static const double lg = 28.0; // Squircle Radius المعتمد في Homex
  static const double xl = 32.0;
  static const double full = 999.0; // Pill Shape
}

class VSPSpacing {
  static const double xs = 6.0;
  static const double sm = 12.0;
  static const double md = 16.0; 
  static const double lg = 24.0; 
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class VSPEffects {
  static List<BoxShadow> neonGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get ambientDepth => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];
}

class VSPShadow {
  static List<BoxShadow> get subtle => VSPEffects.ambientDepth;
}

class VSPConstants {
  static const List<String> sports = ['Football', 'Basketball', 'Volleyball', 'Padel', 'Handball'];
}
