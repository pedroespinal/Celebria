import 'package:flutter/material.dart';

import '../core/palette.dart';

class SectionHeader extends StatelessWidget {
  final String text;
  final Palette palette;
  const SectionHeader(this.text, {super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: palette.cyan, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class AppFooter extends StatelessWidget {
  final String text;
  final Palette palette;
  const AppFooter(this.text, {super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: palette.violet),
      ),
    );
  }
}
