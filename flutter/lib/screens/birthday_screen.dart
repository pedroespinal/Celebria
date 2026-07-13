import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../data/db.dart';
import '../models/contact.dart';
import '../services/sound_player.dart';
import '../state/app_state.dart';

/// Full-screen birthday celebration — shown automatically when the app opens
/// on someone's birthday (unless dismissed for today / hidden in Settings).
class BirthdayScreen extends StatefulWidget {
  final List<Contact> todaysContacts;
  const BirthdayScreen({super.key, required this.todaysContacts});

  @override
  State<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends State<BirthdayScreen> {
  static const _confettiFrames = ['🎉', '🎊', '🎈', '🎁', '✨', '🎉', '🎊', '🎈', '🎁', '✨'];
  String _confettiText = '';
  Timer? _confettiTimer;
  int _confettiIndex = 0;

  @override
  void initState() {
    super.initState();
    SoundPlayer.playBirthdayChime();
    Future.delayed(const Duration(milliseconds: 500), _startConfetti);
  }

  void _startConfetti() {
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 220), (timer) {
      if (_confettiIndex >= _confettiFrames.length) {
        timer.cancel();
        return;
      }
      setState(() {
        _confettiText = _confettiFrames.sublist(0, _confettiIndex + 1).join('  ');
        _confettiIndex++;
      });
    });
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
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
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;
    final today = DateTime.now();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🎈 🎊 🎉 🎁 🎉 🎊 🎈', style: TextStyle(fontSize: 22), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text('🎂', style: TextStyle(fontSize: 88), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(t(lang, 'popup_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 26, color: p.pink, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(t(lang, 'birthday_screen_sub'),
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.t2)),
                      const SizedBox(height: 12),
                      Text(_confettiText, style: const TextStyle(fontSize: 24), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Container(height: 2, color: p.pink),
                      const SizedBox(height: 12),
                      for (final c in widget.todaysContacts) ...[
                        _contactCelebrationCard(c, p, lang, today),
                        const SizedBox(height: 12),
                      ],
                      const Text('✨ 🎊 🎉 🎊 ✨', style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _celebrate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('🎉  ${t(lang, 'popup_close')}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactCelebrationCard(Contact c, Palette p, String lang, DateTime today) {
    final age = calcAge(c.day, c.month, c.year);
    final ageThisYear = c.year != null ? today.year - c.year! : null;
    final isMilestone = ageThisYear != null && milestoneAges.contains(ageThisYear);

    var line = age != null
        ? '${c.name}\n${t(lang, 'popup_turns')} $age ${t(lang, 'popup_years')} 🎂'
        : '${c.name}  🎂';
    if (isMilestone) line += '\n✨ ${t(lang, 'milestone_popup')}';

    final phoneDigits = c.phone.replaceAll(RegExp(r'[^0-9+]'), '').replaceFirst(RegExp(r'^\+'), '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMilestone ? p.purpledim : p.cyandim,
        borderRadius: BorderRadius.circular(12),
        border: isMilestone ? Border.all(color: p.yellow) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(line,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, color: isMilestone ? p.yellow : p.cyan, fontWeight: FontWeight.w600)),
          if (phoneDigits.isNotEmpty)
            TextButton(
              onPressed: () {
                final msg = lang == 'es'
                    ? '¡Feliz cumpleaños ${c.name}! 🎂🎉'
                    : 'Happy birthday ${c.name}! 🎂🎉';
                launchUrl(
                  Uri.parse('https://wa.me/$phoneDigits?text=${Uri.encodeComponent(msg)}'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text('💬  ${t(lang, 'whatsapp_wish')}', style: TextStyle(color: p.cyan)),
            ),
        ],
      ),
    );
  }
}
