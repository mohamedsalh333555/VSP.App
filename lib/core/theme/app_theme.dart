import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/tokens/vsp_tokens.dart';

class AppTheme {
  static const Color darkBackground = VSPColors.background;
  static const Color neonGreen = VSPColors.accent;
  static const Color cardBackground = VSPColors.surface;
  static const Color textPrimary = VSPColors.textPrimary;
  static const Color textSecondary = VSPColors.textSecondary;
  static const Color divider = VSPColors.divider;

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
    
    final List<String> fallbackFonts = [tajawalFamily ?? 'Tajawal', 'sans-serif'];

    TextTheme applyFallback(TextTheme theme) {
      return theme.copyWith(
        displayLarge: theme.displayLarge?.copyWith(fontFamilyFallback: fallbackFonts),
        displayMedium: theme.displayMedium?.copyWith(fontFamilyFallback: fallbackFonts),
        displaySmall: theme.displaySmall?.copyWith(fontFamilyFallback: fallbackFonts),
        headlineLarge: theme.headlineLarge?.copyWith(fontFamilyFallback: fallbackFonts),
        headlineMedium: theme.headlineMedium?.copyWith(fontFamilyFallback: fallbackFonts),
        headlineSmall: theme.headlineSmall?.copyWith(fontFamilyFallback: fallbackFonts),
        titleLarge: theme.titleLarge?.copyWith(fontFamilyFallback: fallbackFonts),
        titleMedium: theme.titleMedium?.copyWith(fontFamilyFallback: fallbackFonts),
        titleSmall: theme.titleSmall?.copyWith(fontFamilyFallback: fallbackFonts),
        bodyLarge: theme.bodyLarge?.copyWith(fontFamilyFallback: fallbackFonts),
        bodyMedium: theme.bodyMedium?.copyWith(fontFamilyFallback: fallbackFonts),
        bodySmall: theme.bodySmall?.copyWith(fontFamilyFallback: fallbackFonts),
        labelLarge: theme.labelLarge?.copyWith(fontFamilyFallback: fallbackFonts),
        labelMedium: theme.labelMedium?.copyWith(fontFamilyFallback: fallbackFonts),
        labelSmall: theme.labelSmall?.copyWith(fontFamilyFallback: fallbackFonts),
      );
    }

    final TextTheme finalTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: VSPColors.textPrimary,
        letterSpacing: 1.0,
        height: 1.2,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: VSPColors.textPrimary,
        letterSpacing: 0.5,
        height: 1.2,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: VSPColors.textPrimary,
        height: 1.2,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
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
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 12,
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
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTheme.background, 
      
      colorScheme: const ColorScheme.dark(
        primary: VSPColors.accent,
        secondary: VSPColors.accent,
        surface: VSPColors.surface,
      ),

      fontFamily: poppinsFamily,
      fontFamilyFallback: [tajawalFamily ?? 'Tajawal', 'sans-serif'],

      textTheme: applyFallback(finalTextTheme),

      // 🛑 FIX: إعدادات معتمة صلبة 100% للـ BottomSheet والـ Dialog لمنع تسريب خلفية البوب اب
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: VSPColors.surface,
        elevation: 10,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: VSPColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: VSPColors.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: VSPColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: VSPColors.textPrimary,
          height: 1.2,
          fontFamily: poppinsFamily,
          fontFamilyFallback: fallbackFonts,
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
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.poppins().fontFamily,
            fontFamilyFallback: [tajawalFamily ?? 'Tajawal', 'sans-serif'],
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