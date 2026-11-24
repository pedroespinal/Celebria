import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../data/db.dart';
import '../models/contact.dart';
import '../services/sound_player.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/wish_sheet.dart';

/// Full-screen celebration — shown automatically when the app opens on
/// someone's birthday / anniversary / special date (unless dismissed for
/// today or hidden in Settings). Neon confetti falls behind the content.
class BirthdayScreen extends StatefulWidget {
  final List<Contact> todaysContacts;
  const BirthdayScreen({super.key, required this.todaysContacts});

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    SoundPlayer.playBirthdayChime();
    final rnd = math.Random();
    for (var i = 0; i < 90; i++) {
      _particles.add(_Particle(
        x: rnd.nextDouble(),
        phase: rnd.nextDouble(),
        speed: 0.6 + rnd.nextDouble() * 0.9,
        size: 5 + rnd.nextDouble() * 7,
        sway: 0.01 + rnd.nextDouble() * 0.04,
        spin: (rnd.nextDouble() - 0.5) * 12,
        colorIndex: rnd.nextInt(5),
        round: rnd.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _celebrate(BuildContext context) async {
    final remindAllDay = await AppDb.instance.getSetting('remind_all_day', '0') == '1';
    if (!remindAllDay) {
      await AppDb.instance.setSetting(
          'birthday_dismissed_date', DateTime.now().toIso8601String().substring(0, 10));
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.palette;
    final lang = state.lang;
    final allBirthdays = widget.todaysContacts.every((c) => c.isBirthday);
    final colors = [p.pink, p.cyan, p.yellow, p.purple, p.green];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ConfettiPainter(_anim, _particles, colors),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                      child: Column(
                        children: [
                          Text(allBirthdays ? '🎂' : '🎉',
                              style: const TextStyle(fontSize: 88), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Text(allBirthdays ? t(lang, 'popup_title') : t(lang, 'special_day_title'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                color: p.pink,
                                fontWeight: FontWeight.bold,
                                shadows: p.isDark
                                    ? [Shadow(color: p.pink.withValues(alpha: 0.8), blurRadius: 18)]
                                    : null,
                              )),
                          if (allBirthdays) ...[
                            const SizedBox(height: 12),
                            Text(t(lang, 'birthday_screen_sub'),
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.t2)),
                          ],
                          const SizedBox(height: 20),
                          for (final c in widget.todaysContacts) ...[
                            _card(c, p, lang),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12), boxShadow: p.glow(p.pink)),
                      child: ElevatedButton(
                        onPressed: () => _celebrate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.pink,
                          foregroundColor: onColor(p.pink),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('🎉  ${t(lang, 'popup_close')}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Contact c, Palette p, String lang) {
    final age = calcAge(c.day, c.month, c.year);
    final isMilestone = c.isBirthday && age != null && milestoneAges.contains(age);
    final accent = isMilestone ? p.yellow : p.cyan;

    final String line;
    if (c.kind == 'anniversary') {
      line = '💍 ${t(lang, 'anniv_line')}${age != null && age > 0 ? ' · $age ${t(lang, 'years_anniv')}' : ''}';
    } else if (c.kind == 'other') {
      line = '⭐ ${t(lang, 'other_line')}${age != null && age > 0 ? ' · $age ${t(lang, 'years_other')}' : ''}';
    } else {
      line = age != null ? '${t(lang, 'popup_turns')} $age ${t(lang, 'popup_years')} 🎂' : '🎂';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: p.glow(accent, strength: 0.6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContactAvatar(
              photo: c.photo, name: c.name, relation: c.relation, palette: p, size: 72, celebrating: true),
          const SizedBox(height: 10),
          Text(c.name,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: accent, fontWeight: FontWeight.bold)),
          Text(line, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.t1)),
          if (isMilestone)
            Text('✨ ${t(lang, 'milestone_popup')}',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.yellow)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => showWishSheet(context, c, lang, p),
            child: Text('💬  ${t(lang, 'whatsapp_wish')}',
                style: TextStyle(color: p.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final double x, phase, speed, size, sway, spin;
  final int colorIndex;
  final bool round;
  const _Particle({
    required this.x,
    required this.phase,
    required this.speed,
    required this.size,
    required this.sway,
    required this.spin,
    required this.colorIndex,
    required this.round,
  });
}

/// Falling confetti driven by one repeating controller: each particle's
/// position is a pure function of time, so no per-frame allocations.
class _ConfettiPainter extends CustomPainter {
  final Animation<double> anim;
  final List<_Particle> particles;
  final List<Color> colors;
  _ConfettiPainter(this.anim, this.particles, this.colors) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final pt in particles) {
      final tt = (anim.value * pt.speed + pt.phase) % 1.0;
      final y = -20 + tt * (size.height + 40);
      final x = (pt.x + math.sin((tt * 6 + pt.phase) * math.pi) * pt.sway) * size.width;
      paint.color = colors[pt.colorIndex].withValues(alpha: 0.85);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tt * pt.spin);
      if (pt.round) {
        canvas.drawCircle(Offset.zero, pt.size / 2.6, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset.zero, width: pt.size, height: pt.size * 0.45),
                const Radius.circular(1.5)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
