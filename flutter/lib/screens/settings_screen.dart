import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import '../core/vcf_parser.dart';
import '../data/db.dart';
import '../models/contact.dart';
import '../notification_helper.dart';
import '../state/app_state.dart';
import '../widgets/buttons.dart';
import '../widgets/section_header.dart';
import 'help_screen.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _notifDays = 0;
  int _notifDays2 = 0;
  int _notifHour = 8;
  int _notifMinute = 0;
  bool _alsoDayOf = false;
  bool _monthlySummary = true;
  bool _showPopup = true;
  bool _remindAllDay = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = AppDb.instance;
    _notifDays = int.tryParse(await db.getSetting('notif_days', '0')) ?? 0;
    _notifDays2 = int.tryParse(await db.getSetting('notif_days_2', '0')) ?? 0;
    _notifHour = int.tryParse(await db.getSetting('notif_hour', '8')) ?? 8;
    _notifMinute = int.tryParse(await db.getSetting('notif_minute', '0')) ?? 0;
    _alsoDayOf = await db.getSetting('notif_also_day_of', '0') == '1';
    _monthlySummary = await db.getSetting('notif_monthly_summary', '1') == '1';
    _showPopup = await db.getSetting('show_popup', '1') == '1';
    _remindAllDay = await db.getSetting('remind_all_day', '0') == '1';
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveAndReschedule(String key, Object value) async {
    await AppDb.instance.setSetting(key, value);
    NotificationHelper.scheduleFromDB();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showBatteryGuide(Palette p, String lang) {
    final contentEs = "Las notificaciones de Celebria pueden ser bloqueadas por el "
        "sistema de ahorro de batería del fabricante. Sigue los pasos "
        "para tu marca:\n\n"
        "📱 Samsung\nAjustes → Batería → Optimización de batería → "
        "Todas las apps → Celebria → No restringir\n\n"
        "📱 Xiaomi / MIUI\nAjustes → Apps → Administrar apps → Celebria "
        "→ Ahorro de batería → Sin restricciones\n\n"
        "📱 Huawei\nAjustes → Batería → Inicio de apps → Celebria → "
        "Gestión manual → activa los 3 toggles\n\n"
        "📱 OPPO / ColorOS\nAjustes → Batería → Gestión de energía → "
        "Celebria → No restringir\n\n"
        "📱 Otros\nAjustes → Apps → Celebria → Batería → Sin restricciones";
    final contentEn = "Celebria notifications can be blocked by manufacturer battery "
        "optimization. Follow the steps for your brand:\n\n"
        "📱 Samsung\nSettings → Battery → Battery optimization → "
        "All apps → Celebria → Don't optimize\n\n"
        "📱 Xiaomi / MIUI\nSettings → Apps → Manage apps → Celebria "
        "→ Battery saver → No restrictions\n\n"
        "📱 Huawei\nSettings → Battery → App launch → Celebria → "
        "Manual → enable all 3 toggles\n\n"
        "📱 OPPO / ColorOS\nSettings → Battery → Power management → "
        "Celebria → No restriction\n\n"
        "📱 Others\nSettings → Apps → Celebria → Battery → Unrestricted";
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: p.bg2,
        title: Text(t(lang, 'battery_guide_title'),
            style: TextStyle(color: p.cyan, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Text(lang == 'es' ? contentEs : contentEn,
                style: TextStyle(fontSize: 12, color: p.t1)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _doExport(AppState state, String lang) async {
    final jsonStr = await AppDb.instance.toJson();
    try {
      final path = await FilePicker.platform.saveFile(
        fileName: 'Celebria_backup.json',
        bytes: utf8EncodeToBytes(jsonStr),
      );
      if (path != null && mounted) _toast('✓  ${t(lang, 'export_ok')}');
    } catch (e) {
      if (mounted) _toast('Error: $e');
    }
  }

  Future<void> _doImport(AppState state, String lang) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final file = result.files.single;
      final txt = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      final n = await AppDb.instance.fromJson(txt);
      if (n >= 0) {
        await state.reloadContacts();
        NotificationHelper.scheduleFromDB();
        if (mounted) _toast('✓  $n ${t(lang, 'import_ok')}');
      } else if (mounted) {
        _toast('Error en el archivo / File error');
      }
    } catch (e) {
      if (mounted) _toast('Error: $e');
    }
  }

  Future<void> _doVcfImport(AppState state, String lang, Palette p) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vcf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final content = file.bytes != null
        ? utf8.decode(file.bytes!, allowMalformed: true)
        : await File(file.path!).readAsString();
    final parsed = parseVcf(content);
    if (parsed.isEmpty) {
      if (mounted) _toast(t(lang, 'import_vcf_none'));
      return;
    }
    if (!mounted) return;
    final selected = List<bool>.filled(parsed.length, true);
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: p.bg2,
          title: Text('Importar contactos', style: TextStyle(color: p.cyan)),
          content: SizedBox(
            width: 300,
            height: 360,
            child: ListView.builder(
              itemCount: parsed.length,
              itemBuilder: (_, i) => CheckboxListTile(
                value: selected[i],
                onChanged: (v) => setDialogState(() => selected[i] = v ?? false),
                title: Text(parsed[i].name ?? '?', style: TextStyle(color: p.t1, fontSize: 13)),
                subtitle: Text('${parsed[i].day}/${parsed[i].month}',
                    style: TextStyle(color: p.t3, fontSize: 11)),
                activeColor: p.cyan,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(t(lang, 'btn_cancel'), style: TextStyle(color: p.t3)),
            ),
            TextButton(
              onPressed: () async {
                var imported = 0;
                for (var i = 0; i < parsed.length; i++) {
                  if (!selected[i]) continue;
                  final vc = parsed[i];
                  await AppDb.instance.addContact(Contact(
                    id: 0,
                    name: vc.name ?? '?',
                    day: vc.day ?? 1,
                    month: vc.month ?? 1,
                    year: vc.year,
                    phone: vc.phone ?? '',
                    relation: 'friend',
                  ));
                  imported++;
                }
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                await state.reloadContacts();
                NotificationHelper.scheduleFromDB();
                if (mounted) _toast('✓  $imported ${t(lang, 'import_ok')}');
              },
              child: Text(t(lang, 'confirm_yes'), style: TextStyle(color: p.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;

    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          SectionHeader(t(lang, 'set_theme'), palette: p),
          Row(children: [
            OptionButton(
                label: '🌙  Dark',
                active: state.theme == 'dark',
                palette: p,
                onTap: () => state.setTheme('dark')),
            const SizedBox(width: 10),
            OptionButton(
                label: '☀  Light',
                active: state.theme == 'light',
                palette: p,
                onTap: () => state.setTheme('light')),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_lang'), palette: p),
          Row(children: [
            OptionButton(
                label: '🇩🇴  Español',
                active: lang == 'es',
                palette: p,
                onTap: () => state.setLang('es')),
            const SizedBox(width: 10),
            OptionButton(
                label: '🇺🇸  English',
                active: lang == 'en',
                palette: p,
                onTap: () => state.setLang('en')),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_notif'), palette: p),
          Row(children: [
            for (final pair in [(0, 'same_day'), (1, 'one_day'), (3, 'three_days'), (7, 'one_week')])
              OptionButton(
                label: t(lang, pair.$2),
                active: _notifDays == pair.$1,
                palette: p,
                margin: const EdgeInsets.only(right: 4),
                onTap: () {
                  setState(() => _notifDays = pair.$1);
                  _saveAndReschedule('notif_days', pair.$1);
                },
              ),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_notif_hour'), palette: p),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DropdownButton<int>(
                value: _notifHour,
                dropdownColor: p.bg2,
                style: TextStyle(color: p.t1),
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0')))
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _notifHour = v);
                  _saveAndReschedule('notif_hour', v);
                  _toast('${t(lang, 'alarm_saved')}  ${v.toString().padLeft(2, '0')}:${_notifMinute.toString().padLeft(2, '0')}');
                },
              ),
              Text(':', style: TextStyle(fontSize: 24, color: p.t2, fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _notifMinute,
                dropdownColor: p.bg2,
                style: TextStyle(color: p.t1),
                items: [
                  for (var m = 0; m < 60; m++)
                    DropdownMenuItem(value: m, child: Text(':${m.toString().padLeft(2, '0')}'))
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _notifMinute = v);
                  _saveAndReschedule('notif_minute', v);
                  _toast('${t(lang, 'alarm_saved')}  ${_notifHour.toString().padLeft(2, '0')}:${v.toString().padLeft(2, '0')}');
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_notif_also_day'), palette: p),
          Row(children: [
            OptionButton(
                label: t(lang, 'notif_also_day_on'),
                active: _alsoDayOf,
                palette: p,
                onTap: () {
                  setState(() => _alsoDayOf = true);
                  _saveAndReschedule('notif_also_day_of', '1');
                }),
            const SizedBox(width: 10),
            OptionButton(
                label: t(lang, 'notif_also_day_off'),
                active: !_alsoDayOf,
                palette: p,
                onTap: () {
                  setState(() => _alsoDayOf = false);
                  _saveAndReschedule('notif_also_day_of', '0');
                }),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_notif_days_2'), palette: p),
          Row(children: [
            for (final pair in [(0, 'notif_days_2_off'), (1, 'one_day'), (3, 'three_days'), (7, 'one_week')])
              OptionButton(
                label: t(lang, pair.$2),
                active: _notifDays2 == pair.$1,
                palette: p,
                margin: const EdgeInsets.only(right: 4),
                onTap: () {
                  setState(() => _notifDays2 = pair.$1);
                  _saveAndReschedule('notif_days_2', pair.$1);
                },
              ),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'monthly_summary'), palette: p),
          Row(children: [
            OptionButton(
                label: t(lang, 'monthly_summary_on'),
                active: _monthlySummary,
                palette: p,
                onTap: () {
                  setState(() => _monthlySummary = true);
                  _saveAndReschedule('notif_monthly_summary', '1');
                }),
            const SizedBox(width: 10),
            OptionButton(
                label: t(lang, 'monthly_summary_off'),
                active: !_monthlySummary,
                palette: p,
                onTap: () {
                  setState(() => _monthlySummary = false);
                  _saveAndReschedule('notif_monthly_summary', '0');
                }),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showBatteryGuide(p, lang),
              child: Text(t(lang, 'battery_guide_btn'), style: TextStyle(color: p.yellow)),
            ),
          ),
          const SizedBox(height: 6),
          SectionHeader(t(lang, 'set_popup'), palette: p),
          Row(children: [
            OptionButton(
                label: '🎂  ${t(lang, 'opt_show')}',
                active: _showPopup,
                palette: p,
                onTap: () {
                  setState(() => _showPopup = true);
                  AppDb.instance.setSetting('show_popup', '1');
                }),
            const SizedBox(width: 10),
            OptionButton(
                label: '🚫  ${t(lang, 'opt_hide')}',
                active: !_showPopup,
                palette: p,
                onTap: () {
                  setState(() => _showPopup = false);
                  AppDb.instance.setSetting('show_popup', '0');
                }),
          ]),
          const SizedBox(height: 10),
          SectionHeader(t(lang, 'set_remind_all_day'), palette: p),
          Row(children: [
            OptionButton(
                label: '🔔  ${t(lang, 'remind_all_day_on')}',
                active: _remindAllDay,
                palette: p,
                onTap: () {
                  setState(() => _remindAllDay = true);
                  AppDb.instance.setSetting('remind_all_day', '1');
                }),
            const SizedBox(width: 10),
            OptionButton(
                label: '🔕  ${t(lang, 'remind_all_day_off')}',
                active: !_remindAllDay,
                palette: p,
                onTap: () {
                  setState(() => _remindAllDay = false);
                  AppDb.instance.setSetting('remind_all_day', '0');
                }),
          ]),
          const SizedBox(height: 12),
          SolidButton(t(lang, 'test_push_btn'), p.cyan,
              onPressed: () => NotificationHelper.fireTestNotification(lang)),
          const SizedBox(height: 12),
          SectionHeader(t(lang, 'set_backup'), palette: p),
          Row(children: [
            Expanded(
                child: SolidButton('📤  ${t(lang, 'btn_export')}', p.green,
                    onPressed: () => _doExport(state, lang))),
            const SizedBox(width: 10),
            Expanded(
                child: SolidButton('📥  ${t(lang, 'btn_import')}', p.yellow,
                    onPressed: () => _doImport(state, lang))),
          ]),
          const SizedBox(height: 10),
          SolidButton('📱  ${t(lang, 'import_vcf_btn')}', p.cyan,
              onPressed: () => _doVcfImport(state, lang, p)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: SolidButton('📊  ${t(lang, 'stats_btn')}', p.violet,
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const StatsScreen())))),
            const SizedBox(width: 10),
            Expanded(
                child: SolidButton('📖  ${t(lang, 'manual_btn')}', p.purple,
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const HelpScreen())))),
          ]),
          const SizedBox(height: 12),
          SectionHeader(t(lang, 'about_title'), palette: p),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎂  Celebria', style: TextStyle(color: p.cyan, fontWeight: FontWeight.bold)),
                Text(t(lang, 'app_sub'), style: TextStyle(fontSize: 11, color: p.t2)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppFooter(t(lang, 'app_sub'), palette: p),
        ],
      ),
    );
  }
}

Uint8List utf8EncodeToBytes(String s) => Uint8List.fromList(utf8.encode(s));
