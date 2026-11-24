/// Mirrors the `contacts` table — byte-compatible with the original
/// SQLite schema so an existing install's data migrates with zero loss.
class Contact {
  final int id;
  final String name;
  final int day;
  final int month;
  final int? year;
  final String phone;
  final String email;
  final String notes;
  final String relation; // family | friend | work | other
  final String photo; // absolute file path, '' if none
  final String giftNote;
  /// birthday | anniversary | other  (column added in v1.10.0; rows from
  /// older versions get the column default 'birthday').
  final String kind;

  const Contact({
    required this.id,
    required this.name,
    required this.day,
    required this.month,
    this.year,
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.relation = 'friend',
    this.photo = '',
    this.giftNote = '',
    this.kind = 'birthday',
  });

  bool get isBirthday => kind == 'birthday';

  factory Contact.fromMap(Map<String, Object?> m) => Contact(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        day: m['day'] as int? ?? 0,
        month: m['month'] as int? ?? 0,
        year: m['year'] as int?,
        phone: m['phone'] as String? ?? '',
        email: m['email'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        relation: m['relation'] as String? ?? 'friend',
        photo: m['photo'] as String? ?? '',
        giftNote: m['gift_note'] as String? ?? '',
        kind: normalizeKind(m['kind'] as String?),
      );

  Map<String, Object?> toMap({bool includeId = true}) => {
        if (includeId) 'id': id,
        'name': name,
        'day': day,
        'month': month,
        'year': year,
        'phone': phone,
        'email': email,
        'notes': notes,
        'relation': relation,
        'photo': photo,
        'gift_note': giftNote,
        'kind': kind,
      };

  Contact copyWith({
    String? name,
    int? day,
    int? month,
    int? year,
    bool clearYear = false,
    String? phone,
    String? email,
    String? notes,
    String? relation,
    String? photo,
    String? giftNote,
    String? kind,
  }) =>
      Contact(
        id: id,
        name: name ?? this.name,
        day: day ?? this.day,
        month: month ?? this.month,
        year: clearYear ? null : (year ?? this.year),
        phone: phone ?? this.phone,
        email: email ?? this.email,
        notes: notes ?? this.notes,
        relation: relation ?? this.relation,
        photo: photo ?? this.photo,
        giftNote: giftNote ?? this.giftNote,
        kind: kind ?? this.kind,
      );
}

const List<String> contactKinds = ['birthday', 'anniversary', 'other'];

String normalizeKind(String? k) => contactKinds.contains(k) ? k! : 'birthday';

String kindIcon(String kind) => switch (kind) {
      'anniversary' => '💍',
      'other' => '⭐',
      _ => '🎂',
    };
