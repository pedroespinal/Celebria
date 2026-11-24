import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../models/contact.dart';
import 'buttons.dart';

/// i18n key for the unit shown after an age, by date type.
String yearsLabelKey(String kind) => switch (kind) {
      'anniversary' => 'years_anniv',
      'other' => 'years_other',
      _ => 'years',
    };

/// Ready-made greetings (formal / warm / funny) with the contact's first
/// name and age already filled in. Pure function so it can be unit-tested.
List<String> wishTemplates(Contact c, String lang, {DateTime? now}) {
  final first = c.name.trim().split(RegExp(r'\s+')).first;
  final n = ageOnNextBirthday(c.day, c.month, c.year, now: now);
  final es = lang == 'es';
  switch (c.kind) {
    case 'anniversary':
      final yrs = n != null && n > 0 ? (es ? ' ¡$n años juntos!' : ' $n years together!') : '';
      return es
          ? [
              'Muchas felicidades en su aniversario, ${c.name}.$yrs Les deseo muchos años más de amor y felicidad.',
              '¡Feliz aniversario, ${c.name}! 💍❤️$yrs Que su amor siga creciendo cada día. ¡Los quiero mucho!',
              '¡Feliz aniversario! 💍 ¿${n ?? 'Tantos'} años y todavía se aguantan? Eso merece un premio... ¡y pastel! 🎂😂',
            ]
          : [
              'Congratulations on your anniversary, ${c.name}.$yrs Wishing you many more years of love and happiness.',
              'Happy anniversary, ${c.name}! 💍❤️$yrs May your love keep growing every day. Love you both!',
              'Happy anniversary! 💍 ${n ?? 'So many'} years and you still put up with each other? That deserves a prize... and cake! 🎂😂',
            ];
    case 'other':
      return es
          ? [
              'Muchas felicidades en este día tan especial, $first. Te deseo lo mejor.',
              '¡Felicidades, $first! ⭐ Hoy es un día para celebrar contigo. ¡Un abrazo enorme!',
              '¡$first, hoy se celebra! ⭐ Que no falte la música, la comida... ¡ni el pastel! 🎉😄',
            ]
          : [
              'Congratulations on this special day, $first. Wishing you all the best.',
              'Congrats, $first! ⭐ Today is a day to celebrate you. Big hug!',
              '$first, today we celebrate! ⭐ Bring the music, the food... and the cake! 🎉😄',
            ];
    default:
      final ageEs = n != null ? ' por tus $n años' : '';
      final ageEn = n != null ? ' on your ${_ordinal(n)}' : '';
      return es
          ? [
              'Muchas felicidades en tu cumpleaños, $first. Te deseo un año lleno de salud, éxitos y bendiciones.',
              '¡Feliz cumpleaños, $first! 🎂❤️ Muchas felicidades$ageEs. Que este nuevo año te traiga todo lo que sueñas. ¡Te quiero mucho!',
              '¡Feliz cumple, $first! 🎉 ${n != null ? '$n años' : 'Un año más'} y sigues igual de joven... bueno, casi 😂 ¡A celebrar en grande!',
            ]
          : [
              'Happy birthday, $first. Wishing you a year full of health, success and blessings.',
              'Happy birthday, $first! 🎂❤️ Congratulations$ageEn. May this new year bring you everything you dream of. Love you!',
              'Happy birthday, $first! 🎉 ${n != null ? '$n years' : 'Another year'} and still looking young... well, almost 😂 Let\'s party!',
            ];
  }
}

String _ordinal(int n) {
  final mod100 = n % 100;
  final suffix = (mod100 >= 11 && mod100 <= 13)
      ? 'th'
      : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return '$n$suffix birthday';
}

/// Digits-only phone for wa.me (keeps the country code, drops "+").
String waDigits(String phone) => phone.replaceAll(RegExp(r'[^0-9]'), '');

/// Bottom sheet: pick a template, tweak it, then send via WhatsApp or copy.
Future<void> showWishSheet(BuildContext context, Contact c, String lang, Palette p) {
  final templates = wishTemplates(c, lang);
  final ctrl = TextEditingController(text: templates[1]);
  var selected = 1;
  final labels = [t(lang, 'wish_formal'), t(lang, 'wish_warm'), t(lang, 'wish_funny')];

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.bg2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💬  ${t(lang, 'wish_title')}',
                  style: TextStyle(color: p.cyan, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < 3; i++)
                  OptionButton(
                    label: labels[i],
                    active: selected == i,
                    palette: p,
                    margin: const EdgeInsets.only(right: 4),
                    onTap: () => setS(() {
                      selected = i;
                      ctrl.text = templates[i];
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                minLines: 3,
                maxLines: 6,
                style: TextStyle(color: p.t1, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: p.bg3,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.cyan)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: SolidButton('📋  ${t(lang, 'wish_copy')}', p.purple, onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: ctrl.text));
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx)
                          .showSnackBar(SnackBar(content: Text(t(lang, 'wish_copied'))));
                    }
                  }),
                ),
                if (waDigits(c.phone).isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SolidButton('💬  ${t(lang, 'wish_send')}', p.green, onPressed: () {
                      launchUrl(
                        Uri.parse('https://wa.me/${waDigits(c.phone)}?text=${Uri.encodeComponent(ctrl.text)}'),
                        mode: LaunchMode.externalApplication,
                      );
                      Navigator.of(sheetCtx).pop();
                    }),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}
