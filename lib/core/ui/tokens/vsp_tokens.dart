import 'package:flutter/material.dart';

class VSPColors {
  static const background = Color(0xFF0A0C0A); // Deeper, green-black tone
  static const surface = Color(0xFF161A16);    // Dark forest grey-green
  static const surfaceAlt = Color(0xFF1F261F); // Lighter forest grey-green
  static const divider = Color(0xFF232A23);
  static const inputFill = Color(0xFF232A23);

  static const accent = Color(0xFF9FDF02);
  static const accentSoft = Color(0x269FDF02);

  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B3B8); // Slightly lighter for better readability
}

class VSPRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const full = 999.0;
}

class VSPSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class VSPShadow {
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
  ];
}

class VSPCardHeight {
  static const stat = 110.0;
  static const hero = 140.0;
  static const heroFull = 200.0;
  static const horizontal = 220.0;
}
