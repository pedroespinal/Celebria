/// App-wide constants ported from the original main.py.
library;

const String appName = 'Celebria';
const String appVersion = '1.9.7';
const String appAuthor = 'Pedro Espinal';
const String appRights = 'Todos los derechos reservados';
const String githubRepo = 'pedroespinal/Celebria';

String get appYear => DateTime.now().year.toString();
String get copyright => 'Creado por: $appAuthor   ·   $appRights   ©$appYear';

/// Round-number ages that get a milestone highlight (badge, gold color, 🎊 icon).
const Set<int> milestoneAges = {15, 18, 21, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100};

/// Relationship type → emoji icon.
const Map<String, String> relIcon = {
  'family': '👪',
  'friend': '👥',
  'work': '💼',
  'other': '⭐',
};

/// Relationship type → palette color key (see palette.dart).
const Map<String, String> relColorKey = {
  'family': 'cyan',
  'friend': 'green',
  'work': 'purple',
  'other': 'yellow',
};

/// Zodiac sign ranges: (startMonth, startDay), (endMonth, endDay), symbol, name key.
/// nameEs/nameEn hold the display name directly (no separate i18n lookup).
class ZodiacRange {
  final int startMonth, startDay, endMonth, endDay;
  final String symbol;
  final String nameEs, nameEn;
  const ZodiacRange(this.startMonth, this.startDay, this.endMonth, this.endDay,
      this.symbol, this.nameEs, this.nameEn);
}

const List<ZodiacRange> zodiacTable = [
  ZodiacRange(3, 21, 4, 19, '♈', 'Aries', 'Aries'),
  ZodiacRange(4, 20, 5, 20, '♉', 'Tauro', 'Taurus'),
  ZodiacRange(5, 21, 6, 20, '♊', 'Géminis', 'Gemini'),
  ZodiacRange(6, 21, 7, 22, '♋', 'Cáncer', 'Cancer'),
  ZodiacRange(7, 23, 8, 22, '♌', 'Leo', 'Leo'),
  ZodiacRange(8, 23, 9, 22, '♍', 'Virgo', 'Virgo'),
  ZodiacRange(9, 23, 10, 22, '♎', 'Libra', 'Libra'),
  ZodiacRange(10, 23, 11, 21, '♏', 'Escorpio', 'Scorpio'),
  ZodiacRange(11, 22, 12, 21, '♐', 'Sagitario', 'Sagittarius'),
  ZodiacRange(12, 22, 1, 19, '♑', 'Capricornio', 'Capricorn'),
  ZodiacRange(1, 20, 2, 18, '♒', 'Acuario', 'Aquarius'),
  ZodiacRange(2, 19, 3, 20, '♓', 'Piscis', 'Pisces'),
];
