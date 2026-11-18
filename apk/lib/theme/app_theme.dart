import 'package:flutter/material.dart';

/// Centralized Design System for Merkato Credit Record.
///
/// Designed with modern Material 3 guidelines and a premium, high-trust
/// business & financial aesthetic (fintech-grade).
class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1E5BB8);
  static const Color primaryBlueDark = Color(0xFF3B82F6);
  static const Color primaryBlueLight = Color(0xFFEFF6FF);

  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color emeraldGreenDark = Color(0xFF059669);
  static const Color emeraldGreenLight = Color(0xFFECFDF5);

  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color amberWarningLight = Color(0xFFFFFBEB);

  static const Color roseDanger = Color(0xFFE11D48);
  static const Color roseDangerDark = Color(0xFFBE123C);
  static const Color roseDangerLight = Color(0xFFFFF1F2);

  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color purpleAccentLight = Color(0xFFF5F3FF);

  // Neutral Light
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Neutral Dark
  static const Color darkScaffold = Color(0xFF0A0F1D);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceAlt = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF1F293D);
  static const Color darkBorderStrong = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Corner Radii
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  // Elevation Shadows
  static List<BoxShadow> softShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 10,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.40)
              : const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 14,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.20)
              : const Color(0xFF0F172A).withValues(alpha: 0.02),
          blurRadius: 3,
          spreadRadius: 0,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> elevatedShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.50)
              : const Color(0xFF1E5BB8).withValues(alpha: 0.12),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 6),
        ),
      ];

  // ThemeData Builder
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: primaryBlueLight,
        onPrimaryContainer: primaryBlue,
        secondary: emeraldGreen,
        onSecondary: Colors.white,
        error: roseDanger,
        onError: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        onSurfaceVariant: lightTextSecondary,
        outline: lightBorder,
        outlineVariant: lightBorderStrong,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: lightScaffold,
      dividerColor: lightBorder,
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lightBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: lightTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        elevation: 2,
        indicatorColor: primaryBlueLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryBlue, size: 22);
          }
          return const IconThemeData(color: lightTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primaryBlue,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: lightTextSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontSize: 13,
          color: lightTextTertiary,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: lightTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: roseDanger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: roseDanger, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: lightBorderStrong, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceAlt,
        side: const BorderSide(color: lightBorder, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: lightTextSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlueDark,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF1E3A8A),
        onPrimaryContainer: const Color(0xFFBFDBFE),
        secondary: emeraldGreen,
        onSecondary: Colors.white,
        error: roseDangerDark,
        onError: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
        outline: darkBorder,
        outlineVariant: darkBorderStrong,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkScaffold,
      dividerColor: darkBorder,
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: darkBorder, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: darkTextPrimary, size: 22),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        elevation: 2,
        indicatorColor: const Color(0xFF1E3A8A),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF93C5FD), size: 22);
          }
          return const IconThemeData(color: darkTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF93C5FD),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: darkTextSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontSize: 13,
          color: darkTextTertiary,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: darkTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryBlueDark, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: roseDangerDark, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: roseDangerDark, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlueDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF93C5FD),
          side: const BorderSide(color: darkBorderStrong, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF93C5FD),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceAlt,
        side: const BorderSide(color: darkBorder, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: darkTextSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
      ),
    );
  }
}
