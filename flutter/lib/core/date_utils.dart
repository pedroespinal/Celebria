import 'constants.dart';

/// Days from today until the next occurrence of day/month (this year, or
/// next year if already passed). Clamps to day 28 for invalid dates (Feb 29
/// in a non-leap year) exactly like the original Python `days_until`.
int daysUntil(int day, int month) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  DateTime? bd = _safeDate(today.year, month, day);
  if (bd == null) {
    final clamped = day > 28 ? 28 : day;
    bd = _safeDate(today.year, month, clamped);
    if (bd == null) return 999;
  }
  if (bd.isBefore(todayDate)) {
    bd = _safeDate(today.year + 1, month, day) ??
        _safeDate(today.year + 1, month, day > 28 ? 28 : day);
    if (bd == null) return 999;
  }
  return bd.difference(todayDate).inDays;
}

DateTime? _safeDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime normalizes overflow (e.g. Feb 30 -> Mar 2) instead of throwing —
  // detect that and treat it as invalid, matching Python's date() ValueError.
  if (d.month != month || d.day != day) return null;
  return d;
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

/// Current age, or null if no birth year on file. Adjusts down by 1 if this
/// year's birthday hasn't happened yet.
int? calcAge(int day, int month, int? year) {
  if (year == null || year == 0) return null;
  final today = DateTime.now();
  int age = today.year - year;
  final birthdayAlreadyPassedThisYear =
      today.month > month || (today.month == month && today.day >= day);
  if (!birthdayAlreadyPassedThisYear) age -= 1;
  return age < 0 ? 0 : age;
}

String relIconFor(String rel) => relIcon[rel] ?? '⭐';
