import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/palette.dart';

/// Circle with the contact's photo (or a colored initial) inside a ring in
/// the relation's color. When [celebrating] is true (it's their day) the
/// ring becomes a spinning neon gradient.
class ContactAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final String relation;
  final Palette palette;
  final double size;
  final bool celebrating;

  const ContactAvatar({
    super.key,
    required this.photo,
    required this.name,
    required this.relation,
    required this.palette,
    this.size = 44,
    this.celebrating = false,
  });

  @override
  Widget build(BuildContext context) {
    final relColor = palette.byKey(relColorKey[relation] ?? 't2');
    final ring = size >= 60 ? 3.0 : 2.0;
    final inner = size - ring * 2 - 2;

    Widget face;
    if (photo.isNotEmpty && File(photo).existsSync()) {
      face = ClipOval(
        child: Image.file(File(photo),
            width: inner, height: inner, fit: BoxFit.cover, cacheWidth: (inner * 3).round()),
      );
    } else {
      final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
      face = Container(
        width: inner,
        height: inner,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: relColor, shape: BoxShape.circle),
        child: Text(
          initial,
          style: TextStyle(fontSize: inner / 2.3, color: onColor(relColor), fontWeight: FontWeight.bold),
        ),
      );
    }

    final core = Container(
      width: size - ring * 2,
      height: size - ring * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.card, shape: BoxShape.circle),
      child: face,
    );

    if (celebrating) {
      return _SpinningRing(size: size, palette: palette, child: core);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: relColor,
        boxShadow: palette.glow(relColor, strength: 0.35),
      ),
      child: core,
    );
  }
}

class _SpinningRing extends StatefulWidget {
  final double size;
  final Palette palette;
  final Widget child;
  const _SpinningRing({required this.size, required this.palette, required this.child});

  @override
  State<_SpinningRing> createState() => _SpinningRingState();
}

class _SpinningRingState extends State<_SpinningRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Transform.rotate(
              angle: _c.value * 2 * math.pi,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [p.pink, p.yellow, p.cyan, p.purple, p.pink]),
                  boxShadow: p.glow(p.pink, strength: 0.6),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
