import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Public entry point called once at app start ─────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      tz_data.initializeTimeZones();

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _notif.initialize(initSettings);

      // Create the notification channel (Android 8+)
      final androidPlugin = _notif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'celebria_birthdays',
          'Birthday Reminders',
          description: 'Daily birthday reminders from Celebria',
          importance: Importance.high,
        ),
      );

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      await scheduleFromDB();
    } catch (e) {
      debugPrint('[Celebria] NotificationHelper.initialize error: $e');
    }
  }

  // ── Schedule one notification per upcoming birthday (next 365 days) ─────────
  static Future<void> scheduleFromDB() async {
    try {
      final docsDir = await path_provider.getApplicationDocumentsDirectory();
      final dbPath = path_pkg.join(docsDir.path, 'celebria.db');
      if (!File(dbPath).existsSync()) return;

      final db = await openDatabase(dbPath, readOnly: true);

      final lang = await _getSetting(db, 'lang', 'es');
      final notifDays =
          int.tryParse(await _getSetting(db, 'notif_days', '0')) ?? 0;
      final notifHour =
          int.tryParse(await _getSetting(db, 'notif_hour', '8')) ?? 8;

      final contacts = await db.query(
        'contacts',
        columns: ['name', 'day', 'month', 'year'],
      );
      await db.close();

      // Cancel everything previously scheduled
      await _notif.cancelAll();

      final now = DateTime.now();
      int notifId = 3000; // base ID for birthday notifications

      for (final row in contacts) {
        final name = (row['name'] as String?) ?? '';
        final day = (row['day'] as int?) ?? 0;
        final month = (row['month'] as int?) ?? 0;
        final birthYear = (row['year'] as int?);

        if (day == 0 || month == 0 || name.isEmpty) continue;

        // Notification fires `notifDays` days BEFORE the birthday
        final notifDt =
            _nextNotifDateTime(day, month, notifDays, notifHour, now);
        if (notifDt == null) continue;

        // Age the person will turn on their birthday
        int? age;
        if (birthYear != null && birthYear > 0) {
          // birthday date = notifDt + notifDays days
          final birthdayDt = notifDt.add(Duration(days: notifDays));
          age = birthdayDt.year - birthYear;
          if (age < 0) age = null;
        }

        final title = _buildTitle(name, age, notifDays, lang);
        final body = notifDays == 0
            ? (lang == 'es'
                ? 'Abre Celebria para celebrar 🎉'
                : 'Open Celebria to celebrate 🎉')
            : (lang == 'es'
                ? 'Prepara tu felicitación con tiempo 😊'
                : 'Prepare your wishes in advance 😊');

        await _notif.zonedSchedule(
          notifId++,
          title,
          body,
          tz.TZDateTime.from(notifDt, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'celebria_birthdays',
              'Birthday Reminders',
              channelDescription: 'Daily birthday reminders from Celebria',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          // inexactAllowWhileIdle: no SCHEDULE_EXACT_ALARM permission needed;
          // fires within ~1 hour of target time even in Doze mode — fine for birthdays.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      debugPrint(
          '[Celebria] Scheduled ${notifId - 3000} birthday notification(s).');
    } catch (e) {
      debugPrint('[Celebria] scheduleFromDB error: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _buildTitle(
      String name, int? age, int notifDays, String lang) {
    if (lang == 'es') {
      if (notifDays == 0) {
        return age != null
            ? '🎂 ¡$name cumple $age años HOY!'
            : '🎂 ¡$name cumple años HOY!';
      } else {
        return age != null
            ? '🎂 $name cumple $age años en $notifDays día(s)'
            : '🎂 $name cumple años en $notifDays día(s)';
      }
    } else {
      if (notifDays == 0) {
        return age != null
            ? '🎂 $name turns $age TODAY!'
            : "🎂 $name's birthday is TODAY!";
      } else {
        return age != null
            ? '🎂 $name turns $age in $notifDays day(s)'
            : "🎂 $name's birthday in $notifDays day(s)";
      }
    }
  }

  // Returns the DateTime when the notification should fire, or null if no
  // upcoming occurrence within the next 365 days (+1 year fallback).
  static DateTime? _nextNotifDateTime(
      int day, int month, int notifDays, int hour, DateTime now) {
    for (int offset = 0; offset <= 1; offset++) {
      try {
        final birthday = DateTime(now.year + offset, month, day);
        final candidate = DateTime(
          birthday.subtract(Duration(days: notifDays)).year,
          birthday.subtract(Duration(days: notifDays)).month,
          birthday.subtract(Duration(days: notifDays)).day,
          hour,
          0,
          0,
        );
        // Must be strictly in the future (> 1 min from now)
        if (candidate.isAfter(now.add(const Duration(minutes: 1)))) {
          return candidate;
        }
      } catch (_) {
        // Invalid date (e.g. Feb 29 in non-leap year) — skip
      }
    }
    return null;
  }

  static Future<String> _getSetting(
      Database db, String key, String defaultValue) async {
    try {
      final rows =
          await db.query('settings', where: 'key = ?', whereArgs: [key]);
      return rows.isNotEmpty
          ? (rows.first['value'] as String? ?? defaultValue)
          : defaultValue;
    } catch (_) {
      return defaultValue;
    }
  }
}
