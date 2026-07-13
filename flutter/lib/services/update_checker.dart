import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/palette.dart';
import '../data/db.dart';

/// Background check against version.json in the GitHub repo — shows an
/// update (or forced-update) dialog if a newer release is available.
/// Ported from main.py's `_check_for_update`.
class UpdateChecker {
  static bool _shown = false;

  static List<int> _verTuple(String v) {
    try {
      final clean = v.trim().replaceFirst(RegExp(r'^v'), '');
      return clean.split('.').map((s) => int.parse(s)).toList();
    } catch (_) {
      return [0];
    }
  }

  static bool _isGreater(List<int> a, List<int> b) {
    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  static Future<void> check(BuildContext context, String lang, Palette p) async {
    try {
      final url = Uri.parse('https://raw.githubusercontent.com/$githubRepo/main/version.json');
      final resp = await http
          .get(url, headers: {'User-Agent': 'Celebria-App'})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final latest = data['latest'] as String? ?? '';
      final minimum = data['minimum'] as String? ?? '0.0.0';
      final dlUrl = data['download_url'] as String? ??
          'https://github.com/$githubRepo/releases/latest';

      final cur = _verTuple(appVersion);
      if (!_isGreater(_verTuple(latest), cur)) return;

      final forced = _isGreater(_verTuple(minimum), cur);
      if (!forced) {
        final snoozed = await AppDb.instance.getSetting('snoozed_update_ver', '');
        if (snoozed == latest) return;
      }
      if (_shown && !forced) return;
      _shown = true;

      if (!context.mounted) return;
      _showDialog(context, lang, p, latest, dlUrl, forced);
    } catch (_) {
      // No connection or malformed response — fail silently.
    }
  }

  static void _showDialog(
      BuildContext context, String lang, Palette p, String newVer, String dlUrl, bool forced) {
    final es = lang == 'es';
    final title = es
        ? (forced ? '🔒  ¡Actualización requerida!' : '🎉  ¡Nueva versión disponible!')
        : (forced ? '🔒  Update required!' : '🎉  Update available!');
    final body = es
        ? (forced
            ? 'Esta versión (v$appVersion) ya no es compatible.\nDebes actualizar a v$newVer para continuar usando Celebria.'
            : 'Celebria v$newVer ya está disponible.\nTienes instalada la v$appVersion.\n\n📥 Al terminar la descarga, toca el archivo APK\nen la barra de notificaciones para instalarlo.')
        : (forced
            ? 'Version v$appVersion is no longer supported.\nYou must update to v$newVer to keep using Celebria.'
            : 'Celebria v$newVer is now available.\nYou have v$appVersion installed.\n\n📥 When the download finishes, tap the APK file\nin your notifications to install it.');
    final btnLater = es ? 'Ahora no' : 'Not now';
    final btnDl = es ? '⬇  Descargar' : '⬇  Download';
    final dlColor = forced ? p.red : p.cyan;
    final releasesPage = 'https://github.com/$githubRepo/releases/tag/v$newVer';

    showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (dialogCtx) => PopScope(
        canPop: !forced,
        child: AlertDialog(
          backgroundColor: p.bg2,
          title: Text(title,
              style: TextStyle(
                  color: forced ? p.red : p.cyan, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(body, style: TextStyle(color: p.t1, fontSize: 13)),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            if (!forced)
              TextButton(
                onPressed: () async {
                  await AppDb.instance.setSetting('snoozed_update_ver', newVer);
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                },
                child: Text(btnLater, style: TextStyle(color: p.t3)),
              ),
            TextButton(
              onPressed: () {
                launchUrl(Uri.parse(releasesPage), mode: LaunchMode.externalApplication);
                Navigator.of(dialogCtx).pop();
              },
              child: Text(btnDl, style: TextStyle(color: dlColor)),
            ),
          ],
        ),
      ),
    );
  }
}
