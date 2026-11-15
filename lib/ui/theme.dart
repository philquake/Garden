import 'package:flutter/material.dart';

import '../flower/plants.dart';

/// Accent for a habit's charts and heatmap, taken from its flower. One shade
/// per theme brightness so the dots stay readable on both backgrounds.
Color flowerColor(String kind, Brightness b) {
  final p = plantOf(kind) ?? plantOf('daisy')!;
  return b == Brightness.dark ? p.dark : p.light;
}

/// Ink to draw on top of [accent]: whichever of near-black or white contrasts
/// more. Mid-tone accents only reach ~4:1, so text on them is drawn large.
Color onAccent(Color accent) {
  final l = accent.computeLuminance();
  const darkInk = Color(0xFF1C2420);
  return (l + 0.05) / (darkInk.computeLuminance() + 0.05) > 1.05 / (l + 0.05)
      ? darkInk
      : Colors.white;
}

/// A whisper of the habit's colour over a card, so each habit keeps its hue
/// without shouting.
Color accentWash(Color accent, Brightness b) => Color.alphaBlend(
  accent.withValues(alpha: b == Brightness.dark ? 0.14 : 0.08),
  b == Brightness.dark ? _darkCard : Colors.white,
);

const _serif = 'Newsreader';
const _serifFallback = ['serif'];

const _darkCard = Color(0xFF1B211E);

/// Calm garden pastels: warm oat paper, white cards, deep sage actions, and
/// each habit's flower colour as a soft wash.
ThemeData gardenTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? const Color(0xFF121614) : const Color(0xFFF6F4EE);
  final card = dark ? _darkCard : Colors.white;
  final ink = dark ? const Color(0xFFE8EEEA) : const Color(0xFF26302B);
  final muted = dark ? const Color(0xFFAEBAB3) : const Color(0xFF5C6A62);
  // Deep sage in light (white text 5.4:1), soft mint in dark (dark text 9:1).
  final primary = dark ? const Color(0xFF8AD5B6) : const Color(0xFF2F7A64);
  final onPrimary = dark ? const Color(0xFF0B1A13) : Colors.white;
  final soft = dark ? const Color(0xFF243B31) : const Color(0xFFDCEFE5);
  final lilac = dark ? const Color(0xFF2E2A3D) : const Color(0xFFECE7F7);
  final line = dark ? const Color(0xFF2C3530) : const Color(0xFFE4E1D8);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F7A64),
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: soft,
        onPrimaryContainer: ink,
        secondaryContainer: soft,
        onSecondaryContainer: ink,
        tertiaryContainer: lilac,
        onTertiaryContainer: ink,
        surface: bg,
        onSurface: ink,
        onSurfaceVariant: muted,
        surfaceContainerLowest: card,
        surfaceContainerLow: card,
        surfaceContainer: card,
        surfaceContainerHigh: card,
        surfaceContainerHighest: line,
        outline: muted,
        outlineVariant: line,
      );
  final base = ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
  );
  TextStyle? serif(TextStyle? s) =>
      s?.copyWith(fontFamily: _serif, fontFamilyFallback: _serifFallback);
  final t = base.textTheme.apply(bodyColor: ink, displayColor: ink);
  final round16 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    textTheme: t.copyWith(
      headlineMedium: serif(t.headlineMedium),
      headlineSmall: serif(t.headlineSmall),
      titleLarge: serif(t.titleLarge),
      titleMedium: serif(t.titleMedium),
      bodySmall: t.bodySmall?.copyWith(color: muted),
      labelMedium: t.labelMedium?.copyWith(color: muted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    listTileTheme: ListTileThemeData(iconColor: primary),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(48, 44),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: card,
        selectedBackgroundColor: soft,
        selectedForegroundColor: ink,
        foregroundColor: ink,
        side: BorderSide(color: line),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: soft,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(color: ink, fontSize: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? onPrimary : muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : line,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : muted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: line,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: bg, fontSize: 14),
      shape: round16,
    ),
  );
}

/// A titled group on a screen: small heading above a card of content.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    this.color,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;
  final Widget? trailing;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}
