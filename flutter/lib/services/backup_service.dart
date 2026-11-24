import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';

/// Weekly automatic JSON backup into the phone's public Downloads/Celebria
/// folder (survives uninstalling the app, unlike the app's private data).
///
/// Android has no reliable way to wake a sideloaded app weekly without extra
/// background services, so the check runs each time the app opens: if the
/// last backup is older than 7 days (and there are contacts), it saves one.
/// The native side (MainActivity "com.flet.celebria/backup") writes through
/// MediaStore on Android 10+, so no storage permission is needed.
class BackupService {
  static const _ch = MethodChannel('com.flet.celebria/backup');
  static const fileName = 'Celebria_auto_backup.json';
  static const interval = Duration(days: 7);

  static Future<bool> enabled() async =>
      await AppDb.instance.getSetting('autobackup', '1') == '1';

  static Future<DateTime?> lastBackup() async {
    final ms = int.tryParse(await AppDb.instance.getSetting('autobackup_last', '0')) ?? 0;
    return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Writes the backup now. Returns false if the native write failed.
  static Future<bool> saveNow() async {
    try {
      final json = await AppDb.instance.toJson();
      final where = await _ch.invokeMethod<String>(
          'saveToDownloads', {'name': fileName, 'content': json});
      if (where == null) return false;
      await AppDb.instance.setSetting('autobackup_last', DateTime.now().millisecondsSinceEpoch);
      debugPrint('[Celebria] Auto-backup saved: $where');
      return true;
    } catch (e) {
      debugPrint('[Celebria] Auto-backup failed: $e');
      return false;
    }
  }

  static bool isDue(DateTime? last, DateTime now) =>
      last == null || now.difference(last) >= interval || now.isBefore(last);

  /// Called on app start; silent no-op when disabled, not due, or empty.
  static Future<void> maybeRun() async {
    try {
      if (!await enabled()) return;
      if (!isDue(await lastBackup(), DateTime.now())) return;
      if ((await AppDb.instance.allContacts()).isEmpty) return;
      await saveNow();
    } catch (_) {}
  }
}
