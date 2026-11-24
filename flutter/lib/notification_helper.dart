import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/constants.dart';
import 'core/date_utils.dart';
import 'models/contact.dart';
import 'data/db.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final Completer<void> _pluginReady = Completer<void>();

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
      debugPrint('[Celebria] Timezone set to: $timeZoneName');
    } catch (tzErr) {
      debugPrint('[Celebria] Timezone init failed, using UTC fallback: $tzErr');
    }

    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _notif.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[Celebria] Notification tapped: ${response.payload}');
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          // On a cold start this can fire before the UI has registered
          // onTap — keep it for launchPayload() instead of dropping it.
          if (onTap != null) {
            onTap!(payload);
          } else {
            _pendingPayload = payload;
          }
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotification,
      );
    } catch (e) {
      debugPrint('[Celebria] _notif.initialize error: $e');
    }
    if (!_pluginReady.isCompleted) _pluginReady.complete();

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
      debugPrint('[Celebria] createNotificationChannel error: $e');
    }

    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[Celebria] requestNotificationsPermission error: $e');
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
    debugPrint('[Celebria] Background notification tapped: ${response.id}');
  }

  /// Set by main.dart: opens the contact a tapped notification is about.
  /// Payloads: `contact:<id>` (per-contact reminders) or `month:<m>`.
  static void Function(String payload)? onTap;
  static String? _pendingPayload;

  /// Payload of the notification that cold-started the app, if any (the
  /// in-app callback above only fires when the app is already running).
  static Future<String?> launchPayload() async {
    try {
      // main() initializes the plugin after the first frame; wait for it.
      await _pluginReady.future.timeout(const Duration(seconds: 5));
      final pending = _pendingPayload;
      _pendingPayload = null;
      if (pending != null) return pending;
      final d = await _notif.getNotificationAppLaunchDetails();
      debugPrint('[Celebria] launch details: launched=${d?.didNotificationLaunchApp} '
          'payload=${d?.notificationResponse?.payload}');
      if (d?.didNotificationLaunchApp ?? false) return d!.notificationResponse?.payload;
    } catch (e) {
      debugPrint('[Celebria] launchPayload error: $e');
    }
    return null;
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
  // Builds the full plan (see [buildPlan]) and hands it to AlarmManager.
  //
  // Calls are serialized: every contact/settings change fires this without
  // awaiting it, and two overlapping runs used to interleave their
  // cancelAll()/zonedSchedule() calls, so the newest settings could be wiped
  // by an older run that finished later.
  static Future<void> _chain = Future.value();

  static Future<int> scheduleFromDB() {
    final run = _chain.then((_) => _scheduleFromDBImpl());
    _chain = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<int> _scheduleFromDBImpl() async {
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

      final settings = NotifSettings(
        lang:           await _getSetting(db, 'lang', 'es'),
        notifDays:      int.tryParse(await _getSetting(db, 'notif_days',   '0')) ?? 0,
        notifDays2:     int.tryParse(await _getSetting(db, 'notif_days_2', '0')) ?? 0,
        hour:           int.tryParse(await _getSetting(db, 'notif_hour',   '8')) ?? 8,
        minute:         int.tryParse(await _getSetting(db, 'notif_minute', '0')) ?? 0,
        alsoOnDay:      (await _getSetting(db, 'notif_also_day_of', '0')) == '1',
        monthlySummary: (await _getSetting(db, 'notif_monthly_summary', '1')) == '1',
        remindAllDay:   (await _getSetting(db, 'remind_all_day', '0')) == '1',
        remindInterval: int.tryParse(await _getSetting(db, 'remind_all_day_interval', '120')) ?? 120,
      );

      final contacts = await db.query(
        'contacts',
        columns: ['id', 'name', 'day', 'month', 'year', 'kind', 'gift_note'],
      );

      // cancelAll() can throw PlatformException("Missing type parameter")
      // when it tries to load/migrate notifications that were persisted by
      // an older flutter_local_notifications version. That crash must NOT
      // abort the rest of this function — the zonedSchedule calls below
      // still overwrite notifications by id regardless.
      try {
        await _notif.cancelAll();
      } catch (e) {
        debugPrint('[Celebria] cancelAll() failed (continuing anyway): $e');
      }

      final plan = buildPlan(contacts, settings, DateTime.now());
      for (final n in plan) {
        await _scheduleNotif(n.id, n.title, n.body, tz.TZDateTime.from(n.when, tz.local),
            payload: n.payload);
        scheduled++;
      }
      debugPrint('[Celebria] Scheduled $scheduled notification(s).');
    } catch (e) {
      debugPrint('[Celebria] scheduleFromDB error: $e');
    }
    await _refreshHomeWidget();
    return scheduled;
  }

  /// Asks the native side to redraw the home-screen widget so it reflects a
  /// contact that was just added/edited/deleted (or a language change)
  /// right away instead of up to 30 min later. In the headless boot engine
  /// the channel isn't registered — MissingPluginException is expected there.
  static Future<void> _refreshHomeWidget() async {
    try {
      await const MethodChannel('com.flet.celebria/widget').invokeMethod('refresh');
    } catch (_) {}
  }

  /// Android's AlarmManager refuses more than 500 pending alarms per app
  /// ("Maximum limit of concurrent alarms 500 reached") and every scheduled
  /// notification is one alarm. The old code scheduled per contact in DB
  /// order, so with ~80 contacts (or a handful with "remind all day" every
  /// 30 min) everything past the limit silently failed — whole contacts got
  /// no reminder at all. The plan is now sorted by time and capped well
  /// below the limit, so the nearest reminders always win; the far-future
  /// tail is filled in on later runs (every app open, every change, boot).
  static const int maxScheduled = 400;

  /// Pure, testable: every notification that should be pending at [now],
  /// sorted by time, capped at [maxScheduled], with ids assigned 1000+.
  ///
  /// Per contact, for this year's and next year's birthday:
  ///   • N days before (notif_days; N == 0 means on the day itself)
  ///   • Day-of notice (notif_also_day_of, when N > 0)
  ///   • Second advance notice (notif_days_2, when set and ≠ N)
  ///   • "Remind all day" (remind_all_day): a day-of notice plus repeats every
  ///     `remind_all_day_interval` minutes until 23:59 — independent of the
  ///     advance-notice settings (it used to silently do nothing unless the
  ///     day-of notice happened to be enabled too).
  /// Plus a monthly summary on the 1st of each month that has birthdays.
  @visibleForTesting
  static List<PlannedNotif> buildPlan(
      List<Map<String, Object?>> contacts, NotifSettings s, DateTime now) {
    final cutoff = now.add(const Duration(minutes: 1));
    final out = <PlannedNotif>[];
    final es = s.lang == 'es';

    DateTime at(DateTime d, [int addMinutes = 0]) =>
        DateTime(d.year, d.month, d.day, s.hour, s.minute + addMinutes);

    void add(DateTime when, String title, String body, [String? payload]) {
      if (when.isAfter(cutoff)) out.add(PlannedNotif(0, when, title, body, payload));
    }

    for (final row in contacts) {
      final name      = ((row['name'] as String?) ?? '').trim();
      final day       = (row['day']   as int?) ?? 0;
      final month     = (row['month'] as int?) ?? 0;
      final birthYear = row['year'] as int?;
      final kind      = normalizeKind(row['kind'] as String?);
      final gift      = ((row['gift_note'] as String?) ?? '').trim();
      final id        = row['id'] as int?;
      final payload   = id != null ? 'contact:$id' : null;
      if (name.isEmpty || month < 1 || month > 12 || day < 1 || day > 31) continue;

      for (int yearOffset = 0; yearOffset <= 1; yearOffset++) {
        final birthday = birthdayInYear(now.year + yearOffset, month, day);
        int? age;
        if (birthYear != null && birthYear > 0) {
          age = birthday.year - birthYear;
          if (age < 0) age = null;
        }
        final milestone = kind == 'birthday' && age != null && milestoneAges.contains(age);

        String title(int daysBefore) =>
            _buildTitle(name, age, daysBefore, s.lang, milestone, kind);
        final bodyDayOf = milestone
            ? (es ? '¡Un día muy especial! Abre Celebria para celebrar 🎊'
                  : 'A very special day! Open Celebria to celebrate 🎊')
            : (es ? 'Abre Celebria para celebrar 🎉' : 'Open Celebria to celebrate 🎉');
        // Gift reminder: advance notices surface the contact's gift idea.
        final bodyBefore = gift.isNotEmpty
            ? (es ? '🎁 Idea de regalo: $gift' : '🎁 Gift idea: $gift')
            : (es ? 'Prepara tu felicitación con tiempo 😊' : 'Prepare your wishes in advance 😊');

        final dayOfWanted = s.notifDays == 0 || s.alsoOnDay || s.remindAllDay;
        if (s.notifDays > 0) {
          add(at(birthday.subtract(Duration(days: s.notifDays))), title(s.notifDays), bodyBefore, payload);
        }
        if (dayOfWanted) add(at(birthday), title(0), bodyDayOf, payload);
        if (s.notifDays2 > 0 && s.notifDays2 != s.notifDays) {
          add(at(birthday.subtract(Duration(days: s.notifDays2))), title(s.notifDays2), bodyBefore, payload);
        }
        if (s.remindAllDay && s.remindInterval > 0) {
          final endOfDay = DateTime(birthday.year, birthday.month, birthday.day, 23, 59);
          for (var k = 1;; k++) {
            final when = at(birthday, s.remindInterval * k);
            if (!when.isBefore(endOfDay)) break;
            add(when, title(0), bodyDayOf, payload);
          }
        }
      }
    }

    if (s.monthlySummary) {
      final byMonth = <int, List<String>>{};
      for (final row in contacts) {
        final name  = ((row['name'] as String?) ?? '').trim();
        final month = (row['month'] as int?) ?? 0;
        if (month < 1 || month > 12 || name.isEmpty) continue;
        byMonth.putIfAbsent(month, () => []).add(name);
      }
      for (int yearOffset = 0; yearOffset <= 1; yearOffset++) {
        for (int m = 1; m <= 12; m++) {
          final names = byMonth[m];
          if (names == null || names.isEmpty) continue;
          final count = names.length;
          final preview = count <= 3
              ? names.join(', ')
              : '${names.take(3).join(', ')} +${count - 3}';
          final title = es
              ? '📅 ${_monthName(m, s.lang)} tiene $count cumpleaños'
              : '📅 ${_monthName(m, s.lang)} has $count birthday${count == 1 ? '' : 's'}';
          add(at(DateTime(now.year + yearOffset, m, 1)), title, preview, 'month:$m');
        }
      }
    }

    out.sort((a, b) => a.when.compareTo(b.when));
    final capped = out.length > maxScheduled ? out.sublist(0, maxScheduled) : out;
    return [
      for (var i = 0; i < capped.length; i++)
        PlannedNotif(1000 + i, capped[i].when, capped[i].title, capped[i].body, capped[i].payload),
    ];
  }

  // ── Immediate test notification (Settings → "Send test push notification") ─
  // Public: called directly from the Settings screen. Now that everything is
  // Dart (no more Python), there's no need for the old DB-flag-plus-resume
  // polling trick — the UI can just call this straight away.
  /// Returns false when Android has Celebria's notifications switched off
  /// (the push is silently dropped then) so the UI can tell the user why.
  static Future<bool> fireTestNotification(String lang) async {
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
      debugPrint('[Celebria] Test notification fired.');
    } catch (e) {
      debugPrint('[Celebria] Test notification failed: $e');
    }
    return areNotificationsEnabled();
  }

  // ── Schedule a single notification with exact alarm fallback ────────────────
  static Future<void> _scheduleNotif(
      int id, String title, String body, tz.TZDateTime when, {String? payload}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'celebria_birthdays',
        'Birthday Reminders',
        channelDescription: 'Daily birthday reminders from Celebria',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        // Expandable text: long gift ideas / name lists aren't cut off.
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    try {
      await _notif.zonedSchedule(
        id, title, body, when, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // SCHEDULE_EXACT_ALARM not granted — fall back to inexact
      try {
        await _notif.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (e) {
        debugPrint('[Celebria] Could not schedule notif $id: $e');
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _buildTitle(String name, int? age, int daysLabel, String lang,
      bool isMilestone, [String kind = 'birthday']) {
    final es = lang == 'es';
    final when = daysLabel == 0
        ? (es ? 'HOY' : 'TODAY')
        : (es ? 'en $daysLabel día(s)' : 'in $daysLabel day(s)');
    if (kind == 'anniversary') {
      final yrs = age != null && age > 0 ? (es ? ' ($age años)' : ' ($age years)') : '';
      return daysLabel == 0
          ? (es ? '💍 ¡Aniversario de $name HOY!$yrs' : '💍 $name\'s anniversary is TODAY!$yrs')
          : (es ? '💍 Aniversario de $name $when$yrs' : '💍 $name\'s anniversary $when$yrs');
    }
    if (kind == 'other') {
      final yrs = age != null && age > 0 ? (es ? ' ($age años)' : ' ($age years)') : '';
      return daysLabel == 0
          ? (es ? '⭐ ¡$name es HOY!$yrs' : '⭐ $name is TODAY!$yrs')
          : '⭐ $name $when$yrs';
    }
    final emoji = isMilestone ? '🎊' : '🎂';
    if (es) {
      if (daysLabel == 0) {
        return age != null
            ? '$emoji ¡$name cumple $age años HOY!'
            : '$emoji ¡$name cumple años HOY!';
      }
      return age != null
          ? '$emoji $name cumple $age años en $daysLabel día(s)'
          : '$emoji $name cumple años en $daysLabel día(s)';
    }
    if (daysLabel == 0) {
      return age != null ? '$emoji $name turns $age TODAY!' : "$emoji $name's birthday is TODAY!";
    }
    return age != null
        ? '$emoji $name turns $age in $daysLabel day(s)'
        : "$emoji $name's birthday in $daysLabel day(s)";
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

class PlannedNotif {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final String? payload;
  const PlannedNotif(this.id, this.when, this.title, this.body, [this.payload]);
}

class NotifSettings {
  final String lang;
  final int notifDays, notifDays2, hour, minute, remindInterval;
  final bool alsoOnDay, monthlySummary, remindAllDay;
  const NotifSettings({
    this.lang = 'es',
    this.notifDays = 0,
    this.notifDays2 = 0,
    this.hour = 8,
    this.minute = 0,
    this.alsoOnDay = false,
    this.monthlySummary = true,
    this.remindAllDay = false,
    this.remindInterval = 120,
  });
}
