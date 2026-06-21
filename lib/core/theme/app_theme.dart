import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ScanGo Design System — Patient App Theme (LIGHT)
/// Warm, clean, medical trust. Like a private clinic.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Cairo',

      // ─── Color Scheme ─────────────────────────────────────
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDeep,
        secondary: AppColors.primaryDark,
        onSecondary: AppColors.textOnPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),

      // ─── Scaffold ─────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.background,

      // ─── AppBar ───────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppColors.primary,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),

      // ─── Bottom Navigation ────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ─── Elevated Button (Primary CTA) ────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.border),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Text Button (Ghost) ──────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ─── Input Fields ─────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        prefixIconColor: AppColors.textMuted,
      ),

      // ─── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // ─── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),

      // ─── SnackBar ─────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDeep,
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          color: AppColors.textOnPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Dialog ───────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          color: AppColors.textSecondary,
          height: 1.8,
        ),
      ),

      // ─── Text Theme ──────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
        headlineLarge: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
        headlineMedium: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
        headlineSmall: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
        bodyLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.8),
        bodyMedium: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.8),
        bodySmall: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.6),
        labelLarge: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        labelSmall: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted, height: 1.4),
      ),
    );
  }
}
