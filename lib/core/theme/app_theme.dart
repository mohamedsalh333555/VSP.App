import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const String poppinsFamily = 'Poppins';
  static const String tajawalFamily = 'Tajawal';
  static const List<String> fallbackFonts = [tajawalFamily, 'sans-serif'];

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme.apply(
      fontFamily: poppinsFamily,
    );

    TextTheme applyFallback(TextTheme theme) {
      return theme.copyWith(
        displayLarge: theme.displayLarge?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        displayMedium: theme.displayMedium?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        displaySmall: theme.displaySmall?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        headlineLarge: theme.headlineLarge?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        headlineMedium: theme.headlineMedium?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        headlineSmall: theme.headlineSmall?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        titleLarge: theme.titleLarge?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        titleMedium: theme.titleMedium?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        titleSmall: theme.titleSmall?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        bodyLarge: theme.bodyLarge?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        bodyMedium: theme.bodyMedium?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        bodySmall: theme.bodySmall?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        labelLarge: theme.labelLarge?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        labelMedium: theme.labelMedium?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
        labelSmall: theme.labelSmall?.copyWith(fontFamily: poppinsFamily, fontFamilyFallback: fallbackFonts),
      );
    }

    final TextTheme finalTextTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: VSPColors.textPrimary,
        letterSpacing: 0.5,
        height: 1.2,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: 25,
        fontWeight: FontWeight.bold,
        color: VSPColors.textPrimary,
        letterSpacing: 0.5,
        height: 1.2,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: VSPColors.textPrimary,
        height: 1.2,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: VSPColors.textPrimary,
        height: 1.2,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: VSPColors.textPrimary,
        height: 1.3,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: VSPColors.textSecondary,
        height: 1.3,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: VSPColors.textSecondary,
        height: 1.3,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: 11,
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
      fontFamilyFallback: fallbackFonts,

      textTheme: applyFallback(finalTextTheme),

      // FIX: إعدادات معتمة صلبة 100% للـ BottomSheet والـ Dialog لمنع تسريب خلفية البوب اب
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
        titleTextStyle: const TextStyle(fontFamily: tajawalFamily, color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: const TextStyle(fontFamily: tajawalFamily, color: VSPColors.textSecondary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VSPRadius.lg),
        ),
      ),

      datePickerTheme: const DatePickerThemeData(
        backgroundColor: VSPColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: VSPColors.surface,
        headerForegroundColor: VSPColors.accent,
        headerHelpStyle: TextStyle(fontFamily: tajawalFamily, color: VSPColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
        headerHeadlineStyle: TextStyle(fontFamily: tajawalFamily, color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        dayStyle: TextStyle(fontFamily: tajawalFamily, color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        weekdayStyle: TextStyle(fontFamily: tajawalFamily, color: VSPColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
        yearStyle: TextStyle(fontFamily: tajawalFamily, color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        cancelButtonStyle: ButtonStyle(
          textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: tajawalFamily, color: VSPColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
          foregroundColor: WidgetStatePropertyAll(VSPColors.accent),
        ),
        confirmButtonStyle: ButtonStyle(
          textStyle: WidgetStatePropertyAll(TextStyle(fontFamily: tajawalFamily, color: VSPColors.accent, fontSize: 14, fontWeight: FontWeight.bold)),
          foregroundColor: WidgetStatePropertyAll(VSPColors.accent),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: VSPColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: VSPColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
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
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: poppinsFamily,
            fontFamilyFallback: fallbackFonts,
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

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothFadeTransitionsBuilder(),
          TargetPlatform.iOS: SmoothFadeTransitionsBuilder(),
          TargetPlatform.windows: SmoothFadeTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Custom high-performance transition builder that replaces heavy Android Zoom/Slide
/// with an ultra-responsive 60fps fade transition.
class SmoothFadeTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothFadeTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
      child: child,
    );
  }
}