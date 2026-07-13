import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import 'add_edit_screen.dart';

class DetailScreen extends StatelessWidget {
  final int contactId;
  const DetailScreen({super.key, required this.contactId});

  Widget _card(Palette p, Color borderColor, Widget child, {EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;

    Contact? c;
    for (final contact in state.contacts) {
      if (contact.id == contactId) {
        c = contact;
        break;
      }
    }

    if (c == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).pop());
      return const Scaffold(body: SizedBox.shrink());
    }

    final dLeft = daysUntil(c.day, c.month);
    final age = calcAge(c.day, c.month, c.year);
    final relColor = p.byKey(const {
          'family': 'cyan',
          'friend': 'green',
          'work': 'purple',
          'other': 'yellow',
        }[c.relation] ??
        't2');

    var ds = lang == 'es'
        ? '${c.day} de ${monthName(lang, c.month)}'
        : '${monthName(lang, c.month)} ${c.day}';
    if (c.year != null) ds += lang == 'es' ? ', ${c.year}' : ', ${c.year}';

    final stat1Val = dLeft == 0 ? t(lang, 'today_badge') : '$dLeft';
    final stat1Lbl = dLeft == 0 ? '' : t(lang, 'days_left');
    final stat1Col = dLeft == 0 ? p.pink : p.cyan;

    final infoRows = <(String, String, String)>[
      ('📞', t(lang, 'field_phone'), c.phone),
      ('✉', t(lang, 'field_email'), c.email),
      ('👤', t(lang, 'field_relation'), t(lang, 'rel_${c.relation}')),
      ('📝', t(lang, 'field_notes'), c.notes),
      ('🎁', t(lang, 'field_gift'), c.giftNote),
    ].where((row) => row.$3.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(c.name, style: TextStyle(color: p.cyan, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddEditScreen(
                existing: c,
                onDone: () => Navigator.of(context).pop(),
              ),
            )),
            child: Text('✏  ${t(lang, 'btn_edit')}', style: TextStyle(color: p.purple)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        children: [
          _card(
            p,
            relColor,
            Column(
              children: [
                ContactAvatar(photo: c.photo, name: c.name, relation: c.relation, palette: p, size: 80),
                const SizedBox(height: 8),
                Text(c.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: relColor, fontWeight: FontWeight.bold)),
                Text(ds, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.t3)),
              ],
            ),
            padding: const EdgeInsets.all(16),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _card(
                  p,
                  stat1Col,
                  Column(children: [
                    Text(stat1Val,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, color: stat1Col, fontWeight: FontWeight.bold)),
                    Text(stat1Lbl, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.t3)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _card(
                  p,
                  p.green,
                  Column(children: [
                    Text(age != null ? '$age' : '?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, color: p.green, fontWeight: FontWeight.bold)),
                    Text(t(lang, 'years'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: p.t3)),
                  ]),
                ),
              ),
            ],
          ),
          for (final row in infoRows) ...[
            const SizedBox(height: 10),
            _card(
              p,
              p.border,
              Row(
                children: [
                  SizedBox(width: 34, child: Text(row.$1, style: const TextStyle(fontSize: 20))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$2, style: TextStyle(fontSize: 10, color: p.t3)),
                        Text(row.$3, style: TextStyle(fontSize: 13, color: p.t1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (c.phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: p.green,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final digits = c!.phone.replaceAll(RegExp(r'[^0-9]'), '');
                  launchUrl(Uri.parse('https://wa.me/$digits'),
                      mode: LaunchMode.externalApplication);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('💬  ${t(lang, 'btn_whatsapp')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
