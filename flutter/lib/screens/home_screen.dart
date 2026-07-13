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

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenAdd;
  const HomeScreen({super.key, required this.onOpenAdd});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;

    var rows = state.contacts;
    if (state.relationFilter != 'all') {
      rows = rows.where((c) => c.relation == state.relationFilter).toList();
    }
    if (state.search.isNotEmpty) {
      final q = state.search.toLowerCase();
      rows = rows.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    final today = rows.where((c) => daysUntil(c.day, c.month) == 0).toList();
    final week = rows.where((c) {
      final d = daysUntil(c.day, c.month);
      return d >= 1 && d <= 7;
    }).toList();
    final soon = rows.where((c) {
      final d = daysUntil(c.day, c.month);
      return d >= 8 && d <= 30;
    }).toList();
    final all = rows.where((c) => daysUntil(c.day, c.month) > 30).toList();

    final now = DateTime.now();
    final monthBdays = state.contacts.where((c) => c.month == now.month).toList();
    final monthLabel = lang == 'es'
        ? '${monthName(lang, now.month)}: ${monthBdays.length} cumpleaños'
        : '${monthName(lang, now.month)}: ${monthBdays.length} birthday${monthBdays.length == 1 ? '' : 's'}';

    void openContact(Contact c) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(contactId: c.id)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              if (monthBdays.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {}, // calendar tab switch handled by user tapping bottom nav
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: palette.cyan,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🗓', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(monthLabel,
                              style: TextStyle(
                                  fontSize: 12, color: palette.bg, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextField(
                onChanged: (v) => state.setSearch(v),
                style: TextStyle(color: palette.t1),
                decoration: InputDecoration(
                  hintText: t(lang, 'search_hint'),
                  hintStyle: TextStyle(color: palette.t3),
                  filled: true,
                  fillColor: palette.bg3,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: palette.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('filter_all', 'all'),
                    ('filter_fam', 'family'),
                    ('filter_fri', 'friend'),
                    ('filter_wor', 'work'),
                  ].map((pair) {
                    final (key, value) = pair;
                    final active = state.relationFilter == value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => state.setRelationFilter(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? palette.cyandim : palette.bg3,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(t(lang, key),
                              style: TextStyle(
                                  fontSize: 11, color: active ? palette.cyan : palette.t3)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    t(lang, 'no_contacts'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.t2, fontSize: 14),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  children: [
                    for (final (titleKey, bucket) in [
                      ('today_title', today),
                      ('week_title', week),
                      ('month_title', soon),
                      ('all_title', all),
                    ])
                      if (bucket.isNotEmpty) ...[
                        SectionHeader(t(lang, titleKey), palette: palette),
                        for (final c in bucket)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ContactCard(
                              contact: c,
                              lang: lang,
                              palette: palette,
                              onTap: () => openContact(c),
                            ),
                          ),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}
