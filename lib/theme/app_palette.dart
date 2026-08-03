import 'package:flutter/material.dart';

/// Semantic colour roles for one theme. Registered as a [ThemeExtension] so any
/// widget can read them via `context.p` and they recolour live when the theme
/// changes. Purpose-based names (not colour names) — same idea as the LEAP apps.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.surface1, // page / scaffold background
    required this.surface2, // cards, sheets, fields
    required this.surface3, // chips, hover, subtle fills
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.danger,
    required this.appBar,
    required this.onAppBar,
    required this.onPrimary,
  });

  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color danger;
  final Color appBar;
  final Color onAppBar;
  final Color onPrimary;

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? danger,
    Color? appBar,
    Color? onAppBar,
    Color? onPrimary,
  }) =>
      AppPalette(
        primary: primary ?? this.primary,
        primaryDark: primaryDark ?? this.primaryDark,
        accent: accent ?? this.accent,
        surface1: surface1 ?? this.surface1,
        surface2: surface2 ?? this.surface2,
        surface3: surface3 ?? this.surface3,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        border: border ?? this.border,
        success: success ?? this.success,
        danger: danger ?? this.danger,
        appBar: appBar ?? this.appBar,
        onAppBar: onAppBar ?? this.onAppBar,
        onPrimary: onPrimary ?? this.onPrimary,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      primary: c(primary, other.primary),
      primaryDark: c(primaryDark, other.primaryDark),
      accent: c(accent, other.accent),
      surface1: c(surface1, other.surface1),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      border: c(border, other.border),
      success: c(success, other.success),
      danger: c(danger, other.danger),
      appBar: c(appBar, other.appBar),
      onAppBar: c(onAppBar, other.onAppBar),
      onPrimary: c(onPrimary, other.onPrimary),
    );
  }
}

/// Read the active palette from any widget: `context.p.text`, `context.p.surface2`…
extension PaletteX on BuildContext {
  AppPalette get p => Theme.of(this).extension<AppPalette>()!;
}
