import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ui/tokens/vsp_design_tokens.dart';

/// Global VSP theme backed by Design System V2 tokens.
///
/// This file defines Flutter component defaults only. Product/business logic
/// remains outside the design-system layer.
class AppTheme {
  static ThemeData get darkTheme {
    final textTheme = TextTheme(
      displayLarge: VSPDSTypography.displayLarge,
      displayMedium: VSPDSTypography.displayMedium,
      displaySmall: VSPDSTypography.displaySmall,
      headlineLarge: VSPDSTypography.headlineLarge,
      headlineMedium: VSPDSTypography.headlineMedium,
      headlineSmall: VSPDSTypography.headlineSmall,
      titleLarge: VSPDSTypography.titleLarge,
      titleMedium: VSPDSTypography.titleMedium,
      titleSmall: VSPDSTypography.titleSmall,
      bodyLarge: VSPDSTypography.bodyLarge,
      bodyMedium: VSPDSTypography.bodyMedium,
      bodySmall: VSPDSTypography.bodySmall,
      labelLarge: VSPDSTypography.labelLarge,
      labelMedium: VSPDSTypography.labelMedium,
      labelSmall: VSPDSTypography.labelSmall,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: VSPDSSemanticColors.background,
      colorScheme: const ColorScheme.dark(
        primary: VSPDSSemanticColors.accent,
        secondary: VSPDSSemanticColors.accent,
        surface: VSPDSSemanticColors.surface,
      ),
      fontFamily: VSPDSTypography.latinFont,
      fontFamilyFallback: VSPDSTypography.fallback,
      textTheme: textTheme,

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VSPDSSemanticColors.surface,
        surfaceTintColor: VSPDSColors.transparent,
        modalBackgroundColor: VSPDSSemanticColors.surface,
        elevation: VSPDSElevation.modal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VSPDSRadius.bottomSheet),
          ),
        ),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: VSPDSSemanticColors.surface,
        surfaceTintColor: VSPDSColors.transparent,
        elevation: VSPDSElevation.modal,
        titleTextStyle: VSPDSTypography.modalTitle,
        contentTextStyle: VSPDSTypography.modalBody,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(VSPDSRadius.dialog),
          ),
        ),
      ),

      datePickerTheme: const DatePickerThemeData(
        backgroundColor: VSPDSSemanticColors.surface,
        surfaceTintColor: VSPDSColors.transparent,
        headerBackgroundColor: VSPDSSemanticColors.surface,
        headerForegroundColor: VSPDSSemanticColors.accent,
        headerHelpStyle: VSPDSTypography.actionLabel,
        headerHeadlineStyle: VSPDSTypography.calendarHeadline,
        dayStyle: VSPDSTypography.calendarDay,
        weekdayStyle: VSPDSTypography.calendarWeekday,
        yearStyle: VSPDSTypography.calendarDay,
        cancelButtonStyle: ButtonStyle(
          textStyle: WidgetStatePropertyAll(VSPDSTypography.actionLabel),
          foregroundColor: WidgetStatePropertyAll(VSPDSSemanticColors.accent),
        ),
        confirmButtonStyle: ButtonStyle(
          textStyle: WidgetStatePropertyAll(VSPDSTypography.actionLabel),
          foregroundColor: WidgetStatePropertyAll(VSPDSSemanticColors.accent),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: VSPDSSemanticColors.background,
        elevation: VSPDSElevation.none,
        scrolledUnderElevation: VSPDSElevation.none,
        iconTheme: IconThemeData(color: VSPDSSemanticColors.textPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: VSPDSColors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: VSPDSSemanticColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontFamily: VSPDSTypography.latinFont,
          fontFamilyFallback: VSPDSTypography.fallback,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          height: 1.20,
          color: VSPDSSemanticColors.textPrimary,
        ),
      ),

      cardTheme: const CardThemeData(
        color: VSPDSSemanticColors.surface,
        elevation: VSPDSElevation.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(VSPDSRadius.card),
          ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: VSPDSSemanticColors.border,
        thickness: VSPDSBorders.standard,
        space: VSPDSSpacing.sm,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: VSPDSSemanticColors.surface,
        contentTextStyle: VSPDSTypography.bodyMedium,
        behavior: SnackBarBehavior.floating,
        elevation: VSPDSElevation.snackbar,
      ),

      chipTheme: const ChipThemeData(
        backgroundColor: VSPDSSemanticColors.surfaceRaised,
        selectedColor: VSPDSSemanticColors.accentSoft,
        disabledColor: VSPDSSemanticColors.surfaceRaised,
        secondarySelectedColor: VSPDSSemanticColors.accentSoft,
        padding: EdgeInsets.symmetric(
          horizontal: VSPDSSpacing.xs,
          vertical: VSPDSSpacing.xxs,
        ),
        side: VSPDSBorders.divider,
        shape: StadiumBorder(),
        labelStyle: VSPDSTypography.compactLabel,
      ),

      popupMenuTheme: const PopupMenuThemeData(
        color: VSPDSSemanticColors.surface,
        surfaceTintColor: VSPDSColors.transparent,
        elevation: VSPDSElevation.modal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(VSPDSRadius.dialog),
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VSPDSSemanticColors.accent,
        linearTrackColor: VSPDSSemanticColors.surfaceRaised,
        circularTrackColor: VSPDSSemanticColors.surfaceRaised,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: VSPDSSpacing.sm,
          vertical: VSPDSSpacing.xxs,
        ),
        minLeadingWidth: VSPDSizes.iconXl,
        iconColor: VSPDSSemanticColors.textSecondary,
        textColor: VSPDSSemanticColors.textPrimary,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: VSPDSSemanticColors.accent,
        unselectedLabelColor: VSPDSSemanticColors.textSecondary,
        indicatorColor: VSPDSSemanticColors.accent,
        dividerColor: VSPDSColors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VSPDSSemanticColors.accent,
          minimumSize: Size(
            VSPDSElevation.none,
            VSPDSizes.textButtonMinHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: VSPDSSpacing.sm,
          ),
          textStyle: VSPDSTypography.actionLabel,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VSPDSSemanticColors.accent,
          side: VSPDSBorders.accent,
          minimumSize: const Size(
            VSPDSElevation.none,
            VSPDSizes.buttonHeight,
          ),
          shape: const StadiumBorder(),
          textStyle: VSPDSTypography.compactButton,
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: VSPDSSemanticColors.surface,
        elevation: VSPDSElevation.none,
        indicatorColor: VSPDSSemanticColors.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          VSPDSTypography.status,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VSPDSSemanticColors.accent,
          foregroundColor: VSPDSColors.black,
          elevation: VSPDSElevation.none,
          shape: const StadiumBorder(),
          textStyle: VSPDSTypography.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VSPDSSemanticColors.inputFill,
        hintStyle: VSPDSTypography.bodyMedium.copyWith(
          color: VSPDSSemanticColors.textSecondary.withValues(
            alpha: VSPDSOpacity.secondaryText,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VSPDSSpacing.inputHorizontal,
          vertical: VSPDSSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPDSRadius.input),
          borderSide: VSPDSBorders.subtle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPDSRadius.input),
          borderSide: VSPDSBorders.subtle,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VSPDSRadius.input),
          borderSide: BorderSide(
            color: VSPDSSemanticColors.accent,
            width: VSPDSBorders.fieldFocus,
          ),
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

/// Custom transition builder retained from the existing VSP experience.
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
        curve: VSPDSMotion.standardCurve,
      ),
      child: child,
    );
  }
}
