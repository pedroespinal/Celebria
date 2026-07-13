import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/help_data.dart';
import '../core/i18n.dart';
import '../core/palette.dart';
import '../state/app_state.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;
    final entries = lang == 'es' ? kHelpEs : kHelpEn;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg2,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.cyan),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('📖  ${t(lang, 'manual_btn')}', style: TextStyle(color: p.cyan)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          children: [
            for (final entry in entries)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(entry.title,
                              style: TextStyle(fontSize: 14, color: p.cyan, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(entry.body, style: TextStyle(fontSize: 12, color: p.t1, height: 1.4)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
