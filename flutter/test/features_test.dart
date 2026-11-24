// Tests for v1.10.0 features: palettes, date types, gift reminders,
// notification payloads, greeting templates, weekly backup schedule.
import 'dart:convert';

import 'package:celebria/core/palette.dart';
import 'package:celebria/models/contact.dart';
import 'package:celebria/notification_helper.dart';
import 'package:celebria/services/backup_service.dart';
import 'package:celebria/widgets/wish_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('palettes', () {
    test('tropical is the default and unknown families fall back to it', () {
      expect(paletteFor('nope', 'dark').family, 'tropical');
      expect(paletteFor('cyber', 'light').isDark, isFalse);
    });

    for (final fam in paletteFamilies) {
      for (final mode in ['dark', 'light']) {
        test('$fam/$mode: text and accents are readable', () {
          final p = paletteFor(fam, mode);
          expect(_contrast(p.t1, p.bg), greaterThan(7), reason: 'body text');
          expect(_contrast(p.t3, p.bg), greaterThan(3), reason: 'muted text');
          for (final c in [p.cyan, p.pink, p.green, p.yellow, p.purple]) {
            expect(_contrast(c, p.card), greaterThan(3), reason: 'accent $c on card');
            expect(_contrast(onColor(c), c), greaterThan(4.5), reason: 'label on $c');
          }
          expect(p.glow(p.cyan).isEmpty, !p.isDark);
        });
      }
    }
  });

  group('contact kind', () {
    test('rows from older versions (no kind column) are birthdays', () {
      final c = Contact.fromMap({'id': 1, 'name': 'A', 'day': 1, 'month': 1});
      expect(c.kind, 'birthday');
      expect(Contact.fromMap({'id': 1, 'name': 'A', 'day': 1, 'month': 1, 'kind': 'x'}).kind,
          'birthday');
      expect(c.copyWith(kind: 'anniversary').toMap()['kind'], 'anniversary');
    });
  });

  group('notification plan v1.10', () {
    final now = DateTime(2026, 11, 23, 9);
    Map<String, Object?> row(int id, String name, int d, int m,
            {int? y, String kind = 'birthday', String gift = ''}) =>
        {'id': id, 'name': name, 'day': d, 'month': m, 'year': y, 'kind': kind, 'gift_note': gift};

    test('payload points to the contact; monthly summary to the month', () {
      final plan = NotificationHelper.buildPlan([row(7, 'Ana', 1, 12)], const NotifSettings(), now);
      expect(plan.where((n) => n.title.contains('Ana')).every((n) => n.payload == 'contact:7'), isTrue);
      expect(plan.firstWhere((n) => n.title.startsWith('📅')).payload, 'month:12');
    });

    test('gift idea appears in advance notices only', () {
      final plan = NotificationHelper.buildPlan([row(1, 'Ana', 1, 12, gift: 'Perfume')],
          const NotifSettings(notifDays: 7, alsoOnDay: true, monthlySummary: false), now);
      final before = plan.firstWhere((n) => n.when == DateTime(2026, 11, 24, 8));
      expect(before.body, contains('Perfume'));
      final dayOf = plan.firstWhere((n) => n.when == DateTime(2026, 12, 1, 8));
      expect(dayOf.body, isNot(contains('Perfume')));
    });

    test('anniversary / special titles', () {
      final plan = NotificationHelper.buildPlan([
        row(1, 'Ana y Luis', 1, 12, y: 2016, kind: 'anniversary'),
        row(2, 'Graduación', 2, 12, kind: 'other'),
      ], const NotifSettings(monthlySummary: false), now);
      expect(plan[0].title, '💍 ¡Aniversario de Ana y Luis HOY! (10 años)');
      expect(plan[1].title, '⭐ ¡Graduación es HOY!');
    });
  });

  group('greeting templates', () {
    test('three templates with first name and age, per language', () {
      const c = Contact(id: 1, name: 'José Muñoz', day: 25, month: 11, year: 1996);
      final es = wishTemplates(c, 'es', now: DateTime(2026, 11, 23));
      expect(es, hasLength(3));
      expect(es.every((m) => m.contains('José')), isTrue);
      expect(es[1], contains('30 años'));
      final en = wishTemplates(c, 'en', now: DateTime(2026, 11, 23));
      expect(en[1], contains('30th birthday'));
    });

    test('anniversary templates mention years together', () {
      const c = Contact(id: 1, name: 'Ana y Luis', day: 1, month: 12, year: 2016, kind: 'anniversary');
      expect(wishTemplates(c, 'es', now: DateTime(2026, 11, 23))[1], contains('10 años juntos'));
    });

    test('waDigits keeps the country code digits only', () {
      expect(waDigits('+1 (809) 555-0101'), '18095550101');
    });
  });

  test('version.json with a UTF-8 BOM still parses once the BOM is stripped', () {
    const body = '﻿{"latest":"1.10.0"}';
    expect(() => jsonDecode(body), throwsFormatException);
    expect(jsonDecode(body.replaceFirst('﻿', ''))['latest'], '1.10.0');
  });

  test('weekly backup is due after 7 days, or if the clock went backwards', () {
    final now = DateTime(2026, 11, 23);
    expect(BackupService.isDue(null, now), isTrue);
    expect(BackupService.isDue(now.subtract(const Duration(days: 6)), now), isFalse);
    expect(BackupService.isDue(now.subtract(const Duration(days: 7)), now), isTrue);
    expect(BackupService.isDue(now.add(const Duration(days: 3)), now), isTrue);
  });
}
