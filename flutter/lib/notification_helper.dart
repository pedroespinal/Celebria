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
  static int _lastHandledTestTrigger = 0;

  // ── Public entry point called once at app start ─────────────────────────────
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
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
          debugPrint('[Celebria] Notification tapped: ${response.id}');
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
      );

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

      await androidPlugin?.requestNotificationsPermission();

      // Request exact alarm permission (Android 12+).
      // Opens system settings once so the user can grant it; if already
      // granted this is a no-op.
      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {}

      await scheduleFromDB();
    } catch (e) {
      debugPrint('[Celebria] NotificationHelper.initialize error: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationResponse response) {
    debugPrint('[Celebria] Background notification tapped: ${response.id}');
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _notif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Schedule all notifications ───────────────────────────────────────────────
  //
  // Per-contact slots (IDs 3000+):
  //   • N days before birthday (advance notice) — current + next year
  //   • Day-of notice (if notif_also_day_of == "1" and notifDays > 0)
  //   • Second advance notice at notif_days_2 (if configured and ≠ notifDays)
  //
  // Monthly summary slots (IDs 2000–2023):
  //   • On the 1st of each month that has birthday contacts — for next 2 years
  //
  // Uses exactAllowWhileIdle for reliability; falls back to inexact if the
  // SCHEDULE_EXACT_ALARM permission is not granted.
  static Future<int> scheduleFromDB() async {
    int scheduled = 0;
    try {
      final docsDir = await path_provider.getApplicationDocumentsDirectory();
      final dbPath = path_pkg.join(docsDir.path, 'celebria.db');
      if (!File(dbPath).existsSync()) return 0;

      final db = await openDatabase(dbPath, readOnly: true);

      final lang         = await _getSetting(db, 'lang',               'es');
      final notifDays    = int.tryParse(await _getSetting(db, 'notif_days',   '0')) ?? 0;
      final notifDays2   = int.tryParse(await _getSetting(db, 'notif_days_2', '0')) ?? 0;
      final notifHour    = int.tryParse(await _getSetting(db, 'notif_hour',   '8')) ?? 8;
      final notifMinute  = int.tryParse(await _getSetting(db, 'notif_minute', '0')) ?? 0;
      final alsoOnDay    = (await _getSetting(db, 'notif_also_day_of', '0')) == '1';
      final summaryOn    = (await _getSetting(db, 'notif_monthly_summary', '1')) == '1';
      final testTrigger  = int.tryParse(await _getSetting(db, 'notif_test_trigger', '0')) ?? 0;

      final contacts = await db.query(
        'contacts',
        columns: ['name', 'day', 'month', 'year'],
      );
      await db.close();

      // "Send test notification" button in Settings — fires immediately so
      // we can tell whether Android will display ANY notification for this
      // app at all, independent of scheduling/timing. Deduped in-memory so
      // it only fires once per button tap even if this runs again soon.
      if (testTrigger > 0 && testTrigger != _lastHandledTestTrigger) {
        final ageMs = DateTime.now().millisecondsSinceEpoch - testTrigger;
        if (ageMs >= 0 && ageMs < 120000) {
          _lastHandledTestTrigger = testTrigger;
          await _fireTestNotification(lang);
        }
      }

      await _notif.cancelAll();

      final now    = DateTime.now();
      final cutoff = now.add(const Duration(minutes: 1));
      int notifId  = 3000;

      // ── Per-contact notifications ──────────────────────────────────────
      for (final row in contacts) {
        final name      = (row['name']  as String?) ?? '';
        final day       = (row['day']   as int?)    ?? 0;
        final month     = (row['month'] as int?)    ?? 0;
        final birthYear = (row['year']  as int?);

        if (day == 0 || month == 0 || name.isEmpty) continue;

        final List<_NotifSlot> slots = [];

        for (int yearOffset = 0; yearOffset <= 1; yearOffset++) {
          DateTime birthday;
          try {
            birthday = DateTime(now.year + yearOffset, month, day);
          } catch (_) {
            continue;
          }

          // ── Primary advance notice ────────────────────────────────────
          final notifDay  = birthday.subtract(Duration(days: notifDays));
          final candidate = DateTime(
              notifDay.year, notifDay.month, notifDay.day,
              notifHour, notifMinute, 0);
          if (candidate.isAfter(cutoff)) {
            slots.add(_NotifSlot(candidate, birthday, notifDays));
          }

          // ── Day-of notice (only when advance > 0 and enabled) ────────
          if (alsoOnDay && notifDays > 0) {
            final dayOf = DateTime(
                birthday.year, birthday.month, birthday.day,
                notifHour, notifMinute, 0);
            if (dayOf.isAfter(cutoff)) {
              slots.add(_NotifSlot(dayOf, birthday, 0));
            }
          }

          // ── Second advance notice (if different from primary) ─────────
          if (notifDays2 > 0 && notifDays2 != notifDays) {
            final notifDay2  = birthday.subtract(Duration(days: notifDays2));
            final candidate2 = DateTime(
                notifDay2.year, notifDay2.month, notifDay2.day,
                notifHour, notifMinute, 0);
            if (candidate2.isAfter(cutoff)) {
              slots.add(_NotifSlot(candidate2, birthday, notifDays2));
            }
          }
        }

        for (final slot in slots) {
          int? age;
          if (birthYear != null && birthYear > 0) {
            age = slot.birthday.year - birthYear;
            if (age < 0) age = null;
          }

          final isMilestone = age != null && _isMilestoneAge(age);
          final title = _buildTitle(name, age, slot.daysLabel, lang, isMilestone);
          final body  = slot.daysLabel == 0
              ? (isMilestone
                  ? (lang == 'es'
                      ? '¡Un día muy especial! Abre Celebria para celebrar 🎊'
                      : 'A very special day! Open Celebria to celebrate 🎊')
                  : (lang == 'es'
                      ? 'Abre Celebria para celebrar 🎉'
                      : 'Open Celebria to celebrate 🎉'))
              : (lang == 'es'
                  ? 'Prepara tu felicitación con tiempo 😊'
                  : 'Prepare your wishes in advance 😊');

          await _scheduleNotif(
            notifId++, title, body,
            tz.TZDateTime.from(slot.notifDt, tz.local),
          );
          scheduled++;
        }
      }

      // ── Monthly summary notifications (IDs 2000–2023) ─────────────────
      if (summaryOn && contacts.isNotEmpty) {
        // Build map month → list of names
        final Map<int, List<String>> byMonth = {};
        for (final row in contacts) {
          final name  = (row['name']  as String?) ?? '';
          final month = (row['month'] as int?)    ?? 0;
          if (month == 0 || name.isEmpty) continue;
          byMonth.putIfAbsent(month, () => []).add(name);
        }

        int summaryId = 2000;
        for (int yearOffset = 0; yearOffset <= 1; yearOffset++) {
          for (int m = 1; m <= 12; m++) {
            final names = byMonth[m];
            if (names == null || names.isEmpty) continue;

            final firstOfMonth = DateTime(now.year + yearOffset, m, 1,
                notifHour, notifMinute, 0);
            if (!firstOfMonth.isAfter(cutoff)) continue;

            final monthName = _monthName(m, lang);
            final count     = names.length;
            final preview   = names.length <= 3
                ? names.join(', ')
                : '${names.take(3).join(', ')} +${names.length - 3}';

            final title = lang == 'es'
                ? '📅 $monthName tiene $count cumpleaños'
                : '📅 $monthName has $count birthday${count == 1 ? '' : 's'}';
            final body = preview;

            await _scheduleNotif(
              summaryId++, title, body,
              tz.TZDateTime.from(firstOfMonth, tz.local),
            );
            scheduled++;
          }
        }
      }

      debugPrint('[Celebria] Scheduled $scheduled birthday notification(s).');
    } catch (e) {
      debugPrint('[Celebria] scheduleFromDB error: $e');
    }
    return scheduled;
  }

  // ── Immediate test notification (Settings → "Send test push notification") ─
  static Future<void> _fireTestNotification(String lang) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'celebria_birthdays',
        'Birthday Reminders',
        channelDescription: 'Daily birthday reminders from Celebria',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
      ),
    );
    final title = lang == 'es' ? '\U0001f514 Notificación de prueba' : '\U0001f514 Test notification';
    final body  = lang == 'es'
        ? 'Si ves esto, las notificaciones de Celebria funcionan correctamente.'
        : 'If you see this, Celebria notifications are working correctly.';
    try {
      await _notif.show(9999, title, body, details);
      debugPrint('[Celebria] Test notification fired.');
    } catch (e) {
      debugPrint('[Celebria] Test notification failed: $e');
    }
  }

  // ── Schedule a single notification with exact alarm fallback ────────────────
  static Future<void> _scheduleNotif(
      int id, String title, String body, tz.TZDateTime when) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'celebria_birthdays',
        'Birthday Reminders',
        channelDescription: 'Daily birthday reminders from Celebria',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
      ),
    );
    try {
      await _notif.zonedSchedule(
        id, title, body, when, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // SCHEDULE_EXACT_ALARM not granted — fall back to inexact
      try {
        await _notif.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('[Celebria] Could not schedule notif $id: $e');
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool _isMilestoneAge(int age) {
    const milestones = {15, 18, 21, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100};
    return milestones.contains(age);
  }

  static String _buildTitle(
      String name, int? age, int daysLabel, String lang, bool isMilestone) {
    final emoji = isMilestone ? '🎊' : '🎂';
    if (lang == 'es') {
      if (daysLabel == 0) {
        return age != null
            ? '$emoji ¡$name cumple $age años HOY!'
            : '$emoji ¡$name cumple años HOY!';
      } else {
        return age != null
            ? '$emoji $name cumple $age años en $daysLabel día(s)'
            : '$emoji $name cumple años en $daysLabel día(s)';
      }
    } else {
      if (daysLabel == 0) {
        return age != null
            ? '$emoji $name turns $age TODAY!'
            : "$emoji $name's birthday is TODAY!";
      } else {
        return age != null
            ? '$emoji $name turns $age in $daysLabel day(s)'
            : "$emoji $name's birthday in $daysLabel day(s)";
      }
    }
  }

  static String _monthName(int month, String lang) {
    const es = ['', 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                 'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    const en = ['', 'January','February','March','April','May','June',
                 'July','August','September','October','November','December'];
    return lang == 'es' ? es[month] : en[month];
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

// Data class for a scheduled notification slot
class _NotifSlot {
  final DateTime notifDt;
  final DateTime birthday;
  final int daysLabel; // 0 = day-of, N = N days before
  const _NotifSlot(this.notifDt, this.birthday, this.daysLabel);
}
