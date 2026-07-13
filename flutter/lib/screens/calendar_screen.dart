import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../models/contact.dart';
import '../state/app_state.dart';
import '../widgets/contact_card.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
  }

  void _openDay(BuildContext context, List<Contact> rowsForDay, String lang, Palette p) {
    if (rowsForDay.length == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(contactId: rowsForDay.first.id)),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: p.bg2,
        title: Text(t(lang, 'cal_multi_title'),
            style: TextStyle(color: p.cyan, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 260,
          height: (rowsForDay.length * 64).clamp(0, 300).toDouble(),
          child: ListView(
            children: [
              for (final r in rowsForDay)
                ListTile(
                  leading: Text(relIconFor(r.relation), style: const TextStyle(fontSize: 18)),
                  title: Text(r.name, style: TextStyle(color: p.t1, fontSize: 13)),
                  subtitle: Text('${r.day} ${monthName(lang, r.month)}',
                      style: TextStyle(color: p.t3, fontSize: 11)),
                  onTap: () {
                    Navigator.of(dialogCtx).pop();
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => DetailScreen(contactId: r.id)));
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(t(lang, 'btn_cancel'), style: TextStyle(color: p.t3)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;

    final bdMap = <(int, int), List<Contact>>{};
    for (final c in state.contacts) {
      bdMap.putIfAbsent((c.month, c.day), () => []).add(c);
    }

    final firstOfMonth = DateTime(_year, _month, 1);
    final firstWeekday = firstOfMonth.weekday - 1; // 0=Mon .. 6=Sun
    final numDays = DateTime(_year, _month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var dn = 1; dn <= numDays; dn++) {
      final bds = bdMap[(_month, dn)] ?? const <Contact>[];
      final isToday = dn == today.day && _month == today.month && _year == today.year;
      final bg = isToday ? p.cyandim : (bds.isNotEmpty ? p.pinkdim : p.bg3);
      final dc = isToday ? p.cyan : (bds.isNotEmpty ? p.pink : p.t1);
      cells.add(
        Material(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: bds.isNotEmpty ? () => _openDay(context, bds, lang, p) : null,
            child: SizedBox(
              height: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$dn',
                      style: TextStyle(fontSize: 13, color: dc, fontWeight: FontWeight.bold)),
                  if (bds.isNotEmpty)
                    Text('🎂' * (bds.length > 2 ? 2 : bds.length), style: const TextStyle(fontSize: 8))
                  else
                    const SizedBox(height: 11),
                ],
              ),
            ),
          ),
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    final gridRows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      gridRows.add(Row(
        children: [
          for (final cell in cells.sublist(i, i + 7))
            Expanded(child: Padding(padding: const EdgeInsets.all(1), child: cell)),
        ],
      ));
    }

    final monthContacts = state.contacts.where((c) => c.month == _month).toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  icon: Icon(Icons.chevron_left, color: p.violet), onPressed: _prevMonth),
              Expanded(
                child: Text('${monthName(lang, _month)} $_year',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: p.cyan, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  icon: Icon(Icons.chevron_right, color: p.violet), onPressed: _nextMonth),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(dayAbbr(lang, i),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: p.violet, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            child: Column(children: gridRows),
          ),
          if (monthContacts.isNotEmpty) ...[
            const SizedBox(height: 6),
            SectionHeader('🎂  ${monthName(lang, _month)}', palette: p),
            for (final c in monthContacts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ContactCard(
                  contact: c,
                  lang: lang,
                  palette: p,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => DetailScreen(contactId: c.id))),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
