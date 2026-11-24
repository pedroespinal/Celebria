// Unit tests for Celebria's pure logic: dates, vCard import, notification plan.
// Run:  cd C:\Celebria\flutter ; flutter test
import 'package:celebria/core/date_utils.dart';
import 'package:celebria/core/vcf_parser.dart';
import 'package:celebria/data/db.dart';
import 'package:celebria/notification_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dates', () {
    test('daysUntil today / tomorrow / wraps to next year', () {
      final now = DateTime(2026, 11, 23, 15, 30);
      expect(daysUntil(23, 11, now: now), 0);
      expect(daysUntil(24, 11, now: now), 1);
      expect(daysUntil(22, 11, now: now), 364);
      expect(daysUntil(1, 1, now: now), 39);
    });

    test('Feb 29 is celebrated on Feb 28 in common years', () {
      expect(birthdayInYear(2027, 2, 29), DateTime(2027, 2, 28));
      expect(birthdayInYear(2028, 2, 29), DateTime(2028, 2, 29));
      expect(daysUntil(29, 2, now: DateTime(2027, 2, 28)), 0);
      expect(calcAge(29, 2, 2000, now: DateTime(2027, 2, 28)), 27);
    });

    test('isValidBirthday rejects impossible dates, accepts Feb 29', () {
      expect(isValidBirthday(29, 2), isTrue);
      expect(isValidBirthday(30, 2), isFalse);
      expect(isValidBirthday(31, 4), isFalse);
      expect(isValidBirthday(31, 12), isTrue);
      expect(isValidBirthday(0, 5), isFalse);
    });

    test('milestone uses the age at the NEXT birthday', () {
      // Turned 30 in Feb 2026; in Nov 2026 the next birthday is the 31st.
      expect(ageOnNextBirthday(10, 2, 1996, now: DateTime(2026, 11, 23)), 31);
      expect(ageOnNextBirthday(10, 12, 1996, now: DateTime(2026, 11, 23)), 30);
      expect(calcAge(10, 2, 1996, now: DateTime(2026, 11, 23)), 30);
      expect(calcAge(10, 12, 1996, now: DateTime(2026, 11, 23)), 29);
    });
  });

  group('vCard parser', () {
    test('Android export: QUOTED-PRINTABLE UTF-8 name, ISO BDAY, grouped TEL', () {
      const vcf = 'BEGIN:VCARD\r\n'
          'VERSION:2.1\r\n'
          'N;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Mu=C3=B1oz;Jos=C3=A9;;;\r\n'
          'FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Jos=C3=A9 Mu=C3=B1oz\r\n'
          'item1.TEL;CELL:+1 809-555-0101\r\n'
          'NOTE:call him, tel later, bday party\r\n'
          'BDAY:1990-05-12\r\n'
          'END:VCARD\r\n';
      final r = parseVcf(vcf);
      expect(r, hasLength(1));
      expect(r.first.name, 'José Muñoz');
      expect(r.first.phone, '+1 809-555-0101');
      expect((r.first.day, r.first.month, r.first.year), (12, 5, 1990));
    });

    test('iOS / vCard 4 forms: VALUE=date, time suffix, --MMDD, folded line', () {
      const vcf = 'BEGIN:VCARD\nVERSION:3.0\nFN:Ana\n  María\nBDAY;VALUE=date:1985-03-07T00:00:00Z\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:4.0\nFN:Luis\nBDAY:--1224\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Sin Fecha\nTEL:123\nEND:VCARD\n'
          'BEGIN:VCARD\nVERSION:3.0\nFN:Mal\nBDAY:2001-02-30\nEND:VCARD\n';
      final r = parseVcf(vcf);
      expect(r.map((c) => c.name), ['Ana María', 'Luis']);
      expect((r[0].day, r[0].month, r[0].year), (7, 3, 1985));
      expect((r[1].day, r[1].month, r[1].year), (24, 12, null));
    });

    test('Apple no-year placeholder 1604 becomes null year', () {
      final r = parseVcf('BEGIN:VCARD\nFN:X\nBDAY:1604-08-15\nEND:VCARD');
      expect((r.single.day, r.single.month, r.single.year), (15, 8, null));
    });
  });

  test('normalizeForSearch strips accents', () {
    expect(normalizeForSearch('José MUÑOZ'), 'jose munoz');
  });

  group('notification plan', () {
    Map<String, Object?> c(String name, int d, int m, [int? y]) =>
        {'name': name, 'day': d, 'month': m, 'year': y};
    final now = DateTime(2026, 11, 23, 9, 0);

    test('default: one day-of notice per year at 08:00 + monthly summaries', () {
      final plan = NotificationHelper.buildPlan(
          [c('Ana', 1, 12, 1996)], const NotifSettings(), now);
      final perContact = plan.where((n) => n.title.contains('Ana')).toList();
      expect(perContact.map((n) => n.when),
          [DateTime(2026, 12, 1, 8), DateTime(2027, 12, 1, 8)]);
      expect(perContact.first.title, contains('30 años HOY'));
      expect(plan.where((n) => n.title.startsWith('📅')), hasLength(2));
      // sorted and ids unique
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].when.isBefore(plan[i - 1].when), isFalse);
      }
      expect(plan.map((n) => n.id).toSet(), hasLength(plan.length));
    });

    test('never exceeds the Android alarm budget, keeps the nearest', () {
      final many = [for (var i = 0; i < 300; i++) c('P$i', 1 + i % 28, 1 + i % 12)];
      final plan = NotificationHelper.buildPlan(many,
          const NotifSettings(notifDays: 3, alsoOnDay: true, notifDays2: 7), now);
      expect(plan.length, NotificationHelper.maxScheduled);
      expect(plan.first.when.isAfter(now), isTrue);
      expect(plan.last.when.isBefore(DateTime(2028)), isTrue);
    });

    test('remind-all-day works even when the day-of notice is off', () {
      final plan = NotificationHelper.buildPlan([c('Leo', 1, 12)],
          const NotifSettings(notifDays: 7, monthlySummary: false,
              remindAllDay: true, remindInterval: 360), now);
      final day = plan.where((n) =>
          n.when.year == 2026 && n.when.month == 12 && n.when.day == 1).map((n) => n.when.hour);
      expect(day, [8, 14, 20]);
    });

    test('Feb 29 contact is notified on Feb 28 in 2027, not Mar 1', () {
      final plan = NotificationHelper.buildPlan([c('Bis', 29, 2)],
          const NotifSettings(monthlySummary: false), now);
      expect(plan.map((n) => n.when), [DateTime(2027, 2, 28, 8)]);
    });

    test('english texts', () {
      final plan = NotificationHelper.buildPlan([c('Ann', 2, 12, 2006)],
          const NotifSettings(lang: 'en', notifDays: 1, monthlySummary: false), now);
      expect(plan.first.title, contains('Ann turns 20 in 1 day(s)'));
    });
  });
}
