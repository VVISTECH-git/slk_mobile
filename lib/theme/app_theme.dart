import 'package:flutter/material.dart';

/// Sree Lakshmi Kalamkari brand palette — warm terracotta on cream, matching the
/// web portal. One place to tune the whole app's look.
class AppColors {
  static const terracotta = Color(0xFFB5533B); // primary
  static const terracottaDark = Color(0xFF8F3F2C);
  static const cream = Color(0xFFFBF6EF); // page background
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2A211C); // primary text
  static const inkSoft = Color(0xFF6B5D53); // secondary text
  static const border = Color(0xFFE7DDD0);
  static const gold = Color(0xFFC9A24B);
  static const success = Color(0xFF2E7D57);
  static const danger = Color(0xFFB3261E);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.terracotta,
      primary: AppColors.terracotta,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        // Labels always sit above the field (never resting inside it, which
        // reads like a value). Applies app-wide.
        floatingLabelBehavior: FloatingLabelBehavior.always,
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
          borderSide: const BorderSide(color: AppColors.terracotta, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textTheme: base.textTheme
          .copyWith(
            titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            bodyLarge: const TextStyle(fontSize: 15, height: 1.35),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.35),
            bodySmall: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.3),
            labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          )
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      dividerColor: AppColors.border,
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Spacing tokens — use instead of scattering magic numbers.
class Gaps {
  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h24 = SizedBox(height: 24);
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
}

/// Corner-radius tokens.
class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}

