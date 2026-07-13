import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/date_utils.dart';
import 'core/palette.dart';
import 'data/db.dart';
import 'notification_helper.dart';
import 'screens/birthday_screen.dart';
import 'services/update_checker.dart';
import 'state/app_state.dart';
import 'widgets/app_shell.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const MethodChannel _bootChannel = MethodChannel('com.flet.celebria/boot');

// Keeps the AppLifecycleListener alive for the whole process lifetime — a
// local variable would get garbage-collected and silently stop firing.
// ignore: unused_element
AppLifecycleListener? _lifecycleListener;

/// Entry point called by BootReceiver on device restart to reschedule
/// notifications without opening the full app UI.
@pragma('vm:entry-point')
void backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationHelper.initialize();
  try {
    await _bootChannel.invokeMethod('bootRescheduleDone');
  } catch (_) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Deferred to after the first rendered frame — confirmed via direct
  // device/emulator testing that calling this before runApp() intermittently
  // crashed inside requestNotificationsPermission() with a null-Activity
  // PlatformException, because the Activity isn't guaranteed to be attached
  // to the plugin yet. addPostFrameCallback guarantees a frame was drawn,
  // which guarantees the Activity is live.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationHelper.initialize();

    // Now that the whole app is Dart, contact/settings screens call
    // NotificationHelper.scheduleFromDB() directly right after every DB
    // write — this resume listener is just a safety net (e.g. the DB
    // changed from a restored backup, or the app was killed and restarted
    // by the OS mid-edit) rather than the only path, as it was previously.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => NotificationHelper.scheduleFromDB(),
    );
  });

  runApp(const CelebriaApp());
}

class CelebriaApp extends StatelessWidget {
  const CelebriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          if (!state.loaded) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          final palette = state.theme == 'dark' ? darkPalette : lightPalette;
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Celebria',
            debugShowCheckedModeBanner: false,
            theme: buildThemeData(
                palette, state.theme == 'dark' ? Brightness.dark : Brightness.light),
            home: _AppRoot(state: state),
          );
        },
      ),
    );
  }
}

/// Hosts the main shell and, once mounted, checks whether to show the
/// birthday celebration screen and/or an update-available dialog.
class _AppRoot extends StatefulWidget {
  final AppState state;
  const _AppRoot({required this.state});

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _checkedBirthday = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedBirthday) {
      _checkedBirthday = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowBirthday());
    }
  }

  Future<void> _maybeShowBirthday() async {
    final db = AppDb.instance;
    final showPopup = await db.getSetting('show_popup', '1') == '1';
    if (!showPopup) {
      _checkUpdate();
      return;
    }

    final todays =
        widget.state.contacts.where((c) => daysUntil(c.day, c.month) == 0).toList();
    if (todays.isEmpty) {
      _checkUpdate();
      return;
    }

    final remindAllDay = await db.getSetting('remind_all_day', '0') == '1';
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final dismissedDate = await db.getSetting('birthday_dismissed_date', '');
    final alreadyDismissed = dismissedDate == todayStr;

    if (remindAllDay || !alreadyDismissed) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BirthdayScreen(todaysContacts: todays)),
      );
    }
    _checkUpdate();
  }

  void _checkUpdate() {
    final palette = widget.state.theme == 'dark' ? darkPalette : lightPalette;
    UpdateChecker.check(context, widget.state.lang, palette);
  }

  @override
  Widget build(BuildContext context) => const AppShell();
}
