import 'dart:io';

import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Circle with the contact's photo, or a colored initial if no photo is set.
class ContactAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final String relation;
  final Palette palette;
  final double size;

  const ContactAvatar({
    super.key,
    required this.photo,
    required this.name,
    required this.relation,
    required this.palette,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final r = size / 2;
    if (photo.isNotEmpty && File(photo).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: Image.file(File(photo), width: size, height: size, fit: BoxFit.cover),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final relKey = const {
      'family': 'cyan',
      'friend': 'green',
      'work': 'purple',
      'other': 'yellow',
    }[relation] ??
        't2';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.byKey(relKey),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size / 2.4,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
