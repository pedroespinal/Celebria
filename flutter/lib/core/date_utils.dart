import 'constants.dart';

/// The calendar date of a day/month birthday in [year]. Days that don't exist
/// that year (Feb 29 in a non-leap year, or an invalid "31" in a 30-day
/// month from old/imported data) are clamped to the month's last day, so
/// Feb 29 birthdays are celebrated on Feb 28 in common years. This single
/// rule is shared by the home list, the calendar, the notifications and the
/// home-screen widget so they always agree on the date.
DateTime birthdayInYear(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final d = day < 1 ? 1 : (day > lastDay ? lastDay : day);
  return DateTime(year, month, d);
}

bool isValidBirthday(int day, int month) {
  if (month < 1 || month > 12 || day < 1) return false;
  // 2024 is a leap year, so Feb 29 is accepted as a real birthday.
  return day <= DateTime(2024, month + 1, 0).day;
}

/// Date of the next occurrence (today counts) of a day/month birthday.
DateTime nextBirthday(int day, int month, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  var bd = birthdayInYear(today.year, month, day);
  if (bd.isBefore(today)) bd = birthdayInYear(today.year + 1, month, day);
  return bd;
}

/// Days from today until the next occurrence of day/month (0 = today).
/// Computed on UTC calendar dates: a local-time difference spanning a DST
/// change is 23h/25h long, and `.inDays` would truncate it to one day less.
int daysUntil(int day, int month, {DateTime? now}) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return 999;
  final n = now ?? DateTime.now();
  final bd = nextBirthday(day, month, now: n);
  return DateTime.utc(bd.year, bd.month, bd.day)
      .difference(DateTime.utc(n.year, n.month, n.day))
      .inDays;
}

/// Age the person turns on their next birthday (today counts), or null if
/// no birth year is on file. Used for milestone badges, so a milestone that
/// already happened earlier this year is no longer highlighted.
int? ageOnNextBirthday(int day, int month, int? year, {DateTime? now}) {
  if (year == null || year <= 0) return null;
  final age = nextBirthday(day, month, now: now).year - year;
  return age < 0 ? null : age;
}

/// (symbol, nameEs, nameEn) for the zodiac sign covering this day/month.
(String, String, String) zodiacSign(int day, int month) {
  for (final z in zodiacTable) {
    if (z.startMonth <= z.endMonth) {
      if ((month == z.startMonth && day >= z.startDay) ||
          (month == z.endMonth && day <= z.endDay) ||
          (z.startMonth < month && month < z.endMonth)) {
        return (z.symbol, z.nameEs, z.nameEn);
      }
    } else {
      // Wraparound sign (Capricorn: Dec 22 -> Jan 19)
      if ((month == z.startMonth && day >= z.startDay) ||
          (month == z.endMonth && day <= z.endDay) ||
          month > z.startMonth ||
          month < z.endMonth) {
        return (z.symbol, z.nameEs, z.nameEn);
      }
    }
  }
  return ('♓', 'Piscis', 'Pisces');
}

/// Current age, or null if no birth year on file. Uses the same clamped
/// birthday date as everything else (Feb 29 -> Feb 28 in common years).
int? calcAge(int day, int month, int? year, {DateTime? now}) {
  if (year == null || year == 0) return null;
  final next = ageOnNextBirthday(day, month, year, now: now);
  if (next == null) return 0;
  final age = daysUntil(day, month, now: now) == 0 ? next : next - 1;
  return age < 0 ? 0 : age;
}

String relIconFor(String rel) => relIcon[rel] ?? '⭐';
