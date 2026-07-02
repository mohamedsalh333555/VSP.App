import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/tokens/vsp_tokens.dart';

/// نظام التصميم الموحد لتطبيق VSP
class AppTheme {
  // الألوان والبيانات القديمة (سيتم حذفها تدريجياً لصالح Tokens)
  static const Color darkBackground = VSPColors.background; // Pitch black background
  static const Color neonGreen = VSPColors.accent;
  static const Color cardBackground = VSPColors.surface;    // Pitch dark surface
  static const Color textPrimary = VSPColors.textPrimary;
  static const Color textSecondary = VSPColors.textSecondary;
  static const Color divider = VSPColors.divider;

  // New color definitions based on the instruction's intent
  static const Color background = VSPColors.background;
  static const Color surface = VSPColors.surface;
  static const Color surfaceAlt = VSPColors.surfaceAlt;
  static const Color inputFill = VSPColors.inputFill;
  static const Color accent = VSPColors.accent;
  static const Color accentSoft = VSPColors.accentSoft;

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);
    final poppinsFamily = GoogleFonts.poppins().fontFamily;
    final tajawalFamily = GoogleFonts.tajawal().fontFamily;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTheme.background, 
      
      colorScheme: const ColorScheme.dark(
        primary: VSPColors.accent,
        secondary: VSPColors.accent,
        surface: VSPColors.surface,
      ),

      fontFamily: poppinsFamily,
      fontFamilyFallback: [tajawalFamily!, 'sans-serif'],

      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          letterSpacing: 1.0,
          height: 1.2,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          letterSpacing: 0.5,
          height: 1.2,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          height: 1.2,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          height: 1.2,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: VSPColors.textPrimary,
          height: 1.3,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: VSPColors.textSecondary,
          height: 1.3,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: VSPColors.textSecondary,
          height: 1.2,
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
          height: 1.2,
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VSPColors.inputFill,
        hintStyle: TextStyle(
          color: VSPColors.textSecondary.withValues(alpha: 0.7),
        ),
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
