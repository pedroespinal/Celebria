import 'package:flutter/material.dart';

import '../data/db.dart';
import '../models/contact.dart';

/// App-wide mutable state: contacts cache, language, theme, home-screen
/// search/filter. Single ChangeNotifier at the root via `provider` —
/// deliberately simple (no Riverpod/Bloc) to match this app's scope.
class AppState extends ChangeNotifier {
  List<Contact> contacts = [];
  String lang = 'es';
  String theme = 'dark'; // 'dark' | 'light'
  String search = '';
  String relationFilter = 'all'; // all | family | friend | work | other

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    lang = await AppDb.instance.getSetting('lang', 'es');
    theme = await AppDb.instance.getSetting('theme', 'dark');
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
  }

  Future<void> setTheme(String value) async {
    theme = value;
    await AppDb.instance.setSetting('theme', value);
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
