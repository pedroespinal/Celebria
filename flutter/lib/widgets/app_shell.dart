import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../screens/add_edit_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/help_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';

/// Persistent bottom-nav shell hosting the 4 main tabs (Home/Add/Calendar/
/// Settings). Detail/Stats/Help/Birthday are reached via Navigator.push from
/// within a tab, matching how a native Flutter app organizes "main" vs
/// "pushed" screens (the original Flet app used one flat `navigate()` for
/// everything since Flet has no real Navigator stack).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _titleKeys = [null, 'add_title', 'nav_calendar', 'nav_settings'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;

    final titleKey = _titleKeys[_index];
    final title = titleKey == null ? '🎂  $appName  v$appVersion' : t(lang, titleKey);

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg2,
        title: Text(title,
            style: TextStyle(color: palette.cyan, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: palette.cyan),
            tooltip: 'Ayuda / Help',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const HelpScreen())),
          ),
          TextButton(
            onPressed: () => state.setLang(lang == 'es' ? 'en' : 'es'),
            child: Text(t(lang, 'lang_btn'), style: TextStyle(color: palette.cyan)),
          ),
          IconButton(
            icon: Icon(
              state.theme == 'dark' ? Icons.light_mode : Icons.dark_mode,
              color: palette.yellow,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => state.setTheme(state.theme == 'dark' ? 'light' : 'dark'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenAdd: () => setState(() => _index = 1)),
          AddEditScreen(
            key: ValueKey('add-tab-${state.contacts.length}'),
            existing: null,
            onDone: () => setState(() => _index = 0),
          ),
          const CalendarScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: palette.bg2,
        indicatorColor: palette.cyandim,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t(lang, 'nav_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle_outline),
            selectedIcon: const Icon(Icons.add_circle),
            label: t(lang, 'nav_add'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: t(lang, 'nav_calendar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: t(lang, 'nav_settings'),
          ),
        ],
      ),
    );
  }
}
