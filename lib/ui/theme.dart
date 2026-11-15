import 'package:flutter/material.dart';

import '../flower/plants.dart';

/// Accent for a habit's charts and heatmap, taken from its flower. One shade
/// per theme brightness so the dots stay readable on both backgrounds.
Color flowerColor(String kind, Brightness b) {
  final p = plantOf(kind) ?? plantOf('daisy')!;
  return b == Brightness.dark ? p.dark : p.light;
}

const _serif = 'Newsreader';
const _serifFallback = ['serif'];

/// Clean mint-and-white cards in light, deep green in dark.
ThemeData gardenTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? const Color(0xFF0F1512) : const Color(0xFFF1F7F3);
  final card = dark ? const Color(0xFF19221D) : Colors.white;
  final ink = dark ? const Color(0xFFE6EFE9) : const Color(0xFF1E2B24);
  final primary = dark ? const Color(0xFF5CCB98) : const Color(0xFF2E9E6C);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2E9E6C),
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: dark ? const Color(0xFF06150D) : Colors.white,
        surface: bg,
        onSurface: ink,
        surfaceContainerLow: card,
        surfaceContainerLowest: card,
      );
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
  );
  TextStyle? serif(TextStyle? s) =>
      s?.copyWith(fontFamily: _serif, fontFamilyFallback: _serifFallback);
  final t = base.textTheme.apply(bodyColor: ink, displayColor: ink);
  return base.copyWith(
    textTheme: t.copyWith(
      headlineSmall: serif(t.headlineSmall),
      titleLarge: serif(t.titleLarge),
      titleMedium: serif(t.titleMedium),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
