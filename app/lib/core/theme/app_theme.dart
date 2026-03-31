import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Apple-style light theme — clean, minimal, professional.
class AppTheme {
  AppTheme._();

  // Core colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
  static const Color primary = Color(0xFF007AFF);
  static const Color textPrimary = Color(0xFF1D1D1F);
  static const Color textSecondary = Color(0xFF86868B);
  static const Color upGreen = Color(0xFF34C759);
  static const Color downRed = Color(0xFFFF3B30);
  static const Color flatGray = Color(0xFF8E8E93);
  static const Color divider = Color(0xFFE5E5EA);

  // Legacy aliases (so existing code compiles without changes)
  static const Color accent = primary;
  static const Color cardBorder = divider;

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: primary,
          surface: surface,
          error: downRed,
        ),
        cardTheme: CardThemeData(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: background,
          selectedItemColor: primary,
          unselectedItemColor: flatGray,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerColor: divider,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
        ),
      );

  // Keep darkTheme getter so app.dart compiles during transition
  static ThemeData get darkTheme => lightTheme;
}
