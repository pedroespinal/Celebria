/// Parsed contact extracted from a .vcf file, ready to review/import.
class VcfContact {
  String? name;
  int? day;
  int? month;
  int? year;
  String? phone;
}

/// Hand-rolled vCard parser — ported line-for-line from Python's `_parse_vcf`.
/// Reads FN: (falls back to N: Last;First), BDAY (YYYYMMDD or --MMDD), and the
/// first TEL: found in each vCard block.
List<VcfContact> parseVcf(String content) {
  final result = <VcfContact>[];
  var current = VcfContact();

  for (final rawLine in content.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    final upper = line.toUpperCase();

    if (upper == 'BEGIN:VCARD') {
      current = VcfContact();
    } else if (upper == 'END:VCARD') {
      final d = current.day, m = current.month;
      if (current.name != null &&
          current.name!.isNotEmpty &&
          d != null &&
          m != null &&
          m >= 1 &&
          m <= 12 &&
          d >= 1 &&
          d <= 31) {
        result.add(current);
      }
      current = VcfContact();
    } else if (upper.startsWith('FN:')) {
      final name = line.substring(3).trim();
      if (name.isNotEmpty) current.name = name;
    } else if (upper.startsWith('N:') && (current.name == null || current.name!.isEmpty)) {
      final parts = line.substring(2).split(';').map((s) => s.trim()).toList();
      final first = parts.length > 1 ? parts[1] : '';
      final last = parts.isNotEmpty ? parts[0] : '';
      final name = first.isNotEmpty ? '$first $last'.trim() : last;
      if (name.isNotEmpty) current.name = name;
    } else if (upper.contains('BDAY')) {
      final raw = line
          .split(':')
          .last
          .trim()
          .replaceAll('-', '')
          .replaceAll('/', '');
      try {
        if (raw.length == 8) {
          // YYYYMMDD
          final yr = int.parse(raw.substring(0, 4));
          current.month = int.parse(raw.substring(4, 6));
          current.day = int.parse(raw.substring(6, 8));
          current.year = (yr > 1900 && yr <= DateTime.now().year) ? yr : null;
        } else if (raw.length == 4) {
          // MMDD (from --MMDD with dashes stripped)
          current.month = int.parse(raw.substring(0, 2));
          current.day = int.parse(raw.substring(2, 4));
          current.year = null;
        }
      } catch (_) {
        // malformed date — ignore, leave day/month unset
      }
    } else if (upper.contains('TEL') && (current.phone == null || current.phone!.isEmpty)) {
      final phone = line.split(':').last.trim();
      if (phone.isNotEmpty) current.phone = phone;
    }
  }

  return result;
}
