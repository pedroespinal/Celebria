import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../data/db.dart';
import '../models/contact.dart';
import '../notification_helper.dart';

/// App-wide mutable state: contacts cache, language, theme, home-screen
/// search/filter. Single ChangeNotifier at the root via `provider` —
/// deliberately simple (no Riverpod/Bloc) to match this app's scope.
class AppState extends ChangeNotifier {
  List<Contact> contacts = [];
  String lang = 'es';
  String theme = 'dark'; // 'dark' | 'light'
  String paletteFamily = defaultPaletteFamily; // tropical | cyber | fiesta

  /// The active colors: chosen family x dark/light mode.
  Palette get palette => paletteFor(paletteFamily, theme);
  String search = '';
  String relationFilter = 'all'; // all | family | friend | work | other

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    lang = await AppDb.instance.getSetting('lang', 'es');
    theme = await AppDb.instance.getSetting('theme', 'dark');
    paletteFamily = await AppDb.instance.getSetting('palette_family', defaultPaletteFamily);
    contacts = await AppDb.instance.allContacts();
    _loaded = true;
    notifyListeners();
  }

  Future<void> reloadContacts() async {
    contacts = await AppDb.instance.allContacts();
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    lang = value;
    await AppDb.instance.setSetting('lang', value);
    notifyListeners();
    // Notification texts (and the home-screen widget) are language-specific
    // — reschedule so already-pending reminders switch language too.
    NotificationHelper.scheduleFromDB();
  }

  Future<void> setTheme(String value) async {
    theme = value;
    await AppDb.instance.setSetting('theme', value);
    notifyListeners();
  }

  Future<void> setPaletteFamily(String value) async {
    paletteFamily = value;
    await AppDb.instance.setSetting('palette_family', value);
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setRelationFilter(String value) {
    relationFilter = value;
    notifyListeners();
  }
}
