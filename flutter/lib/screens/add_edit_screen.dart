import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/palette.dart';
import '../data/db.dart';
import '../models/contact.dart';
import '../notification_helper.dart';
import '../state/app_state.dart';
import '../widgets/avatar.dart';
import '../widgets/buttons.dart';
import '../widgets/section_header.dart';

/// Shared add/edit contact form. `existing == null` means "new contact".
class AddEditScreen extends StatefulWidget {
  final Contact? existing;
  final VoidCallback onDone;

  const AddEditScreen({super.key, required this.existing, required this.onDone});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _giftCtrl = TextEditingController();

  int? _day;
  int? _month;
  int? _year;
  String _relation = 'friend';
  String _photo = '';
  String _error = '';
  bool _confirmingDelete = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _emailCtrl.text = c.email;
      _notesCtrl.text = c.notes;
      _giftCtrl.text = c.giftNote;
      _day = c.day;
      _month = c.month;
      _year = c.year;
      _relation = c.relation;
      _photo = c.photo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _giftCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final dest = await AppDb.instance.copyPhoto(path);
    setState(() => _photo = dest);
  }

  void _removePhoto() => setState(() => _photo = '');

  Future<void> _save(AppState state, String lang) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = t(lang, 'err_name'));
      return;
    }
    if (_day == null || _month == null) {
      setState(() => _error = t(lang, 'err_date'));
      return;
    }

    if (_editing) {
      final updated = widget.existing!.copyWith(
        name: name,
        day: _day,
        month: _month,
        year: _year,
        clearYear: _year == null,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        relation: _relation,
        photo: _photo,
        giftNote: _giftCtrl.text.trim(),
      );
      await AppDb.instance.updateContact(updated);
    } else {
      await AppDb.instance.addContact(Contact(
        id: 0,
        name: name,
        day: _day!,
        month: _month!,
        year: _year,
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        relation: _relation,
        photo: _photo,
        giftNote: _giftCtrl.text.trim(),
      ));
    }

    await state.reloadContacts();
    // Direct wiring: reschedule right away instead of waiting for the next
    // app resume — this is the concrete fix the whole rewrite exists for.
    NotificationHelper.scheduleFromDB();

    if (!_editing) {
      final total = state.contacts.length;
      if (total > 0 && total % 10 == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(lang, 'backup_remind_tip'))),
        );
      }
      _resetForm();
    }
    widget.onDone();
  }

  void _resetForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    _giftCtrl.clear();
    setState(() {
      _day = null;
      _month = null;
      _year = null;
      _relation = 'friend';
      _photo = '';
      _error = '';
    });
  }

  Future<void> _delete(AppState state) async {
    await AppDb.instance.deleteContact(widget.existing!.id);
    await state.reloadContacts();
    NotificationHelper.scheduleFromDB();
    widget.onDone();
  }

  InputDecoration _dec(Palette p, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.t3),
        filled: true,
        fillColor: p.bg3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.cyan)),
      );

  Widget _fieldLabel(String text, Palette p) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(fontSize: 11, color: p.t2, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = state.theme == 'dark' ? darkPalette : lightPalette;
    final lang = state.lang;
    final currentYear = DateTime.now().year;

    return Container(
      color: p.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _fieldLabel(t(lang, 'field_name'), p),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: p.t1),
            decoration: _dec(p, t(lang, 'field_name')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(t(lang, 'field_day'), p),
                    DropdownButtonFormField<int>(
                      initialValue: _day,
                      hint: const Text('DD'),
                      decoration: _dec(p, 'DD'),
                      dropdownColor: p.bg3,
                      style: TextStyle(color: p.t1),
                      items: [
                        for (var i = 1; i <= 31; i++)
                          DropdownMenuItem(value: i, child: Text('$i'))
                      ],
                      onChanged: (v) => setState(() => _day = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(t(lang, 'field_month'), p),
                    DropdownButtonFormField<int>(
                      initialValue: _month,
                      hint: const Text('MM'),
                      decoration: _dec(p, 'MM'),
                      dropdownColor: p.bg3,
                      style: TextStyle(color: p.t1),
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(value: i, child: Text(monthName(lang, i)))
                      ],
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(t(lang, 'field_year'), p),
                    DropdownButtonFormField<int?>(
                      initialValue: _year,
                      decoration: _dec(p, t(lang, 'field_year')),
                      dropdownColor: p.bg3,
                      style: TextStyle(color: p.t1),
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text('— ${t(lang, 'field_year')} —')),
                        for (var y = currentYear; y > 1919; y--)
                          DropdownMenuItem<int?>(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_relation'), p),
          Row(
            children: [
              ('family', '👪', 'rel_family'),
              ('friend', '👥', 'rel_friend'),
              ('work', '💼', 'rel_work'),
              ('other', '⭐', 'rel_other'),
            ]
                .map((tuple) {
                  final (rv, icon, labelKey) = tuple;
                  return OptionButton(
                    label: '$icon ${t(lang, labelKey)}',
                    active: _relation == rv,
                    palette: p,
                    margin: const EdgeInsets.only(right: 4),
                    onTap: () => setState(() => _relation = rv),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_phone'), p),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: p.t1),
            decoration: _dec(p, '+1-809-...'),
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_email'), p),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: p.t1),
            decoration: _dec(p, 'email@...'),
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_notes'), p),
          TextField(
            controller: _notesCtrl,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: p.t1),
            decoration: _dec(p, '...'),
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_gift'), p),
          TextField(
            controller: _giftCtrl,
            minLines: 3,
            maxLines: 5,
            style: TextStyle(color: p.t1),
            decoration: _dec(p, t(lang, 'gift_hint')),
          ),
          const SizedBox(height: 10),
          _fieldLabel(t(lang, 'field_photo'), p),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.bg3, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                ContactAvatar(
                  photo: _photo,
                  name: _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text,
                  relation: _relation,
                  palette: p,
                  size: 70,
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _pickPhoto,
                  child: Text(_photo.isEmpty ? t(lang, 'photo_add') : t(lang, 'photo_change'),
                      style: TextStyle(color: p.cyan)),
                ),
                if (_photo.isNotEmpty)
                  TextButton(
                    onPressed: _removePhoto,
                    child: Text(t(lang, 'photo_remove'), style: TextStyle(color: p.t3)),
                  ),
              ],
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: TextStyle(color: p.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SolidButton(t(lang, 'btn_cancel'), p.t3, onPressed: widget.onDone),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SolidButton('💾  ${t(lang, 'btn_save')}', p.cyan,
                    onPressed: () => _save(state, lang)),
              ),
            ],
          ),
          if (_editing) ...[
            const SizedBox(height: 10),
            if (!_confirmingDelete)
              SolidButton('🗑  ${t(lang, 'btn_delete')}', p.red,
                  onPressed: () => setState(() => _confirmingDelete = true))
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.bg3, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: [
                    Text(t(lang, 'confirm_delete'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.yellow, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SolidButton(t(lang, 'confirm_no'), p.t3,
                              onPressed: () => setState(() => _confirmingDelete = false)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SolidButton(t(lang, 'confirm_yes'), p.red,
                              onPressed: () => _delete(state)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          AppFooter(
              '${t(lang, 'created_by')}: Pedro Espinal   ·   ${t(lang, 'rights')}',
              palette: p),
        ],
      ),
    );
  }
}
