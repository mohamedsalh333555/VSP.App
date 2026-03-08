import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/tokens/vsp_tokens.dart';

/// نظام التصميم الموحد لتطبيق VSP
class AppTheme {
  // الألوان والبيانات القديمة (سيتم حذفها تدريجياً لصالح Tokens)
  static const Color darkBackground = Color(0xFF0A0C0A); // Deeper, green-black tone
  static const Color neonGreen = Color(0xFF9FDF02);
  static const Color cardBackground = Color(0xFF161A16);    // Dark forest grey-green
  static const Color textPrimary = VSPColors.textPrimary;
  static const Color textSecondary = VSPColors.textSecondary;
  static const Color divider = Color(0xFF232A23);

  // New color definitions based on the instruction's intent
  static const Color background = Color(0xFF0A0C0A);
  static const Color surface = Color(0xFF161A16);
  static const Color surfaceAlt = Color(0xFF1F261F);
  static const Color inputFill = Color(0xFF232A23);
  static const Color accent = Color(0xFF9FDF02);
  static const Color accentSoft = Color(0x269FDF02);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTheme.background, // Using the new local definition
      fontFamily: 'Inter',

      colorScheme: const ColorScheme.dark(
        primary: VSPColors.accent,
        secondary: VSPColors.accent,
        surface: VSPColors.surface,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'AgencyFB',
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          letterSpacing: 1.0,
        ),
        displayMedium: TextStyle(
          fontFamily: 'AgencyFB',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          letterSpacing: 0.5,
        ),
        displaySmall: TextStyle(
          fontFamily: 'AgencyFB',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'AgencyFB',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: VSPColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: VSPColors.textSecondary,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: VSPColors.textSecondary,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: VSPColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: VSPColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: VSPColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: VSPColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: VSPColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VSPColors.accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
          ),
        textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VSPColors.inputFill,
        hintStyle: TextStyle(color: VSPColors.textSecondary.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPRadius.md),
          borderSide: const BorderSide(color: VSPColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
