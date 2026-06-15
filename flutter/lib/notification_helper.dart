import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
      // Load timezone database and set device local timezone
      tz_data.initializeTimeZones();
      try {
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('[Celebria] Timezone set to: $timeZoneName');
      } catch (tzErr) {
        debugPrint('[Celebria] Timezone init failed, using UTC fallback: $tzErr');
      }

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _notif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Notification tapped while app is open — no-op for now
          debugPrint('[Celebria] Notification tapped: ${response.id}');
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
      );

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
          enableVibration: true,
          playSound: true,
        ),
      );

      // Request POST_NOTIFICATIONS permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      await scheduleFromDB();
    } catch (e) {
      debugPrint('[Celebria] NotificationHelper.initialize error: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationResponse response) {
    debugPrint('[Celebria] Background notification tapped: ${response.id}');
  }

  // ── Returns whether notifications permission is granted ──────────────────────
  static Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _notif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidPlugin?.areNotificationsEnabled() ?? false;
      return granted;
    } catch (_) {
      return false;
    }
  }

  // ── Schedule one notification per upcoming birthday (next 365 days) ─────────
  static Future<int> scheduleFromDB() async {
    int scheduled = 0;
    try {
      final docsDir = await path_provider.getApplicationDocumentsDirectory();
      final dbPath = path_pkg.join(docsDir.path, 'celebria.db');
      if (!File(dbPath).existsSync()) return 0;

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
      int notifId = 3000;

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

        final tzNotifDt = tz.TZDateTime.from(notifDt, tz.local);

        await _notif.zonedSchedule(
          notifId++,
          title,
          body,
          tzNotifDt,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'celebria_birthdays',
              'Birthday Reminders',
              channelDescription: 'Daily birthday reminders from Celebria',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              enableVibration: true,
            ),
          ),
          // inexactAllowWhileIdle: fires within ~1 hour even in Doze mode.
          // Does not require SCHEDULE_EXACT_ALARM permission.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        scheduled++;
      }

      debugPrint('[Celebria] Scheduled $scheduled birthday notification(s).');
    } catch (e) {
      debugPrint('[Celebria] scheduleFromDB error: $e');
    }
    return scheduled;
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

  // Returns the next DateTime when the notification should fire, or null if
  // there is no upcoming occurrence within the next 2 years.
  static DateTime? _nextNotifDateTime(
      int day, int month, int notifDays, int hour, DateTime now) {
    for (int offset = 0; offset <= 1; offset++) {
      try {
        final birthday = DateTime(now.year + offset, month, day);
        final notifDay = birthday.subtract(Duration(days: notifDays));
        final candidate = DateTime(
          notifDay.year,
          notifDay.month,
          notifDay.day,
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
