import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../models/contact.dart';

/// SQLite wrapper — schema kept byte-identical to the original Python `class DB`
/// so an existing install's `celebria.db` (also read directly by
/// notification_helper.dart / BirthdayWidget.kt / MainActivity.kt) keeps working
/// with zero migration needed. Same path convention
/// (ApplicationDocumentsDirectory/celebria.db) the Dart notification layer
/// already uses — this is the single source of truth for the DB location.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  /// Shared raw connection — used by notification_helper.dart so it queries
  /// through the SAME sqflite instance as the rest of the app instead of
  /// opening its own. sqflite caches connections by path (singleInstance
  /// defaults to true), so a second independent openDatabase() call to this
  /// same file returns the *same* underlying connection — closing that
  /// "second" handle after use was closing this one too, breaking every
  /// other DB call in the app for the rest of the session. Never call
  /// .close() on what this getter returns; AppDb owns its lifecycle.
  Future<Database> get raw async => _database;

  Future<Database> _open() async {
    final docsDir = await path_provider.getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'celebria.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS contacts (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            name      TEXT    NOT NULL,
            day       INTEGER NOT NULL,
            month     INTEGER NOT NULL,
            year      INTEGER,
            phone     TEXT    DEFAULT '',
            email     TEXT    DEFAULT '',
            notes     TEXT    DEFAULT '',
            relation  TEXT    DEFAULT 'friend',
            photo     TEXT    DEFAULT '',
            gift_note TEXT    DEFAULT '',
            kind      TEXT    DEFAULT 'birthday'
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      // Additive, idempotent migration run on every open: only ADDs a
      // column when it's missing, never touches existing rows/columns, so
      // any older install (even the original Python-era DB) upgrades safely
      // and BirthdayWidget.kt / MainActivity.kt keep reading the same file.
      onOpen: (db) async {
        final cols = (await db.rawQuery('PRAGMA table_info(contacts)'))
            .map((r) => r['name'] as String)
            .toSet();
        if (!cols.contains('photo')) {
          await db.execute("ALTER TABLE contacts ADD COLUMN photo TEXT DEFAULT ''");
        }
        if (!cols.contains('gift_note')) {
          await db.execute("ALTER TABLE contacts ADD COLUMN gift_note TEXT DEFAULT ''");
        }
        if (!cols.contains('kind')) {
          await db.execute("ALTER TABLE contacts ADD COLUMN kind TEXT DEFAULT 'birthday'");
        }
      },
    );
  }

  // ── Settings key/value store ─────────────────────────────────────────────
  Future<String> getSetting(String key, [String fallback = '']) async {
    final db = await _database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String? ?? fallback;
  }

  Future<void> setSetting(String key, Object value) async {
    final db = await _database;
    await db.insert(
      'settings',
      {'key': key, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Contacts ──────────────────────────────────────────────────────────────
  Future<List<Contact>> allContacts() async {
    final db = await _database;
    final rows = await db.query('contacts', orderBy: 'month, day, name');
    return rows.map(Contact.fromMap).toList();
  }

  Future<Contact?> getContact(int id) async {
    final db = await _database;
    final rows = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Contact.fromMap(rows.first);
  }

  Future<int> addContact(Contact c) async {
    final db = await _database;
    return db.insert('contacts', c.toMap(includeId: false));
  }

  Future<void> updateContact(Contact c) async {
    final db = await _database;
    await db.update('contacts', c.toMap(includeId: false),
        where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteContact(int id) async {
    final db = await _database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // ── Export / import JSON ────────────────────────────────────────────────
  Future<String> toJson() async {
    final contacts = await allContacts();
    final data = contacts
        .map((c) => {
              'name': c.name,
              'day': c.day,
              'month': c.month,
              'year': c.year,
              'phone': c.phone,
              'email': c.email,
              'notes': c.notes,
              'relation': c.relation,
              'gift_note': c.giftNote,
              'kind': c.kind,
            })
        .toList();
    return const JsonEncoder.withIndent('  ')
        .convert({'app': appName, 'version': appVersion, 'contacts': data});
  }

  /// Parses a Celebria JSON backup and imports it via [importContacts].
  /// Returns (imported, skipped), or null if the file isn't a valid backup.
  Future<(int, int)?> fromJson(String txt) async {
    final List<Contact> parsed = [];
    try {
      final obj = jsonDecode(txt);
      final List items = obj is List ? obj : (obj['contacts'] as List? ?? []);
      for (final raw in items) {
        if (raw is! Map) continue;
        final c = raw.cast<String, dynamic>();
        String str(String k) => (c[k] ?? '').toString().trim();
        int? num_(String k) => c[k] is num ? (c[k] as num).toInt() : int.tryParse(str(k));
        final rel = str('relation');
        parsed.add(Contact(
          id: 0,
          name: str('name'),
          day: num_('day') ?? 0,
          month: num_('month') ?? 0,
          year: num_('year'),
          phone: str('phone'),
          email: str('email'),
          notes: str('notes'),
          relation: const {'family', 'friend', 'work', 'other'}.contains(rel) ? rel : 'friend',
          giftNote: str('gift_note'),
          kind: normalizeKind(str('kind')),
        ));
      }
    } catch (_) {
      return null;
    }
    return importContacts(parsed);
  }

  /// Inserts contacts in ONE transaction (all-or-nothing, and much faster
  /// than one commit per row), skipping rows with no name or an impossible
  /// date and rows that already exist (same name — case/accent-insensitive
  /// — and same day/month). Importing the same backup or .vcf twice used to
  /// duplicate every contact, which also doubled every notification.
  /// Returns (imported, skipped).
  Future<(int, int)> importContacts(List<Contact> items) async {
    final db = await _database;
    var added = 0, skipped = 0;
    await db.transaction((txn) async {
      final existing = <String>{
        for (final r in await txn.query('contacts', columns: ['name', 'day', 'month', 'kind']))
          _dupKey(r['name'] as String? ?? '', r['day'] as int? ?? 0, r['month'] as int? ?? 0,
              normalizeKind(r['kind'] as String?)),
      };
      for (final c in items) {
        final name = c.name.trim();
        final validDate = c.month >= 1 && c.month <= 12 && c.day >= 1 &&
            c.day <= DateTime(2024, c.month + 1, 0).day;
        final key = _dupKey(name, c.day, c.month, c.kind);
        if (name.isEmpty || !validDate || existing.contains(key)) {
          skipped++;
          continue;
        }
        final year = (c.year != null && c.year! > 1900 && c.year! <= DateTime.now().year) ? c.year : null;
        await txn.insert('contacts', c.copyWith(name: name, year: year, clearYear: year == null)
            .toMap(includeId: false));
        existing.add(key);
        added++;
      }
    });
    return (added, skipped);
  }

  static String _dupKey(String name, int day, int month, String kind) =>
      '${normalizeForSearch(name.trim())}|$day|$month|$kind';

  // ── Photo storage ────────────────────────────────────────────────────────
  /// Copies a picked image into the app's data dir and returns the new path.
  Future<String> copyPhoto(String srcPath) async {
    try {
      final docsDir = await path_provider.getApplicationDocumentsDirectory();
      final photosDir = Directory(p.join(docsDir.path, 'photos'));
      await photosDir.create(recursive: true);
      final ext = p.extension(srcPath).isEmpty ? '.jpg' : p.extension(srcPath);
      final dest = p.join(
          photosDir.path, 'p_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(srcPath).copy(dest);
      return dest;
    } catch (_) {
      return srcPath;
    }
  }

  /// Deletes a photo file, but only one this app copied into its own
  /// `photos/` folder — never a file elsewhere on the device.
  Future<void> deleteOwnedPhoto(String path) async {
    if (path.isEmpty) return;
    try {
      final docsDir = await path_provider.getApplicationDocumentsDirectory();
      final photosDir = p.join(docsDir.path, 'photos');
      if (p.isWithin(photosDir, path)) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }
}

/// Lower-case and strip Spanish/Latin accents so "jose" finds "José" and
/// "MARÍA" equals "maria" when detecting duplicates.
String normalizeForSearch(String s) {
  const from = 'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const to   = 'aaaaaaeeeeiiiiooooouuuuncaaaaaaeeeeiiiiooooouuuunc';
  final sb = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb.toString();
}
