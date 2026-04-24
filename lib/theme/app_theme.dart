import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';

// ── Theme mode provider ──
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class AppTheme {
  AppTheme._();

  // ── DARK THEME ──
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.income,
          error: AppColors.expense,
          surface: AppColors.darkSurface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onError: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkCard,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withAlpha(13),
          thickness: 1,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          bodySmall: TextStyle(color: AppColors.textSecondary),
          labelLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
          labelMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );

  // ── LIGHT THEME ──
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.income,
          error: AppColors.expense,
          surface: AppColors.lightSurface,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onError: Colors.white,
          onSurface: AppColors.lightTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
        ),
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.black.withAlpha(13),
          thickness: 1,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.lightTextPrimary,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.lightTextPrimary,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
          bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
          bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
          bodySmall: TextStyle(color: AppColors.lightTextSecondary),
          labelLarge: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextSecondary,
            letterSpacing: 1.2,
          ),
          labelMedium: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextSecondary,
            letterSpacing: 1.0,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );
}
