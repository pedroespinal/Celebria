import 'package:flutter/material.dart';

/// Celebria color system — v1.10.0.
///
/// Three palette families, each with a neon DARK mode and a soft LIGHT mode:
///   • aurora (default) — soft cyan + lilac on navy / cool paper
///   • tropical           — mint + magenta on deep teal / soft mint paper
///   • cyber              — Pedro's signature cyan/pink/purple on #07071A
///   • fiesta             — electric pink on plum / warm sand paper
///
/// Field names are historical (kept so every screen keeps compiling) and
/// are ROLES, not literal hues:
///   cyan   = primary accent (titles, active chips, main buttons)
///   purple = secondary accent (edit, "work" relation)
///   violet = tertiary accent (calendar nav/weekdays, stats, footer)
///   pink   = "today" / celebration
///   green / yellow / red = success / this-week & milestones / danger
///   *dim   = tinted background behind the matching accent
///   t1/t2/t3 = text: primary / warm accent (labels) / muted
class Palette {
  final String family;
  final bool isDark;
  final Color bg, bg2, bg3, card, border;
  final Color cyan, cyandim;
  final Color purple, purpledim, violet;
  final Color pink, pinkdim;
  final Color green, greendim;
  final Color yellow, red;
  final Color t1, t2, t3;

  const Palette({
    required this.family,
    required this.isDark,
    required this.bg, required this.bg2, required this.bg3,
    required this.card, required this.border,
    required this.cyan, required this.cyandim,
    required this.purple, required this.purpledim, required this.violet,
    required this.pink, required this.pinkdim,
    required this.green, required this.greendim,
    required this.yellow, required this.red,
    required this.t1, required this.t2, required this.t3,
  });

  Color byKey(String key) => switch (key) {
        'cyan' => cyan,
        'purple' => purple,
        'green' => green,
        'yellow' => yellow,
        'pink' => pink,
        'violet' => violet,
        'red' => red,
        _ => t1,
      };

  /// Neon glow for highlighted elements (today's card, main buttons).
  /// Only in dark mode — in light mode a glow just looks blurry.
  List<BoxShadow> glow(Color c, {double strength = 1}) => isDark
      ? [
          BoxShadow(color: c.withValues(alpha: 0.55 * strength), blurRadius: 14 * strength, spreadRadius: 0.5),
          BoxShadow(color: c.withValues(alpha: 0.25 * strength), blurRadius: 28 * strength),
        ]
      : const [];
}

/// Readable text color to put ON a filled background: whichever of near-black
/// or white has the higher WCAG contrast (neon fills → dark text, deep
/// light-mode accents → white). Covered by test/features_test.dart.
Color onColor(Color fill) {
  const dark = Color(0xFF0A0F14);
  final l = fill.computeLuminance();
  final withWhite = 1.05 / (l + 0.05);
  final withDark = (l + 0.05) / (dark.computeLuminance() + 0.05);
  return withDark >= withWhite ? dark : Colors.white;
}

Color _c(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

Palette _build(String family, bool dark, Map<String, String> r) => Palette(
      family: family,
      isDark: dark,
      bg: _c(r['bg']!), bg2: _c(r['bg2']!), bg3: _c(r['bg3']!),
      card: _c(r['card']!), border: _c(r['border']!),
      cyan: _c(r['cyan']!), cyandim: _c(r['cyandim']!),
      purple: _c(r['purple']!), purpledim: _c(r['purpledim']!), violet: _c(r['violet']!),
      pink: _c(r['pink']!), pinkdim: _c(r['pinkdim']!),
      green: _c(r['green']!), greendim: _c(r['greendim']!),
      yellow: _c(r['yellow']!), red: _c(r['red']!),
      t1: _c(r['t1']!), t2: _c(r['t2']!), t3: _c(r['t3']!),
    );

const _raw = <String, Map<String, Map<String, String>>>{
  // v1.10.4 (chosen by Pedro): softer neon for legibility — slightly lighter,
  // less saturated accents on raised navy surfaces; lilac field labels.
  'aurora': {
    'dark': {
      'bg': '#0E1222', 'bg2': '#121730', 'bg3': '#1E2542', 'card': '#161B31', 'border': '#36406A',
      'cyan': '#7DF3FF', 'cyandim': '#173A48',
      'purple': '#C8B3FF', 'purpledim': '#2C2550', 'violet': '#B69CFF',
      'pink': '#FF8FD6', 'pinkdim': '#4A1F45',
      'green': '#7DFFB2', 'greendim': '#173D2C',
      'yellow': '#FFE27A', 'red': '#FF7A8F',
      't1': '#F4F6FF', 't2': '#C9B8FF', 't3': '#AAB2D4',
    },
    'light': {
      'bg': '#F4F6FC', 'bg2': '#EAEEF8', 'bg3': '#E6EBF7', 'card': '#FFFFFF', 'border': '#D5DCEE',
      'cyan': '#0E6F86', 'cyandim': '#D6F0F6',
      'purple': '#5B45D6', 'purpledim': '#E6E1FB', 'violet': '#6D4FD8',
      'pink': '#B4237F', 'pinkdim': '#F8DDEE',
      'green': '#127A4B', 'greendim': '#D8F0E3',
      'yellow': '#8A5300', 'red': '#C81E3A',
      't1': '#1A1F36', 't2': '#5B3FC4', 't3': '#5F6788',
    },
  },
  'tropical': {
    'dark': {
      'bg': '#03121A', 'bg2': '#061A24', 'bg3': '#0A2330', 'card': '#071B25', 'border': '#124050',
      'cyan': '#00FFC6', 'cyandim': '#00382E',
      'purple': '#9D7BFF', 'purpledim': '#241A4A', 'violet': '#C38BFF',
      'pink': '#FF4FD8', 'pinkdim': '#45103D',
      'green': '#7CFF4F', 'greendim': '#173D10',
      'yellow': '#FFE45E', 'red': '#FF4D6D',
      't1': '#E6FFF8', 't2': '#FF9E5E', 't3': '#7FA3AE',
    },
    'light': {
      'bg': '#F1F8F6', 'bg2': '#E6F2EE', 'bg3': '#E3F0EC', 'card': '#FFFFFF', 'border': '#CFE5DE',
      'cyan': '#0B7A6B', 'cyandim': '#D2F1EA',
      'purple': '#4F46E5', 'purpledim': '#E3E1FB', 'violet': '#6D5BD0',
      'pink': '#C026D3', 'pinkdim': '#F7DDF9',
      'green': '#4D7C0F', 'greendim': '#E2F0CF',
      'yellow': '#8A5300', 'red': '#C81E3A',
      't1': '#12302B', 't2': '#C2410C', 't3': '#5E7D76',
    },
  },
  'cyber': {
    'dark': {
      'bg': '#07071A', 'bg2': '#0B0B22', 'bg3': '#141433', 'card': '#0D0D26', 'border': '#25255A',
      'cyan': '#00E5FF', 'cyandim': '#003A45',
      'purple': '#A855F7', 'purpledim': '#2A1650', 'violet': '#9B6BFF',
      'pink': '#F72585', 'pinkdim': '#4A0B2A',
      'green': '#39FF88', 'greendim': '#0B3A20',
      'yellow': '#FFE600', 'red': '#FF3B5C',
      't1': '#EAF6FF', 't2': '#FF9A3C', 't3': '#8A8FB8',
    },
    'light': {
      'bg': '#F5F4FB', 'bg2': '#ECEAF7', 'bg3': '#E9E6F6', 'card': '#FFFFFF', 'border': '#DDD8F0',
      'cyan': '#0E7490', 'cyandim': '#D5F1F8',
      'purple': '#7C3AED', 'purpledim': '#EDE4FD', 'violet': '#6D28D9',
      'pink': '#DB2777', 'pinkdim': '#FBE0EE',
      'green': '#059669', 'greendim': '#D7F3E8',
      'yellow': '#92400E', 'red': '#DC2626',
      't1': '#1E1B33', 't2': '#C2410C', 't3': '#6E6A88',
    },
  },
  'fiesta': {
    'dark': {
      'bg': '#0C0614', 'bg2': '#12091C', 'bg3': '#1C1029', 'card': '#140A20', 'border': '#3A1F4F',
      'cyan': '#FF2E97', 'cyandim': '#4A0D2E',
      'purple': '#C04BFF', 'purpledim': '#34124A', 'violet': '#00F0FF',
      'pink': '#FF7AD9', 'pinkdim': '#4A1240',
      'green': '#00FF9C', 'greendim': '#063D27',
      'yellow': '#FFD300', 'red': '#FF4D4D',
      't1': '#FFF0FA', 't2': '#FFB86B', 't3': '#A08AB0',
    },
    'light': {
      'bg': '#FBF7F3', 'bg2': '#F5ECE4', 'bg3': '#F3EAE2', 'card': '#FFFDFA', 'border': '#EBDDD0',
      'cyan': '#D61F69', 'cyandim': '#FBDDE8',
      'purple': '#7E22CE', 'purpledim': '#EEDDFB', 'violet': '#9333EA',
      'pink': '#BE185D', 'pinkdim': '#FCE0EC',
      'green': '#15803D', 'greendim': '#DCF2E2',
      'yellow': '#8A5300', 'red': '#B91C1C',
      't1': '#2B1D22', 't2': '#B45309', 't3': '#7A6A66',
    },
  },
};

const List<String> paletteFamilies = ['aurora', 'tropical', 'cyber', 'fiesta'];
const String defaultPaletteFamily = 'aurora';

final Map<String, Palette> _cache = {
  for (final f in paletteFamilies)
    for (final m in ['dark', 'light']) '$f/$m': _build(f, m == 'dark', _raw[f]![m]!),
};

Palette paletteFor(String family, String theme) {
  final f = paletteFamilies.contains(family) ? family : defaultPaletteFamily;
  return _cache['$f/${theme == 'light' ? 'light' : 'dark'}']!;
}

ThemeData buildThemeData(Palette p) {
  final brightness = p.isDark ? Brightness.dark : Brightness.light;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.cyan,
      onPrimary: onColor(p.cyan),
      secondary: p.pink,
      onSecondary: onColor(p.pink),
      error: p.red,
      onError: onColor(p.red),
      surface: p.card,
      onSurface: p.t1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg2,
      foregroundColor: p.cyan,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.isDark ? p.bg3 : p.t1,
      contentTextStyle: TextStyle(color: p.isDark ? p.t1 : p.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: p.isDark ? BorderSide(color: p.cyan.withValues(alpha: 0.6)) : BorderSide.none),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
          color: s.contains(WidgetState.selected) ? p.cyan : p.t3)),
      iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.cyan : p.t3)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.bg2),
    dividerColor: p.border,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: p.t1,
          displayColor: p.t1,
        ),
  );
}
