import 'package:flutter/material.dart';

/// Fiesta color palette — ported byte-for-byte from main.py's _DARK/_LIGHT dicts.
/// Kept exactly as-is per product decision (only the app ICON gets redesigned,
/// not the in-app palette).
class Palette {
  final Color bg, bg2, bg3, card, border;
  final Color cyan, cyandim;
  final Color purple, purpledim, violet;
  final Color pink, pinkdim;
  final Color green, greendim;
  final Color yellow, red;
  final Color t1, t2, t3;

  const Palette({
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
}

Color _c(String hex) => Color(int.parse('FF${hex.substring(1)}', radix: 16));

const _darkRaw = {
  'bg': '#061418', 'bg2': '#0a1e22', 'bg3': '#0e262c',
  'card': '#081a1e', 'border': '#143440',
  'cyan': '#ff6b6b', 'cyandim': '#4a0a0a',
  'purple': '#ffd93d', 'purpledim': '#3a2800', 'violet': '#ffa040',
  'pink': '#ff4e88', 'pinkdim': '#4a0a20',
  'green': '#6bcb77', 'greendim': '#083a10',
  'yellow': '#ffd93d', 'red': '#ff4444',
  't1': '#ffe8d0', 't2': '#ffc080', 't3': '#9a7888',
};

const _lightRaw = {
  'bg': '#fff8f0', 'bg2': '#ffe8d0', 'bg3': '#ffd8b8',
  'card': '#fff2e0', 'border': '#e8a868',
  'cyan': '#c0382b', 'cyandim': '#ffded8',
  'purple': '#9a6800', 'purpledim': '#fff0c0', 'violet': '#8a4a00',
  'pink': '#b00040', 'pinkdim': '#ffd0e0',
  'green': '#1a7830', 'greendim': '#c0f0c8',
  'yellow': '#7a5000', 'red': '#aa0000',
  't1': '#1a0808', 't2': '#5a2a00', 't3': '#7a5a4a',
};

Palette _buildPalette(Map<String, String> raw) => Palette(
      bg: _c(raw['bg']!), bg2: _c(raw['bg2']!), bg3: _c(raw['bg3']!),
      card: _c(raw['card']!), border: _c(raw['border']!),
      cyan: _c(raw['cyan']!), cyandim: _c(raw['cyandim']!),
      purple: _c(raw['purple']!), purpledim: _c(raw['purpledim']!), violet: _c(raw['violet']!),
      pink: _c(raw['pink']!), pinkdim: _c(raw['pinkdim']!),
      green: _c(raw['green']!), greendim: _c(raw['greendim']!),
      yellow: _c(raw['yellow']!), red: _c(raw['red']!),
      t1: _c(raw['t1']!), t2: _c(raw['t2']!), t3: _c(raw['t3']!),
    );

final Palette darkPalette = _buildPalette(_darkRaw);
final Palette lightPalette = _buildPalette(_lightRaw);

ThemeData buildThemeData(Palette p, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.cyan,
      onPrimary: p.t1,
      secondary: p.pink,
      onSecondary: p.t1,
      error: p.red,
      onError: p.t1,
      surface: p.card,
      onSurface: p.t1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.cyan,
      elevation: 0,
    ),
    dividerColor: p.border,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: p.t1,
          displayColor: p.t1,
        ),
  );
}
