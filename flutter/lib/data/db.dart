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
            gift_note TEXT    DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
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
            })
        .toList();
    return const JsonEncoder.withIndent('  ')
        .convert({'app': appName, 'version': appVersion, 'contacts': data});
  }

  /// Returns number of contacts imported, or -1 on parse failure.
  Future<int> fromJson(String txt) async {
    try {
      final obj = jsonDecode(txt);
      final List items = obj is List ? obj : (obj['contacts'] as List? ?? []);
      for (final raw in items) {
        final c = raw as Map<String, dynamic>;
        await addContact(Contact(
          id: 0,
          name: c['name'] as String? ?? '?',
          day: (c['day'] as num?)?.toInt() ?? 1,
          month: (c['month'] as num?)?.toInt() ?? 1,
          year: (c['year'] as num?)?.toInt(),
          phone: c['phone'] as String? ?? '',
          email: c['email'] as String? ?? '',
          notes: c['notes'] as String? ?? '',
          relation: c['relation'] as String? ?? 'friend',
          giftNote: c['gift_note'] as String? ?? '',
        ));
      }
      return items.length;
    } catch (_) {
      return -1;
    }
  }

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
}
