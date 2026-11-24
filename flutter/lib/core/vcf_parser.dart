import 'dart:convert';

/// Parsed contact extracted from a .vcf file, ready to review/import.
class VcfContact {
  String? name;
  int? day;
  int? month;
  int? year;
  String? phone;
}

/// vCard 2.1 / 3.0 / 4.0 parser for the fields Celebria uses: FN (falls back
/// to N), BDAY and the first TEL of each card.
///
/// Handles what real phone exports contain — the old line-by-line port did
/// not, and silently dropped many contacts from Android exports:
///   • property parameters: `FN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:…`
///     (Android writes every non-ASCII name — "José", "Muñoz" — this way)
///   • QUOTED-PRINTABLE values, including `=` soft line breaks
///   • folded lines (continuation lines starting with a space/tab)
///   • group prefixes (`item1.TEL:…`) and escaped `\,` `\;` `\n`
///   • BDAY as `19900512`, `1990-05-12`, `1990-05-12T00:00:00Z`, `--0512`,
///     `--05-12`, `BDAY;VALUE=date:…`; Apple's no-year placeholder 1604 → null
///   • matches property NAMES exactly, so a NOTE that merely mentions "tel"
///     or "bday" no longer overwrites the phone/birthday.
List<VcfContact> parseVcf(String content) {
  final result = <VcfContact>[];
  VcfContact? current;

  for (final line in _unfold(content)) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final head = line.substring(0, colon);
    var value = line.substring(colon + 1);

    final headParts = head.split(';');
    var prop = headParts.first.trim().toUpperCase();
    final dot = prop.lastIndexOf('.');
    if (dot >= 0) prop = prop.substring(dot + 1); // item1.TEL -> TEL
    final params = headParts.skip(1).map((s) => s.trim().toUpperCase()).toList();

    if (prop == 'BEGIN' && value.trim().toUpperCase() == 'VCARD') {
      current = VcfContact();
      continue;
    }
    if (prop == 'END' && value.trim().toUpperCase() == 'VCARD') {
      final c = current;
      if (c != null &&
          (c.name ?? '').isNotEmpty &&
          c.day != null &&
          c.month != null &&
          c.month! >= 1 &&
          c.month! <= 12 &&
          c.day! >= 1 &&
          c.day! <= DateTime(2024, c.month! + 1, 0).day) {
        result.add(c);
      }
      current = null;
      continue;
    }
    if (current == null) continue;

    if (params.any((p) => p == 'ENCODING=QUOTED-PRINTABLE' || p == 'QUOTED-PRINTABLE')) {
      value = _decodeQuotedPrintable(value);
    }
    value = _unescape(value).trim();

    switch (prop) {
      case 'FN':
        if (value.isNotEmpty) current.name = value;
      case 'N':
        if ((current.name ?? '').isEmpty) {
          final parts = value.split(';').map((s) => s.trim()).toList();
          final last = parts.isNotEmpty ? parts[0] : '';
          final first = parts.length > 1 ? parts[1] : '';
          final name = '$first $last'.trim();
          if (name.isNotEmpty) current.name = name;
        }
      case 'BDAY':
        _parseBday(value, current);
      case 'TEL':
        if ((current.phone ?? '').isEmpty && value.isNotEmpty) {
          current.phone = value.replaceFirst(RegExp(r'^tel:', caseSensitive: false), '');
        }
    }
  }
  return result;
}

/// Joins folded lines. QUOTED-PRINTABLE soft breaks (a line ending in `=`)
/// are joined too, since vCard 2.1 encoders split long QP values that way.
List<String> _unfold(String content) {
  final out = <String>[];
  for (final raw in content.split(RegExp(r'\r\n|\r|\n'))) {
    if (out.isNotEmpty && (raw.startsWith(' ') || raw.startsWith('\t'))) {
      out[out.length - 1] += raw.substring(1);
    } else if (out.isNotEmpty &&
        out.last.toUpperCase().contains('QUOTED-PRINTABLE') &&
        out.last.endsWith('=')) {
      out[out.length - 1] = out.last.substring(0, out.last.length - 1) + raw;
    } else {
      out.add(raw);
    }
  }
  return out;
}

String _decodeQuotedPrintable(String s) {
  final bytes = <int>[];
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '=' && i + 3 <= s.length) {
      final hex = int.tryParse(s.substring(i + 1, i + 3), radix: 16);
      if (hex != null) {
        bytes.add(hex);
        i += 2;
        continue;
      }
    }
    if (ch == '=' && i == s.length - 1) continue; // dangling soft break
    bytes.addAll(utf8.encode(ch));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _unescape(String s) => s
    .replaceAll(r'\n', ' ')
    .replaceAll(r'\N', ' ')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');

void _parseBday(String value, VcfContact c) {
  var v = value.trim();
  final t = v.indexOf('T');
  if (t > 0) v = v.substring(0, t); // drop the time part
  final noYear = v.startsWith('--');
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  try {
    if (!noYear && digits.length == 8) {
      final yr = int.parse(digits.substring(0, 4));
      c.month = int.parse(digits.substring(4, 6));
      c.day = int.parse(digits.substring(6, 8));
      c.year = (yr > 1900 && yr <= DateTime.now().year) ? yr : null;
    } else if (digits.length == 4) {
      c.month = int.parse(digits.substring(0, 2));
      c.day = int.parse(digits.substring(2, 4));
      c.year = null;
    }
  } catch (_) {
    // malformed date — leave day/month unset
  }
}
