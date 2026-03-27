import 'package:flutter/material.dart';

class VSPColors {
  static const background = Color(0xFF000000); 
  static const surface = Color(0xFF121212);    
  static const surfaceAlt = Color(0xFF1C1C1E); 
  static const accent = Color(0xFF9FDF02);     
  static const accentSoft = Color(0x269FDF02);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1AA);
  static const divider = Color(0xFF262626);
  static const inputFill = Color(0xFF232A23);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const cardGreen = Color(0xFF2D4B15);
  static const cardDarkGreen = Color(0xFF1E330E);
  static const white12 = Color(0x1FFFFFFF);
  static const white38 = Color(0x61FFFFFF);
  static const white = Color(0xFFFFFFFF);
}

class VSPRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double full = 999.0;
}

class VSPSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class VSPShadow {
  static List<BoxShadow> get subtle => [
    BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 6)),
  ];
}

class VSPConstants {
  static const List<String> sports = ['Football', 'Basketball', 'Volleyball', 'Padel', 'Handball'];
}
