import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../models/contact.dart';
import '../state/app_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Widget _card(Palette p, Widget child, {EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
        child: child,
      );

  Widget _statCard(Palette p, int val, String lbl, Color col) => Expanded(
        child: _card(
          p,
          Column(
            children: [
              Text('$val',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, color: col, fontWeight: FontWeight.bold)),
              Text(lbl, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: p.t3)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;
    final rows = state.contacts;
    final today = DateTime.now();

    final total = rows.length;
    final cntToday = rows.where((r) => daysUntil(r.day, r.month) == 0).length;
    final cntWeek = rows.where((r) {
      final d = daysUntil(r.day, r.month);
      return d >= 1 && d <= 7;
    }).length;
    final cntMonth = rows.where((r) {
      final d = daysUntil(r.day, r.month);
      return d >= 8 && d <= 30;
    }).length;

    final upcoming = rows.where((r) => daysUntil(r.day, r.month) > 0).toList()
      ..sort((a, b) => daysUntil(a.day, a.month).compareTo(daysUntil(b.day, b.month)));
    final String nxtTxt;
    final Color nxtCol;
    if (upcoming.isNotEmpty) {
      final nr = upcoming.first;
      nxtTxt = '${nr.name}  —  ${daysUntil(nr.day, nr.month)} ${t(lang, 'stats_days')}';
      nxtCol = p.green;
    } else {
      nxtTxt = t(lang, 'stats_none');
      nxtCol = p.t3;
    }

    final relCount = <String, int>{};
    for (final r in rows) {
      relCount[r.relation] = (relCount[r.relation] ?? 0) + 1;
    }
    final relLabels = {
      'family': t(lang, 'rel_family'),
      'friend': t(lang, 'rel_friend'),
      'work': t(lang, 'rel_work'),
      'other': t(lang, 'rel_other'),
    };

    final monthCount = <int, int>{};
    for (final r in rows) {
      monthCount[r.month] = (monthCount[r.month] ?? 0) + 1;
    }
    final maxMc = monthCount.values.isEmpty ? 1 : monthCount.values.reduce((a, b) => a > b ? a : b);
    const maxBarH = 56.0;

    final milestoneRows = <(Contact, int)>[];
    for (final r in rows) {
      if (r.year == null) continue;
      final ageThisYr = today.year - r.year!;
      if (milestoneAges.contains(ageThisYr)) milestoneRows.add((r, ageThisYr));
    }
    milestoneRows.sort((a, b) => daysUntil(a.$1.day, a.$1.month).compareTo(daysUntil(b.$1.day, b.$1.month)));

    final zodiacCount = <String, int>{};
    for (final r in rows) {
      if (r.day > 0 && r.month > 0) {
        final (sym, _, _) = zodiacSign(r.day, r.month);
        zodiacCount[sym] = (zodiacCount[sym] ?? 0) + 1;
      }
    }
    final zMax = zodiacCount.values.isEmpty ? 1 : zodiacCount.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('📊  ${t(lang, 'stats_title')}', style: TextStyle(color: p.cyan)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        children: [
          Row(children: [
            _statCard(p, total, t(lang, 'stats_total'), p.cyan),
            const SizedBox(width: 8),
            _statCard(p, cntToday, t(lang, 'stats_today'), p.pink),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _statCard(p, cntWeek, t(lang, 'stats_week'), p.yellow),
            const SizedBox(width: 8),
            _statCard(p, cntMonth, t(lang, 'stats_month_sec'), p.green),
          ]),
          const SizedBox(height: 10),
          _card(
            p,
            Row(children: [
              const SizedBox(width: 36, child: Text('🎂', style: TextStyle(fontSize: 24))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t(lang, 'stats_next'), style: TextStyle(fontSize: 10, color: p.t3)),
                    Text(nxtTxt, style: TextStyle(fontSize: 13, color: nxtCol, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          _card(
            p,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(lang, 'stats_by_rel'), style: TextStyle(fontSize: 11, color: p.t2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final rk in ['family', 'friend', 'work', 'other'])
                  if ((relCount[rk] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text(relIconFor(rk), style: const TextStyle(fontSize: 18))),
                          SizedBox(width: 72, child: Text(relLabels[rk]!, style: TextStyle(fontSize: 12, color: p.t2))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (relCount[rk] ?? 0) / (total == 0 ? 1 : total),
                                minHeight: 12,
                                backgroundColor: p.bg3,
                                valueColor: AlwaysStoppedAnimation(p.byKey(relColorKey[rk] ?? 't2')),
                              ),
                            ),
                          ),
                          SizedBox(
                              width: 28,
                              child: Text('${relCount[rk]}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: p.t1, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            p,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(lang, 'stats_by_month'), style: TextStyle(fontSize: 11, color: p.t2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 1; i <= 12; i++)
                      Builder(builder: (_) {
                        final cnt = monthCount[i] ?? 0;
                        final isCur = i == today.month;
                        final barH = (cnt / maxMc * maxBarH).clamp(4.0, maxBarH);
                        final barCol = isCur ? p.cyan : p.violet;
                        final mn = monthName(lang, i).substring(0, 3);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cnt != 0 ? '$cnt' : ' ',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: isCur ? p.cyan : p.t3,
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                            SizedBox(height: maxBarH - barH),
                            Container(
                                width: 14,
                                height: barH,
                                decoration:
                                    BoxDecoration(color: barCol, borderRadius: BorderRadius.circular(3))),
                            Text(mn,
                                style: TextStyle(
                                    fontSize: 8,
                                    color: isCur ? p.cyan : p.t3,
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.normal)),
                          ],
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            p,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(lang, 'zodiac_title'), style: TextStyle(fontSize: 11, color: p.t2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (zodiacCount.isEmpty)
                  Text(t(lang, 'stats_none'), style: TextStyle(fontSize: 11, color: p.t3))
                else
                  for (final z in zodiacTable)
                    if ((zodiacCount[z.symbol] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 24, child: Text(z.symbol, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
                            SizedBox(width: 80, child: Text(lang == 'es' ? z.nameEs : z.nameEn, style: TextStyle(fontSize: 11, color: p.t2))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: (zodiacCount[z.symbol] ?? 0) / zMax,
                                  minHeight: 10,
                                  backgroundColor: p.bg3,
                                  valueColor: AlwaysStoppedAnimation(p.violet),
                                ),
                              ),
                            ),
                            SizedBox(
                                width: 24,
                                child: Text('${zodiacCount[z.symbol]}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11, color: p.t1, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _card(
            p,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(lang, 'stats_milestones'), style: TextStyle(fontSize: 11, color: p.t2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (milestoneRows.isEmpty)
                  Text(t(lang, 'stats_no_milestones'), style: TextStyle(fontSize: 11, color: p.t3))
                else
                  for (final pair in milestoneRows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const SizedBox(width: 28, child: Text('✨', textAlign: TextAlign.center, style: TextStyle(fontSize: 16))),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pair.$1.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: p.yellow, fontWeight: FontWeight.w600)),
                                Text(
                                    '${pair.$2} ${t(lang, 'years')}  •  ${daysUntil(pair.$1.day, pair.$1.month) == 0 ? t(lang, 'today_badge') : '${daysUntil(pair.$1.day, pair.$1.month)} ${t(lang, 'stats_days')}'}',
                                    style: TextStyle(fontSize: 10, color: p.t3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
