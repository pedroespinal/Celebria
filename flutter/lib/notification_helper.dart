import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'data/db.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Public entry point called once at app start ─────────────────────────────
  //
  // Each step below is wrapped in its OWN try/catch. Verified on a real
  // device/emulator: requestNotificationsPermission() can throw a
  // PlatformException (null Activity reference) on some cold starts. With a
  // single try/catch around the whole method (the old design), that
  // exception skipped scheduleFromDB() entirely — notifications were
  // silently never scheduled, with no visible error to the user. Isolating
  // each step means a failure in one (permission request, channel creation,
  // whatever) can never prevent scheduling from running.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('[Celebria] Timezone set to: $timeZoneName');
    } catch (tzErr) {
      print('[Celebria] Timezone init failed, using UTC fallback: $tzErr');
    }

    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _notif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('[Celebria] Notification tapped: ${response.id}');
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
      );
    } catch (e) {
      print('[Celebria] _notif.initialize error: $e');
    }

    final androidPlugin = _notif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    try {
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
    } catch (e) {
      print('[Celebria] createNotificationChannel error: $e');
    }

    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      print('[Celebria] requestNotificationsPermission error: $e');
    }

    // Deliberately NOT calling requestExactAlarmsPermission() here.
    // CONFIRMED via direct device testing: that call immediately launches a
    // full-screen "Alarms & reminders" Settings page with ZERO user action —
    // the instant this runs, right after the user grants POST_NOTIFICATIONS,
    // it yanks them out of the app they just opened with no explanation.
    // Exact-alarm permission is opt-in only now, via the native "Enable
    // notifications" dialog in MainActivity.kt (user must explicitly tap
    // "Abrir configuración" there). Without it, _scheduleNotif() already
    // falls back to inexactAllowWhileIdle automatically — notifications
    // still fire, just without the exact-time guarantee.

    await scheduleFromDB();
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotification(NotificationResponse response) {
    print('[Celebria] Background notification tapped: ${response.id}');
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
      // Shared connection (see AppDb.raw doc comment) — this must NEVER be
      // closed here. sqflite caches connections by path (singleInstance
      // defaults to true), so an independent openDatabase() call to this
      // same file used to return AppDb's own connection under the hood;
      // closing it after use broke every other DB call in the app for the
      // rest of the session (confirmed via device testing: Settings screen
      // hung on its loading spinner forever after this ran once).
      final db = await AppDb.instance.raw;

      final lang         = await _getSetting(db, 'lang',               'es');
      final notifDays    = int.tryParse(await _getSetting(db, 'notif_days',   '0')) ?? 0;
      final notifDays2   = int.tryParse(await _getSetting(db, 'notif_days_2', '0')) ?? 0;
      final notifHour    = int.tryParse(await _getSetting(db, 'notif_hour',   '8')) ?? 8;
      final notifMinute  = int.tryParse(await _getSetting(db, 'notif_minute', '0')) ?? 0;
      final alsoOnDay    = (await _getSetting(db, 'notif_also_day_of', '0')) == '1';
      final summaryOn    = (await _getSetting(db, 'notif_monthly_summary', '1')) == '1';

      final contacts = await db.query(
        'contacts',
        columns: ['name', 'day', 'month', 'year'],
      );

      // cancelAll() can throw PlatformException("Missing type parameter")
      // when it tries to load/migrate notifications that were persisted by
      // an older flutter_local_notifications version (e.g. leftover data
      // from before this rewrite, or from any earlier plugin version).
      // That crash must NOT abort the rest of this function — if it did,
      // nothing below would ever get (re)scheduled, silently, forever,
      // since every future call hits the same stuck bad data. Swallow it
      // here and keep going; the zonedSchedule calls below still overwrite
      // notifications by id regardless of whether the old ones were
      // successfully cancelled first.
      try {
        await _notif.cancelAll();
      } catch (e) {
        print('[Celebria] cancelAll() failed (continuing anyway): $e');
      }

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

      print('[Celebria] Scheduled $scheduled birthday notification(s).');
    } catch (e) {
      print('[Celebria] scheduleFromDB error: $e');
    }
    return scheduled;
  }

  // ── Immediate test notification (Settings → "Send test push notification") ─
  // Public: called directly from the Settings screen. Now that everything is
  // Dart (no more Python), there's no need for the old DB-flag-plus-resume
  // polling trick — the UI can just call this straight away.
  static Future<void> fireTestNotification(String lang) async {
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
    final title = lang == 'es' ? '🔔 Notificación de prueba' : '🔔 Test notification';
    final body  = lang == 'es'
        ? 'Si ves esto, las notificaciones de Celebria funcionan correctamente.'
        : 'If you see this, Celebria notifications are working correctly.';
    try {
      await _notif.show(9999, title, body, details);
      print('[Celebria] Test notification fired.');
    } catch (e) {
      print('[Celebria] Test notification failed: $e');
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
      );
    } catch (_) {
      // SCHEDULE_EXACT_ALARM not granted — fall back to inexact
      try {
        await _notif.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        print('[Celebria] Could not schedule notif $id: $e');
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
