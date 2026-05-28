// lib/utils/theme/app_colors.dart
// Autor: Abraham Yance
// Fecha: 2025-11-07
// Tema visual extendido con soporte para Despacho Full y pantallas de transacción

import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface;
  final Color surfaceBorder;
  final Color textPrimary;
  final Color textSecondary;

  // Nuevos campos
  final Color text;
  final Color textMuted;
  final Color textInverse;

  final Color iconActive;
  final Color iconInactive;
  final Color accent;
  final Color fallbackSurfaceOverlay;

  final Color headerBg;
  final Color headerTitle;
  final Color headerSubtitle;
  final Color headerDateTime;
  final Color headerCountdown;

  final Color buttonBg;
  final Color buttonFg;

  final Color iconColor;

  // 🟦 Nuevos campos para uniformidad visual
  final Color border;
  final Color panelTitleBlue; // Azul institucional TPG
  final Color panelBg; // Fondo neutro de panel
  final Color fieldBg;

  final Color azulCorporativo;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.text,
    required this.textMuted,
    required this.textInverse,
    required this.iconActive,
    required this.iconInactive,
    required this.accent,
    required this.fallbackSurfaceOverlay,
    required this.headerBg,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.headerDateTime,
    required this.headerCountdown,
    required this.buttonBg,
    required this.buttonFg,
    required this.iconColor,
    required this.border,
    required this.panelTitleBlue,
    required this.panelBg,
    required this.fieldBg,

    required this.azulCorporativo,
  });

  // ─────────────────────────────
  // ☀️ LIGHT THEME
  // ─────────────────────────────
  static const light = AppPalette(
    bg: Color(0xFFF7F7F7),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFE6E6E6),

    textPrimary: Color(0xFF1C1C1C),
    textSecondary: Color(0xFF6F6F6F),

    text: Color(0xFF1C1C1C),
    textMuted: Color(0xFF6F6F6F),
    textInverse: Color(0xFFFFFFFF),

    iconActive: Color(0xFFF63B3B),
    iconInactive: Color(0xFF9E9E9E),
    accent: Color(0xFFF63B3B),
    fallbackSurfaceOverlay: Color(0xFFF3F3F3),

    headerBg: Color(0xFFF2F3F5),
    headerTitle: Color(0xFF1C1C1C),
    headerSubtitle: Color(0xFF6F6F6F),
    headerDateTime: Color(0xFF3A3A3A),
    headerCountdown: Color(0xFFE90E0E),

    buttonBg: Color(0xFFF63B3B),
    buttonFg: Color(0xFFFFFFFF),

    iconColor: Color(0xFFF63B3B),

    // Nuevos
    border: Color(0xFFBDBDBD),
    panelTitleBlue: Color(0xFF1976D2), // Azul institucional TPG
    panelBg: Color(0xFFFFFFFF),
    fieldBg: Color(0xFFF8F9FA),

    azulCorporativo: Color(0xFF0056B3),
  );

  // ─────────────────────────────
  // 🌙 DARK THEME
  // ─────────────────────────────
  static const dark = AppPalette(
    bg: Color(0xFF0A0B0E),
    surface: Color(0xFF11131A),
    surfaceBorder: Color(0xFF232536),

    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFB8C1CC),

    text: Color(0xFFF5F7FA),
    textMuted: Color(0xFFB8C1CC),
    textInverse: Color(0xFF0A0B0E),

    iconActive: Color(0xFFFF5C5C),
    iconInactive: Color(0xFF80889C),
    accent: Color(0xFFFF4C4C),
    fallbackSurfaceOverlay: Color(0xFF1C1E27),

    headerBg: Color(0x00000000),
    headerTitle: Color(0xFFFFFFFF),
    headerSubtitle: Color(0xFF9FA6B2),
    headerDateTime: Color(0xFFE9F0FF),
    headerCountdown: Color(0xFFFF7C7C),

    buttonBg: Color(0xFFFF0000),
    buttonFg: Color(0xFFFFFFFF),

    iconColor: Color(0xFFFFFFFF),

    // Nuevos
    border: Color(0xFF3C3C3C),
    panelTitleBlue: Color(0xFF42A5F5),
    panelBg: Color(0xFF1B1E24),
    fieldBg: Color(0xFF1E2128),

    azulCorporativo: Color(0xFF42A5F5),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? text,
    Color? textMuted,
    Color? textInverse,
    Color? iconActive,
    Color? iconInactive,
    Color? accent,
    Color? fallbackSurfaceOverlay,
    Color? headerBg,
    Color? headerTitle,
    Color? headerSubtitle,
    Color? headerDateTime,
    Color? headerCountdown,
    Color? buttonBg,
    Color? buttonFg,
    Color? iconColor,
    Color? border,
    Color? panelTitleBlue,
    Color? panelBg,
    Color? fieldBg,
    Color? azulCorporativo,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      iconActive: iconActive ?? this.iconActive,
      iconInactive: iconInactive ?? this.iconInactive,
      accent: accent ?? this.accent,
      fallbackSurfaceOverlay:
          fallbackSurfaceOverlay ?? this.fallbackSurfaceOverlay,
      headerBg: headerBg ?? this.headerBg,
      headerTitle: headerTitle ?? this.headerTitle,
      headerSubtitle: headerSubtitle ?? this.headerSubtitle,
      headerDateTime: headerDateTime ?? this.headerDateTime,
      headerCountdown: headerCountdown ?? this.headerCountdown,
      buttonBg: buttonBg ?? this.buttonBg,
      buttonFg: buttonFg ?? this.buttonFg,
      iconColor: iconColor ?? this.iconColor,
      border: border ?? this.border,
      panelTitleBlue: panelTitleBlue ?? this.panelTitleBlue,
      panelBg: panelBg ?? this.panelBg,
      fieldBg: fieldBg ?? this.fieldBg,
      azulCorporativo: azulCorporativo ?? this.azulCorporativo,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color _lerp(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bg: _lerp(bg, other.bg),
      surface: _lerp(surface, other.surface),
      surfaceBorder: _lerp(surfaceBorder, other.surfaceBorder),
      textPrimary: _lerp(textPrimary, other.textPrimary),
      textSecondary: _lerp(textSecondary, other.textSecondary),
      text: _lerp(text, other.text),
      textMuted: _lerp(textMuted, other.textMuted),
      textInverse: _lerp(textInverse, other.textInverse),
      iconActive: _lerp(iconActive, other.iconActive),
      iconInactive: _lerp(iconInactive, other.iconInactive),
      accent: _lerp(accent, other.accent),
      fallbackSurfaceOverlay: _lerp(
        fallbackSurfaceOverlay,
        other.fallbackSurfaceOverlay,
      ),
      headerBg: _lerp(headerBg, other.headerBg),
      headerTitle: _lerp(headerTitle, other.headerTitle),
      headerSubtitle: _lerp(headerSubtitle, other.headerSubtitle),
      headerDateTime: _lerp(headerDateTime, other.headerDateTime),
      headerCountdown: _lerp(headerCountdown, other.headerCountdown),
      buttonBg: _lerp(buttonBg, other.buttonBg),
      buttonFg: _lerp(buttonFg, other.buttonFg),
      iconColor: _lerp(iconColor, other.iconColor),
      border: _lerp(border, other.border),
      panelTitleBlue: _lerp(panelTitleBlue, other.panelTitleBlue),
      panelBg: _lerp(panelBg, other.panelBg),
      fieldBg: _lerp(fieldBg, other.fieldBg), 
      azulCorporativo: _lerp(azulCorporativo, other.azulCorporativo), 
    );
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppPalette.light.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.light.accent,
        brightness: Brightness.light,
        background: AppPalette.light.bg,
        primary: AppPalette.light.buttonBg,
        onPrimary: AppPalette.light.buttonFg,
        surface: AppPalette.light.surface,
        onSurface: AppPalette.light.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      extensions: const [AppPalette.light],
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppPalette.dark.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppPalette.dark.accent,
        brightness: Brightness.dark,
        background: AppPalette.dark.bg,
        primary: AppPalette.dark.buttonBg,
        onPrimary: AppPalette.dark.buttonFg,
        surface: AppPalette.dark.surface,
        onSurface: AppPalette.dark.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      extensions: const [AppPalette.dark],
      useMaterial3: true,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
