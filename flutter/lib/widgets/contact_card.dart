import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/date_utils.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../models/contact.dart';
import 'avatar.dart';

/// One row in the contact list — avatar, name + date, days-left badge.
/// Border accent/badge color escalates: cyan (normal) -> gold (this week)
/// -> pink (today), and gold+thicker if this is a milestone birthday.
class ContactCard extends StatelessWidget {
  final Contact contact;
  final String lang;
  final Palette palette;
  final VoidCallback? onTap;

  const ContactCard({
    super.key,
    required this.contact,
    required this.lang,
    required this.palette,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final dLeft = daysUntil(c.day, c.month);
    final age = calcAge(c.day, c.month, c.year);
    final relColor = palette.byKey(relColorKey[c.relation] ?? 't2');

    final thisYear = DateTime.now().year;
    final ageThisYear = c.year != null ? thisYear - c.year! : null;
    final isMilestone = ageThisYear != null && milestoneAges.contains(ageThisYear);

    Color accent;
    double borderWidth;
    if (dLeft == 0) {
      accent = palette.pink;
      borderWidth = 2;
    } else if (dLeft <= 7) {
      accent = palette.yellow;
      borderWidth = 1;
    } else {
      accent = palette.cyan;
      borderWidth = 1;
    }
    if (isMilestone) {
      accent = palette.yellow;
      borderWidth = 2;
    }

    String badgeText;
    Color badgeColor;
    if (dLeft == 0) {
      badgeText = '🎉\n${t(lang, 'today_badge')}';
      badgeColor = palette.pink;
    } else if (dLeft == 1) {
      badgeText = '🌅\n${t(lang, 'tomorrow_badge')}';
      badgeColor = palette.yellow;
    } else {
      badgeText = '$dLeft\n${t(lang, 'days_left')}';
      badgeColor = accent;
    }
    if (isMilestone) badgeText = '$badgeText\n✨';

    var dateStr = '${c.day} ${monthName(lang, c.month)}';
    if (c.year != null) dateStr += ' ${c.year}';
    if (age != null) dateStr += '  •  $age ${t(lang, 'years')}';

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: borderWidth),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ContactAvatar(
                photo: c.photo,
                name: c.name,
                relation: c.relation,
                palette: palette,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: relColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(dateStr, style: TextStyle(fontSize: 11, color: palette.t3)),
                  ],
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
