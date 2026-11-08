import 'package:flutter/material.dart';

const paper = Color(0xFFF7F1E5);
const skyBlue = Color(0xFFCFE0E8);
const skyMist = Color(0xFFEAF0EA);
const sageLight = Color(0xFFC9D9B5);
const sage = Color(0xFF9DB58A);
const sageDeep = Color(0xFF6F8F6A);
const dustyPink = Color(0xFFE3B5B5);
const honey = Color(0xFFE8C46A);
const inkBrown = Color(0xFF4E4036);

const _serif = 'Newsreader';
const _serifFallback = ['serif'];

/// Light only; a placeholder palette until the real artwork lands.
ThemeData gardenTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: sage,
    brightness: Brightness.light,
    surface: paper,
  ).copyWith(primary: sageDeep, secondary: dustyPink, tertiary: honey);
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    useMaterial3: true,
  );
  TextStyle? serif(TextStyle? s) =>
      s?.copyWith(fontFamily: _serif, fontFamilyFallback: _serifFallback);
  final t = base.textTheme.apply(bodyColor: inkBrown, displayColor: inkBrown);
  return base.copyWith(
    textTheme: t.copyWith(
      headlineSmall: serif(t.headlineSmall),
      titleLarge: serif(t.titleLarge),
      titleMedium: serif(t.titleMedium),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sageDeep,
        foregroundColor: paper,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: inkBrown,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
