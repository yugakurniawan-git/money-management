import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Core palette ──
  static const darkBg = Color(0xFF0A0E21);
  static const darkSurface = Color(0xFF1A1F36);
  static const darkCard = Color(0xFF242942);
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF9D4EDD);
  static const income = Color(0xFF00D9A6);
  static const incomeDark = Color(0xFF00B4D8);
  static const expense = Color(0xFFFF6B6B);
  static const expenseLight = Color(0xFFFF8E53);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF8E8EA0);
  static const warning = Color(0xFFFFD93D);

  // ── Light theme ──
  static const lightBg = Color(0xFFF8F9FE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF0F1F8);
  static const lightTextPrimary = Color(0xFF1A1F36);
  static const lightTextSecondary = Color(0xFF6B7280);

  // ── Gradients ──
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const incomeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [income, incomeDark],
  );

  static const expenseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [expense, expenseLight],
  );

  static const darkBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBg, darkSurface],
  );

  static const lightBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBg, lightSurface],
  );

  // ── Glass effect colors ──
  static Color glassColorDark = Colors.white.withAlpha(13); // 0.05
  static Color glassBorderDark = Colors.white.withAlpha(26); // 0.1
  static Color glassColorLight = Colors.white.withAlpha(179); // 0.7
  static Color glassBorderLight = Colors.black.withAlpha(13); // 0.05

  // ── Chart palette ──
  static const chartColors = [
    primary,
    income,
    expense,
    expenseLight,
    incomeDark,
    primaryLight,
    warning,
    Color(0xFF4ECDC4),
  ];
}
