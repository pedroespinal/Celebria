import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Solid, colored action button — the main "do a thing" button style used
/// throughout the app (save, export, test-push, etc).
class SolidButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool expand;

  const SolidButton(this.label, this.color,
      {super.key, required this.onPressed, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Toggle-style option button (pill, filled when active) — used for
/// notif-days chips, relation picker, theme/lang toggles, etc.
class OptionButton extends StatelessWidget {
  final String label;
  final bool active;
  final Palette palette;
  final VoidCallback onTap;
  final bool expand;
  final EdgeInsets margin;

  const OptionButton({
    super.key,
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
    this.expand = true,
    this.margin = EdgeInsets.zero,
  });

  // NOTE: when expand is true this widget's build() returns an Expanded, so
  // it must be used directly as a Row/Column child -- never wrapped in a
  // Padding (Expanded requires a Flex as its immediate parent, or Flutter
  // throws "Incorrect use of ParentDataWidget"). Use the `margin` param
  // instead of an external Padding to add spacing between chips.
  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? palette.cyandim : palette.bg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? palette.cyan : palette.border),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: active ? palette.cyan : palette.t3,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
    return expand ? Expanded(child: child) : child;
  }
}

/// Rounded filter chip (search filters, relation filter on Home).
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool active;
  final Palette palette;
  final VoidCallback onTap;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? palette.cyandim : palette.bg3,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? palette.cyan : palette.t3,
          ),
        ),
      ),
    );
  }
}
