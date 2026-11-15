import 'package:flutter/material.dart';

// Flower palette: used by the flower painter, in both light and dark themes.
const paper = Color(0xFFF7F1E5);
const skyBlue = Color(0xFFCFE0E8);
const sageLight = Color(0xFFC9D9B5);
const sage = Color(0xFF9DB58A);
const sageDeep = Color(0xFF6F8F6A);
const dustyPink = Color(0xFFE3B5B5);
const honey = Color(0xFFE8C46A);
const lavender = Color(0xFFB7A6D6);
const inkBrown = Color(0xFF4E4036);

/// Accent for a habit's charts and heatmap, taken from its flower. One shade
/// per theme brightness so the dots stay readable on both backgrounds.
Color flowerColor(String kind, Brightness b) {
  final dark = b == Brightness.dark;
  return switch (kind) {
    'tulip' => dark ? const Color(0xFFF08FA8) : const Color(0xFFD9577A),
    'sunflower' => dark ? const Color(0xFFF2C14E) : const Color(0xFFD99A0B),
    'lavender' => dark ? const Color(0xFFB9A7E8) : const Color(0xFF7B63C2),
    _ => dark ? const Color(0xFF5CCB98) : const Color(0xFF2E9E6C),
  };
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
