import 'i18n_data.dart';

export 'i18n_data.dart';

/// Bilingual string lookup, matching main.py's `t(key)` — falls back to the
/// key itself if missing so a typo shows up as visible text, not a crash.
String t(String lang, String key) {
  return kTranslations[lang]?[key] ?? kTranslations['es']?[key] ?? key;
}

String monthName(String lang, int m) {
  final months = lang == 'en' ? kMonthsEn : kMonthsEs;
  if (m < 0 || m >= months.length) return '';
  return months[m];
}

/// index 0 = Monday .. 6 = Sunday (matches DateTime.weekday - 1).
String dayAbbr(String lang, int mondayIndexedWeekday) {
  final days = lang == 'en' ? kDaysAbbrEn : kDaysAbbrEs;
  if (mondayIndexedWeekday < 0 || mondayIndexedWeekday >= days.length) return '';
  return days[mondayIndexedWeekday];
}
