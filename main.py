#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Celebria v1.0.0 — Birthday Reminder / Recordatorio de Cumpleanos
Creado por: Pedro Espinal  Todos los derechos reservados (c) 2025
"""

import flet as ft
try:
    from flet_audio import Audio as FletAudio
    _AUDIO_OK = True
except ImportError:
    FletAudio = None
    _AUDIO_OK = False
import sqlite3
import json
import os
import sys
import calendar
from datetime import date
from pathlib import Path

# ── App constants ─────────────────────────────────────────────────────────────
APP_NAME    = "Celebria"
APP_VERSION = "1.4.25"
APP_AUTHOR  = "Pedro Espinal"
APP_RIGHTS  = "Todos los derechos reservados"
APP_YEAR    = str(date.today().year)
COPYRIGHT   = f"Creado por: {APP_AUTHOR}   ·   {APP_RIGHTS}   ©{APP_YEAR}"

# ── GitHub — pon aquí tu usuario/nombre-del-repo ──────────────────────────────
GITHUB_REPO = "pedroespinal/Celebria"

# ── Authorship fingerprint ────────────────────────────────────────────────────
# Firma de origen inmutable incrustada en cada APK compilado.
# Prueba criptográfica de autoría desde el primer commit público.
#
# Verificar en: https://github.com/pedroespinal/Celebria/commit/3c6b33a139fa16560d458d61ca52e2dae5d6b2c7
#
_GENESIS_COMMIT = "3c6b33a139fa16560d458d61ca52e2dae5d6b2c7"   # SHA-1 git — primer commit
_GENESIS_DATE   = "2026-05-19T17:55:07"                         # Fecha de creación (UTC-4)
_GENESIS_AUTHOR = "Pedro Espinal"                               # Autor original
_GENESIS_APP    = "Celebria"                                    # Nombre de la aplicación
# Sello SHA-256: sha256("<commit>|<date>|<author>|<app>")
# Si se altera cualquiera de los valores anteriores, este sello NO coincidirá.
_GENESIS_SEAL   = "61842021809f2b64415f519a874153757cf4a766fee141bd5dd20954aa8d3fc5"

def _verify_genesis() -> bool:
    """Verifica que la firma de origen no ha sido alterada."""
    import hashlib
    data = f"{_GENESIS_COMMIT}|{_GENESIS_DATE}|{_GENESIS_AUTHOR}|{_GENESIS_APP}"
    return hashlib.sha256(data.encode("utf-8")).hexdigest() == _GENESIS_SEAL

# ── Palette ───────────────────────────────────────────────────────────────────
_DARK = {
    "bg":        "#07071a", "bg2":       "#0c0c24", "bg3":       "#10102e",
    "card":      "#0d0d26", "border":    "#1c1c40",
    "cyan":      "#00e5ff", "cyandim":   "#003d54",
    "purple":    "#7c3aed", "purpledim": "#2d1566", "violet": "#a78bfa",
    "pink":      "#f72585", "pinkdim":   "#5c0d33",
    "green":     "#00ff88", "greendim":  "#003320",
    "yellow":    "#ffbe0b", "red":       "#ff3d3d",
    "t1":        "#e8e8ff", "t2":        "#ffaa44", "t3":        "#888aaa",
}
_LIGHT = {
    "bg":        "#f0f0ff", "bg2":       "#e4e4f8", "bg3":       "#d6d6ef",
    "card":      "#e8e8fb", "border":    "#8888bb",
    "cyan":      "#003d99", "cyandim":   "#b8d0ff",
    "purple":    "#5500aa", "purpledim": "#ddd0ff", "violet": "#6d28d9",
    "pink":      "#aa004d", "pinkdim":   "#ffd0e8",
    "green":     "#005522", "greendim":  "#c0f0d8",
    "yellow":    "#6b5000", "red":       "#aa0000",
    "t1":        "#08080f", "t2":        "#1a1a3a", "t3":        "#3a3a5c",
}

THEME: list = ["dark"]
C: dict = {}


def _apply_theme():
    C.clear()
    C.update(_DARK if THEME[0] == "dark" else _LIGHT)


_apply_theme()

# ── Bilingual strings ─────────────────────────────────────────────────────────
T = {
    "es": {
        "app_sub":        "Recordatorio de Cumpleaños",
        "lang_btn":       "EN",
        "nav_home":       "Inicio",
        "nav_add":        "Agregar",
        "nav_calendar":   "Calendario",
        "nav_settings":   "Config",
        "today_title":    "\U0001f382  ¡Hoy!",
        "week_title":     "\U0001f4c5  Esta Semana",
        "month_title":    "\U0001f5d3  Próximamente",
        "all_title":      "\U0001f465  Todos",
        "no_contacts":    "Sin contactos aún.\nPresiona + para agregar.",
        "add_title":      "Nuevo Contacto",
        "edit_title":     "Editar Contacto",
        "field_name":     "Nombre completo *",
        "field_day":      "Día *",
        "field_month":    "Mes *",
        "field_year":     "Año (opcional)",
        "field_phone":    "Teléfono / WhatsApp",
        "field_email":    "Correo electrónico",
        "field_notes":    "Notas",
        "field_relation": "Relación",
        "rel_family":     "Familia",
        "rel_friend":     "Amigo/a",
        "rel_work":       "Trabajo",
        "rel_other":      "Otro",
        "btn_save":       "GUARDAR",
        "btn_cancel":     "CANCELAR",
        "btn_delete":     "ELIMINAR",
        "btn_edit":       "EDITAR",
        "btn_whatsapp":   "WhatsApp",
        "search_hint":    "Buscar por nombre...",
        "days_left":      "días",
        "today_badge":    "¡HOY!",
        "tomorrow_badge": "Mañana",
        "years":          "años",
        "calendar_title": "Calendario",
        "settings_title": "Configuración",
        "set_theme":      "Tema",
        "set_lang":       "Idioma / Language",
        "set_notif":      "Notificaciones anticipadas",
        "set_backup":     "Respaldo de Datos",
        "btn_export":     "Exportar JSON",
        "btn_import":     "Importar JSON",
        "confirm_delete": "¿Eliminar este contacto?",
        "confirm_yes":    "Sí, eliminar",
        "confirm_no":     "No, cancelar",
        "popup_title":    "¡Feliz Cumpleaños!",
        "popup_turns":    "Hoy cumple",
        "popup_years":    "años",
        "popup_close":    "¡Celebrar!",
        "err_name":       "El nombre es obligatorio",
        "err_date":       "Día y mes son obligatorios",
        "err_day":        "Día inválido (1-31)",
        "err_month":      "Mes inválido (1-12)",
        "about_title":    "Acerca de Celebria",
        "filter_all":     "Todos",
        "filter_fam":     "Familia",
        "filter_fri":     "Amigos",
        "filter_wor":     "Trabajo",
        "export_ok":      "Exportado",
        "import_ok":      "contactos importados",
        "file_not_found": "Archivo no encontrado",
        "same_day":       "Hoy",
        "one_day":        "1 día antes",
        "three_days":     "3 días antes",
        "one_week":       "1 semana antes",
        "set_notif_hour": "Hora del recordatorio",
        "alarm_saved":    "Hora guardada",
        "manual_btn":     "Manual de Usuario",
        "back_settings":  "Volver a Configuración",
        "set_popup":      "Popup de cumpleaños",
        "opt_show":       "Mostrar",
        "opt_hide":       "Ocultar",
        "months": [
            "", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
            "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
        ],
        "days_abbr": ["Lu", "Ma", "Mi", "Ju", "Vi", "Sa", "Do"],
        "import_vcf_btn":   "Importar desde Agenda (.vcf)",
        "import_vcf_title": "Importar desde Agenda",
        "import_vcf_found": "contactos con cumpleaños encontrados",
        "import_vcf_none":  "No se encontraron contactos con cumpleaños",
        "import_vcf_do":    "IMPORTAR SELECCIONADOS",
        "import_vcf_all":   "Todos",
        "import_vcf_clear": "Ninguno",
        "import_vcf_ok":    "contactos importados desde la agenda",
        "import_vcf_empty": "Selecciona al menos un contacto",
        "field_photo":      "Foto",
        "photo_add":        "Agregar foto",
        "photo_change":     "Cambiar foto",
        "photo_remove":     "Quitar foto",
        "field_gift":       "Nota de regalo",
        "gift_hint":        "¿Qué le gustaría recibir?",
        "stats_title":      "Estadísticas rápidas",
        "stats_btn":        "Estadísticas",
        "stats_total":      "Total de contactos",
        "stats_today":      "Cumplen hoy",
        "stats_week":       "Esta semana",
        "stats_month_sec":  "Próximamente",
        "stats_by_rel":     "Por relación",
        "stats_by_month":   "Distribución por mes",
        "stats_next":       "Próximo cumpleaños",
        "stats_none":       "Sin contactos",
        "stats_days":       "días",
        "mobile_only":      "📱 Función disponible solo en Android",
        "rights":           "Todos los derechos reservados",
        "created_by":       "Creado por",
        "milestone_badge":  "✨ Especial",
        "milestone_popup":  "¡Un año muy especial!",
        "backup_remind_tip": "💾 Recuerda hacer un respaldo de tus contactos",
        "stats_milestones": "Cumpleaños especiales este año",
        "stats_no_milestones": "Sin cumpleaños redondos este año",
        "cal_multi_title":  "Cumpleaños del día",
        "test_popup_btn":      "Probar popup de cumpleaños",
        "test_popup_demo":     "Demo — Pedro (30 años)",
        "set_remind_all_day":  "Recordar todo el día",
        "remind_all_day_on":   "Sí, todo el día",
        "remind_all_day_off":  "Solo una vez por día",
        "birthday_screen_sub": "Hoy es un día especial",
    },
    "en": {
        "app_sub":        "Birthday Reminder",
        "lang_btn":       "ES",
        "nav_home":       "Home",
        "nav_add":        "Add",
        "nav_calendar":   "Calendar",
        "nav_settings":   "Settings",
        "today_title":    "\U0001f382  Today!",
        "week_title":     "\U0001f4c5  This Week",
        "month_title":    "\U0001f5d3  Coming Soon",
        "all_title":      "\U0001f465  All",
        "no_contacts":    "No contacts yet.\nPress + to add one.",
        "add_title":      "New Contact",
        "edit_title":     "Edit Contact",
        "field_name":     "Full name *",
        "field_day":      "Day *",
        "field_month":    "Month *",
        "field_year":     "Year (optional)",
        "field_phone":    "Phone / WhatsApp",
        "field_email":    "Email",
        "field_notes":    "Notes",
        "field_relation": "Relationship",
        "rel_family":     "Family",
        "rel_friend":     "Friend",
        "rel_work":       "Work",
        "rel_other":      "Other",
        "btn_save":       "SAVE",
        "btn_cancel":     "CANCEL",
        "btn_delete":     "DELETE",
        "btn_edit":       "EDIT",
        "btn_whatsapp":   "WhatsApp",
        "search_hint":    "Search by name...",
        "days_left":      "days",
        "today_badge":    "TODAY!",
        "tomorrow_badge": "Tomorrow",
        "years":          "years",
        "calendar_title": "Calendar",
        "settings_title": "Settings",
        "set_theme":      "Theme",
        "set_lang":       "Language / Idioma",
        "set_notif":      "Advance notifications",
        "set_backup":     "Data Backup",
        "btn_export":     "Export JSON",
        "btn_import":     "Import JSON",
        "confirm_delete": "Delete this contact?",
        "confirm_yes":    "Yes, delete",
        "confirm_no":     "No, cancel",
        "popup_title":    "Happy Birthday!",
        "popup_turns":    "Today turns",
        "popup_years":    "years old",
        "popup_close":    "Celebrate!",
        "err_name":       "Name is required",
        "err_date":       "Day and month are required",
        "err_day":        "Invalid day (1-31)",
        "err_month":      "Invalid month (1-12)",
        "about_title":    "About Celebria",
        "filter_all":     "All",
        "filter_fam":     "Family",
        "filter_fri":     "Friends",
        "filter_wor":     "Work",
        "export_ok":      "Exported",
        "import_ok":      "contacts imported",
        "file_not_found": "File not found",
        "same_day":       "Same day",
        "one_day":        "1 day before",
        "three_days":     "3 days before",
        "one_week":       "1 week before",
        "set_notif_hour": "Daily reminder time",
        "alarm_saved":    "Time saved",
        "manual_btn":     "User Manual",
        "back_settings":  "Back to Settings",
        "set_popup":      "Birthday popup",
        "opt_show":       "Show",
        "opt_hide":       "Hide",
        "months": [
            "", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ],
        "days_abbr": ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
        "import_vcf_btn":   "Import from Contacts (.vcf)",
        "import_vcf_title": "Import from Contacts",
        "import_vcf_found": "contacts with birthdays found",
        "import_vcf_none":  "No contacts with birthdays found in this file",
        "import_vcf_do":    "IMPORT SELECTED",
        "import_vcf_all":   "All",
        "import_vcf_clear": "None",
        "import_vcf_ok":    "contacts imported from contacts list",
        "import_vcf_empty": "Select at least one contact",
        "field_photo":      "Photo",
        "photo_add":        "Add photo",
        "photo_change":     "Change photo",
        "photo_remove":     "Remove photo",
        "field_gift":       "Gift note",
        "gift_hint":        "What would they like to receive?",
        "stats_title":      "Quick Statistics",
        "stats_btn":        "Statistics",
        "stats_total":      "Total contacts",
        "stats_today":      "Birthdays today",
        "stats_week":       "This week",
        "stats_month_sec":  "Coming Soon",
        "stats_by_rel":     "By relationship",
        "stats_by_month":   "Birthday distribution by month",
        "stats_next":       "Next birthday",
        "stats_none":       "No contacts yet",
        "stats_days":       "days",
        "mobile_only":      "📱 Feature available on Android only",
        "rights":           "All rights reserved",
        "created_by":       "Created by",
        "milestone_badge":  "✨ Special",
        "milestone_popup":  "A very special year!",
        "backup_remind_tip": "💾 Remember to back up your contacts",
        "stats_milestones": "Milestone birthdays this year",
        "stats_no_milestones": "No milestone birthdays this year",
        "cal_multi_title":  "Birthdays on this day",
        "test_popup_btn":      "Test birthday popup",
        "test_popup_demo":     "Demo — Pedro (30 years)",
        "set_remind_all_day":  "Remind all day",
        "remind_all_day_on":   "Yes, all day",
        "remind_all_day_off":  "Only once a day",
        "birthday_screen_sub": "Today is a special day",
    },
}

LANG: list = ["es"]


def t(key):
    return T[LANG[0]].get(key, key)


def month_name(m):
    months = T[LANG[0]]["months"]
    return months[m] if 1 <= m <= 12 else ""


# ── Birthday utilities ────────────────────────────────────────────────────────
def days_until(day, month):
    today = date.today()
    try:
        bd = date(today.year, month, day)
        if bd < today:
            bd = date(today.year + 1, month, day)
        return (bd - today).days
    except ValueError:
        try:
            d = min(day, 28)
            bd = date(today.year, month, d)
            if bd < today:
                bd = date(today.year + 1, month, d)
            return (bd - today).days
        except Exception:
            return 999


def calc_age(day, month, year):
    if not year:
        return None
    today = date.today()
    age = today.year - year
    if (today.month, today.day) < (month, day):
        age -= 1
    return max(0, age)


REL_ICON      = {"family": "\U0001f46a", "friend": "\U0001f465",
                 "work": "\U0001f4bc", "other": "⭐"}
REL_COLOR_KEY = {"family": "cyan", "friend": "green", "work": "purple", "other": "yellow"}

MILESTONE_AGES = {15, 18, 21, 25, 30, 40, 50, 60, 70, 75, 80, 90, 100}


def rel_icon(rel):  return REL_ICON.get(rel, "⭐")
def rel_color(rel): return C.get(REL_COLOR_KEY.get(rel, "t2"), C["t2"])


# ── DB path ───────────────────────────────────────────────────────────────────
def _get_db_path() -> str:
    storage = os.environ.get("FLET_APP_STORAGE_DATA", "")
    if storage:
        data_dir = Path(storage)
    elif getattr(sys, "frozen", False):
        data_dir = Path(sys.executable).parent
    else:
        data_dir = Path.home() / ".celebria"
    try:
        data_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        import tempfile
        data_dir = Path(tempfile.gettempdir()) / "celebria"
        data_dir.mkdir(parents=True, exist_ok=True)
    return str(data_dir / "celebria.db")


DB_PATH = _get_db_path()


# ── Database ──────────────────────────────────────────────────────────────────
class DB:
    def __init__(self):
        self.conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        self._init()

    def _init(self):
        self.conn.executescript("""
            CREATE TABLE IF NOT EXISTS contacts (
                id        INTEGER PRIMARY KEY AUTOINCREMENT,
                name      TEXT    NOT NULL,
                day       INTEGER NOT NULL,
                month     INTEGER NOT NULL,
                year      INTEGER,
                phone     TEXT    DEFAULT '',
                email     TEXT    DEFAULT '',
                notes     TEXT    DEFAULT '',
                relation  TEXT    DEFAULT 'friend',
                photo     TEXT    DEFAULT '',
                gift_note TEXT    DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT
            );
        """)
        # Migration: add columns to existing installations
        for col, default in [("photo", "''"), ("gift_note", "''")]:
            try:
                self.conn.execute(
                    f"ALTER TABLE contacts ADD COLUMN {col} TEXT DEFAULT {default}"
                )
                self.conn.commit()
            except Exception:
                pass  # column already exists

    def get(self, key, default=""):
        row = self.conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
        return row[0] if row else default

    def set(self, key, value):
        self.conn.execute(
            "INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)", (key, str(value))
        )
        self.conn.commit()

    def all_contacts(self):
        return self.conn.execute(
            "SELECT id,name,day,month,year,phone,email,notes,relation,photo,gift_note "
            "FROM contacts ORDER BY month,day,name"
        ).fetchall()

    def get_contact(self, cid):
        return self.conn.execute(
            "SELECT id,name,day,month,year,phone,email,notes,relation,photo,gift_note "
            "FROM contacts WHERE id=?", (cid,)
        ).fetchone()

    def add(self, name, day, month, year, phone, email, notes, relation,
            photo="", gift_note=""):
        self.conn.execute(
            "INSERT INTO contacts"
            "(name,day,month,year,phone,email,notes,relation,photo,gift_note) "
            "VALUES(?,?,?,?,?,?,?,?,?,?)",
            (name, int(day), int(month), year or None,
             phone, email, notes, relation, photo, gift_note),
        )
        self.conn.commit()

    def update(self, cid, name, day, month, year, phone, email, notes, relation,
               photo="", gift_note=""):
        self.conn.execute(
            "UPDATE contacts "
            "SET name=?,day=?,month=?,year=?,phone=?,email=?,notes=?,"
            "relation=?,photo=?,gift_note=? WHERE id=?",
            (name, int(day), int(month), year or None,
             phone, email, notes, relation, photo, gift_note, cid),
        )
        self.conn.commit()

    def delete(self, cid):
        self.conn.execute("DELETE FROM contacts WHERE id=?", (cid,))
        self.conn.commit()

    def to_json(self):
        rows = self.all_contacts()
        data = [
            {"name": r[1], "day": r[2], "month": r[3], "year": r[4],
             "phone": r[5], "email": r[6], "notes": r[7], "relation": r[8],
             "gift_note": r[10] if len(r) > 10 else ""}
            for r in rows
        ]
        return json.dumps(
            {"app": APP_NAME, "version": APP_VERSION, "contacts": data},
            indent=2, ensure_ascii=False,
        )

    def from_json(self, txt):
        try:
            obj = json.loads(txt)
            items = obj.get("contacts", obj if isinstance(obj, list) else [])
            for c in items:
                self.add(
                    c.get("name", "?"), c.get("day", 1), c.get("month", 1),
                    c.get("year"), c.get("phone", ""), c.get("email", ""),
                    c.get("notes", ""), c.get("relation", "friend"),
                    gift_note=c.get("gift_note", ""),
                )
            return len(items)
        except Exception:
            return -1


# ── Photo storage helper ─────────────────────────────────────────────────────
def _copy_photo(src_path: str) -> str:
    """Copia la imagen al directorio de datos de la app y devuelve la ruta local."""
    import shutil, time as _time
    photos_dir = Path(DB_PATH).parent / "photos"
    try:
        photos_dir.mkdir(parents=True, exist_ok=True)
        ext = Path(src_path).suffix.lower() or ".jpg"
        dest = str(photos_dir / f"p_{int(_time.time() * 1000)}{ext}")
        shutil.copy2(src_path, dest)
        return dest
    except Exception:
        return src_path   # fallback: devuelve el original si no se puede copiar


# ── vCard parser — extrae contactos con cumpleaños de archivos .vcf ──────────
def _parse_vcf(content: str) -> list:
    """Parsea contenido vCard y retorna lista de dicts con cumpleaños."""
    result  = []
    current: dict = {}

    for raw_line in content.splitlines():
        line  = raw_line.strip()
        upper = line.upper()

        if upper == "BEGIN:VCARD":
            current = {}
        elif upper == "END:VCARD":
            d, m = current.get("day"), current.get("month")
            if current.get("name") and d and m and 1 <= m <= 12 and 1 <= d <= 31:
                result.append(current)
            current = {}
        elif upper.startswith("FN:"):
            name = line[3:].strip()
            if name:
                current["name"] = name
        elif upper.startswith("N:") and not current.get("name"):
            parts = line[2:].split(";")
            parts = [p.strip() for p in parts]
            first = parts[1] if len(parts) > 1 else ""
            last  = parts[0] if parts else ""
            name  = f"{first} {last}".strip() if first else last
            if name:
                current["name"] = name
        elif "BDAY" in upper:
            raw = line.split(":")[-1].strip().replace("-", "").replace("/", "")
            try:
                if len(raw) == 8:               # YYYYMMDD
                    yr = int(raw[:4])
                    current["month"] = int(raw[4:6])
                    current["day"]   = int(raw[6:8])
                    current["year"]  = yr if 1900 < yr <= date.today().year else None
                elif len(raw) == 4:             # MMDD (de --MMDD sin guiones)
                    current["month"] = int(raw[:2])
                    current["day"]   = int(raw[2:4])
                    current["year"]  = None
            except ValueError:
                pass
        elif "TEL" in upper and not current.get("phone"):
            phone = line.split(":")[-1].strip()
            if phone:
                current["phone"] = phone

    return result


# ── Birthday WAV (generado en memoria — sin archivos ni HTTP server) ──────────
def _gen_birthday_wav() -> bytes:
    import wave, struct, math, io
    SR = 44100
    def _note(freq, dur, vol=0.68):
        n = int(SR * dur)
        out = []
        for i in range(n):
            t   = i / SR
            env = min(1.0, i / (SR * 0.012)) * max(0.0, 1.0 - (i / n) ** 0.6 * 0.55)
            v   = env * vol * (math.sin(2*math.pi*freq*t)*0.70 +
                               math.sin(4*math.pi*freq*t)*0.20 +
                               math.sin(6*math.pi*freq*t)*0.10)
            out.append(struct.pack('<h', max(-32767, min(32767, int(v * 32767)))))
        return b''.join(out)
    frames = b''.join(_note(f, d) for f, d in [
        (392,0.22),(392,0.12),(440,0.34),(392,0.34),(523,0.34),(494,0.58)
    ]) + b'\x00\x00' * int(SR * 0.08)
    buf = io.BytesIO()
    with wave.open(buf, 'w') as wf:
        wf.setnchannels(1); wf.setsampwidth(2); wf.setframerate(SR)
        wf.writeframes(frames)
    return buf.getvalue()


# ── Help content (bilingual) ──────────────────────────────────────────────────
_HELP_ES = [
    ("\U0001f382", "¿Qué es Celebria?",
     "Celebria es tu recordatorio personal de cumpleaños.\n\n"
     "Guarda los datos de tus contactos y te envía una notificación automática "
     "cada día a la hora que configures — incluso si la app está completamente cerrada."),
    ("➕", "Agregar un contacto",
     "1. Toca + Agregar en la barra inferior.\n"
     "2. Escribe el nombre completo (obligatorio).\n"
     "3. Elige el Día y el Mes con los menús desplegables (obligatorios).\n"
     "   Toca el campo y selecciona el valor de la lista.\n"
     "4. El Año es opcional — selecciónalo del desplegable para que la app\n"
     "   calcule la edad exacta que cumple esa persona.\n"
     "5. Elige la relación: Familia • Amigo/a • Trabajo • Otro\n"
     "6. Teléfono, correo electrónico y notas son opcionales.\n"
     "7. Toca GUARDAR."),
    ("✏", "Editar o eliminar un contacto",
     "• Toca cualquier contacto en la lista para abrir su detalle.\n"
     "• Toca EDITAR (arriba a la derecha) para modificar sus datos.\n"
     "• Dentro del formulario de edición, toca ELIMINAR para borrarlo.\n"
     "• Siempre se pedirá confirmación antes de eliminar."),
    ("\U0001f50d", "Buscar y filtrar contactos",
     "En la pantalla Inicio:\n\n"
     "• Barra de búsqueda: escribe parte del nombre para filtrar en tiempo real.\n"
     "• Botones de categoría: Todos • Familia • Amigos • Trabajo\n\n"
     "Los contactos aparecen agrupados automáticamente:\n"
     "  \U0001f382 ¡Hoy! — cumpleaños de hoy\n"
     "  \U0001f4c5 Esta Semana — próximos 7 días\n"
     "  \U0001f5d3 Próximamente — próximos 8–30 días\n"
     "  \U0001f465 Todos — el resto del año"),
    ("\U0001f514", "Notificaciones automáticas",
     "Celebria revisa los cumpleaños cada vez que abres la app y muestra "
     "un popup con los contactos que cumplen años hoy.\n\n"
     "Para notificaciones en segundo plano sin abrir la app, configura un "
     "recordatorio manual en la app de Alarmas de tu teléfono."),
    ("⚙", "Configurar notificaciones",
     "Ve a Configuración:\n\n"
     "Días de anticipación — elige cuándo quieres el aviso:\n"
     "  Hoy • 1 día antes • 3 días antes • 1 semana antes\n\n"
     "Hora del recordatorio — la hora preferida para el aviso diario:\n"
     "  6:00 · 7:00 · 8:00 · 9:00 · 10:00 · 12:00\n\n"
     "\U0001f382 Popup de cumpleaños — activa o desactiva el aviso visual\n"
     "al abrir la app el día del cumpleaños:\n"
     "  \U0001f382 Mostrar  ·  \U0001f6ab Ocultar"),
    ("\U0001f4c5", "Calendario de cumpleaños",
     "Toca Calendario en la barra inferior.\n\n"
     "• Los días con cumpleaños aparecen resaltados en rosa con \U0001f382.\n"
     "• El día de hoy aparece resaltado en cian.\n"
     "• Navega entre meses con los botones ◄  ►.\n"
     "• Debajo del calendario verás la lista de cumpleaños del mes.\n\n"
     "Toca cualquier día resaltado para ir directamente al detalle\n"
     "del contacto. Si hay varios cumpleaños ese día, se mostrará\n"
     "una lista para que elijas cuál quieres ver.\n\n"
     "También puedes tocar cualquier nombre en la lista inferior\n"
     "del mes para abrir directamente el detalle de ese contacto."),
    ("\U0001f4ac", "Botón de WhatsApp",
     "Si un contacto tiene número de teléfono guardado:\n\n"
     "1. Toca el contacto para abrir su detalle.\n"
     "2. Toca WhatsApp.\n"
     "3. WhatsApp se abrirá directamente en esa conversación.\n\n"
     "Perfecto para enviar un mensaje de felicitación en segundos \U0001f389\n\n"
     "Formato recomendado: incluye el código de país sin el +\n"
     "  República Dominicana: 18095551234\n"
     "  Estados Unidos:       12125551234"),
    ("\U0001f4e4", "Exportar e importar contactos",
     "Ve a Configuración → Respaldo de Datos:\n\n"
     "Exportar JSON: guarda todos tus contactos en Celebria_backup.json "
     "en la carpeta Descargas de tu teléfono.\n\n"
     "Importar JSON: lee el archivo Celebria_backup.json de Descargas "
     "y agrega esos contactos a la app.\n\n"
     "Ideal para copias de seguridad o pasar tus datos a un teléfono nuevo."),
    ("\U0001f4f1", "Importar desde tu Agenda",
     "Si quieres agregar varios contactos que ya tienen cumpleaños en tu teléfono:\n\n"
     "1. En tu app de Contactos, exporta tus contactos a un archivo .vcf "
     "(vCard). El nombre suele ser 'Contacts.vcf' o similar.\n"
     "2. En Celebria, ve a Configuración → Respaldo de Datos → "
     "Importar desde Agenda (.vcf).\n"
     "3. Selecciona el archivo .vcf exportado.\n"
     "4. Celebria encontrará solo los contactos con cumpleaños registrados.\n"
     "5. Marca cuáles quieres importar y toca IMPORTAR SELECCIONADOS.\n\n"
     "Solo se importan contactos que tengan Día y Mes en el archivo.\n"
     "Si el año está incluido, la app calculará la edad automáticamente."),
    ("\U0001f310", "Cambiar el idioma",
     "Toca el botón EN que aparece en la esquina superior derecha "
     "de cualquier pantalla.\n\n"
     "El idioma cambia instantáneamente en toda la app y se recuerda "
     "la próxima vez que la abras.\n\n"
     "Para volver al español, toca ES en la misma posición."),
    ("\U0001f504", "Cómo actualizar la app",
     "Celebria revisa automáticamente si hay versión nueva cada vez que\n"
     "la abres (necesita internet). Si hay actualización, aparece un aviso\n"
     "en la pantalla de Inicio unos segundos después de abrir la app.\n\n"
     "── Paso a paso para actualizar ─────────────────────\n\n"
     "1. Toca el botón  ⬇ Descargar  en el aviso.\n"
     "   Se abrirá Chrome con una página de descarga.\n\n"
     "2. En esa página busca el archivo que dice\n"
     "   'Celebria-vX.X.X.apk'  y tócalo.\n"
     "   (Está listado como un archivo adjunto en la página.)\n\n"
     "3. Chrome descargará el archivo.\n"
     "   Verás una barra de progreso abajo de la pantalla.\n"
     "   Espera a que diga  'Listo'  o  'Abrir'.\n\n"
     "4. Toca  'Abrir'  (o ve a Descargas y toca el archivo .apk).\n\n"
     "5. Android te preguntará si quieres instalar la app.\n"
     "   Toca  INSTALAR.\n\n"
     "6. Si Android dice 'No se permite instalar de esta fuente':\n"
     "   • Toca  Configuración  en ese aviso.\n"
     "   • Activa  'Permitir de esta fuente'.\n"
     "   • Regresa y toca  INSTALAR  nuevamente.\n"
     "   (Esto es normal — la app no está en la Play Store.)\n\n"
     "7. Al terminar toca  ABRIR  para usar la versión nueva.\n\n"
     "── Si tomas 'Ahora no' ──────────────────────────────\n"
     "La próxima vez que abras Celebria con internet, el aviso\n"
     "volverá a aparecer para que puedas actualizar.\n\n"
     "── Actualización obligatoria ────────────────────────\n"
     "Si el botón aparece en rojo y no hay opción 'Ahora no',\n"
     "es una actualización requerida. Debes instalarla para\n"
     "continuar usando la app.\n\n"
     "Si no ves ningún aviso, ya tienes la versión más reciente."),
    ("\U0001f4f8", "Foto de contacto",
     "Cada contacto puede tener una foto personalizada:\n\n"
     "1. Abre el formulario de Agregar o Editar contacto.\n"
     "2. En la sección Foto toca Agregar foto.\n"
     "3. Selecciona cualquier imagen de tu galería o almacenamiento.\n"
     "4. La foto se guarda localmente — sin subir a ningún servidor.\n\n"
     "Si no hay foto, se muestra un círculo con la inicial del nombre "
     "en el color de la relación (cian=Familia, verde=Amigo, etc.).\n\n"
     "Toca Quitar foto en el formulario para eliminarla."),
    ("\U0001f381", "Nota de regalo",
     "Guarda ideas de regalo para cada contacto:\n\n"
     "1. Abre el formulario de Agregar o Editar contacto.\n"
     "2. En el campo Nota de regalo escribe lo que se te ocurra.\n"
     "   Ejemplo: 'Le gusta el café colombiano' o 'Talla M de camiseta'.\n\n"
     "La nota aparece en el detalle del contacto con el ícono 🎁.\n"
     "No hay límite de caracteres — escribe todo lo que necesites recordar."),
    ("\U0001f4ca", "Estadísticas rápidas",
     "Ve a Configuración → Estadísticas para ver un resumen:\n\n"
     "• Total de contactos registrados\n"
     "• Cuántos cumplen hoy, esta semana y este mes\n"
     "• El próximo cumpleaños con los días que faltan\n"
     "• Distribución por tipo de relación (Familia, Amigos, Trabajo, Otro)\n"
     "• Gráfica de barras con la distribución de cumpleaños por mes\n"
     "• ✨ Cumpleaños especiales — contactos que cumplen 15, 18, 21, 25,\n"
     "  30, 40, 50, 60, 70, 75, 80, 90 o 100 años este año\n\n"
     "El mes actual aparece resaltado en cian."),
    ("\U0001f4a1", "Consejos útiles",
     "• Agrega el año de nacimiento para ver la edad exacta que cumple cada persona.\n\n"
     "• El color del borde de cada tarjeta indica la urgencia:\n"
     "   Rosa neón = HOY  •  Amarillo = esta semana  •  Cian = próximos 30 días\n\n"
     "• ✨ Borde amarillo doble = cumpleaños redondo este año (15, 18, 21, 25, 30...)\n\n"
     "• Toca un día rosado en el Calendario para ir directo al detalle del contacto.\n\n"
     "• Agrega notas como '¿Le gusta el chocolate?' para recordar qué regalarle.\n\n"
     "• Usa la categoría Trabajo para cumpleaños de colegas.\n\n"
     "• El archivo JSON de respaldo es texto plano — puedes abrirlo en cualquier editor."),
]

_HELP_EN = [
    ("\U0001f382", "What is Celebria?",
     "Celebria is your personal birthday reminder.\n\n"
     "Store your contacts' birthdays and receive a birthday popup every time "
     "you open the app — never miss an important date again."),
    ("➕", "Adding a contact",
     "1. Tap + Add in the bottom bar.\n"
     "2. Enter the full name (required).\n"
     "3. Choose the birthday Day and Month from the dropdown menus (required).\n"
     "   Tap the field and pick the value from the list.\n"
     "4. Year is optional — select it from the dropdown so the app can\n"
     "   calculate the exact age the person is turning.\n"
     "5. Choose the relationship: Family • Friend • Work • Other\n"
     "6. Phone, email, and notes are optional.\n"
     "7. Tap SAVE."),
    ("✏", "Editing or deleting a contact",
     "• Tap any contact in the list to open their detail view.\n"
     "• Tap EDIT (top right) to modify their information.\n"
     "• Inside the edit form, tap DELETE to remove them.\n"
     "• A confirmation prompt always appears before deleting."),
    ("\U0001f50d", "Search and filter",
     "On the Home screen:\n\n"
     "• Search bar: type part of a name to filter in real time.\n"
     "• Category buttons: All • Family • Friends • Work\n\n"
     "Contacts are automatically grouped by:\n"
     "  \U0001f382 Today! — today's birthdays\n"
     "  \U0001f4c5 This Week — next 7 days\n"
     "  \U0001f5d3 Coming Soon — next 8–30 days\n"
     "  \U0001f465 All — the rest of the year"),
    ("\U0001f514", "Automatic notifications",
     "Celebria checks birthdays every time you open the app and shows "
     "a popup for any contacts whose birthday is today.\n\n"
     "For background reminders without opening the app, set a manual "
     "reminder in your phone's Clock or Alarm app."),
    ("⚙", "Configuring notifications",
     "Go to Settings:\n\n"
     "Advance days — choose when to be notified:\n"
     "  Same day • 1 day before • 3 days before • 1 week before\n\n"
     "Reminder time — your preferred daily reminder hour:\n"
     "  6:00 · 7:00 · 8:00 · 9:00 · 10:00 · 12:00\n\n"
     "\U0001f382 Birthday popup — enable or disable the visual alert\n"
     "shown when you open the app on someone's birthday:\n"
     "  \U0001f382 Show  ·  \U0001f6ab Hide"),
    ("\U0001f4c5", "Birthday calendar",
     "Tap Calendar in the bottom bar.\n\n"
     "• Days with birthdays are highlighted in pink with \U0001f382.\n"
     "• Today is highlighted in cyan.\n"
     "• Use ◄  ► to navigate between months.\n"
     "• Below the calendar, see the complete list of birthdays for the month.\n\n"
     "Tap any highlighted day to go directly to that contact's detail view.\n"
     "If multiple contacts share the day, a list will appear so you can\n"
     "pick which one to open.\n\n"
     "You can also tap any contact name in the list below the calendar\n"
     "to open their detail view directly."),
    ("\U0001f4ac", "WhatsApp button",
     "If a contact has a phone number saved:\n\n"
     "1. Tap the contact to open their detail view.\n"
     "2. Tap WhatsApp.\n"
     "3. WhatsApp will open directly in that conversation.\n\n"
     "Perfect for sending a quick birthday message in seconds \U0001f389\n\n"
     "Recommended format: include the country code without the +\n"
     "  Dominican Republic: 18095551234\n"
     "  United States:      12125551234"),
    ("\U0001f4e4", "Exporting and importing contacts",
     "Go to Settings → Data Backup:\n\n"
     "Export JSON: saves all your contacts to Celebria_backup.json "
     "in your phone's Downloads folder.\n\n"
     "Import JSON: reads Celebria_backup.json from your Downloads folder "
     "and adds those contacts to the app.\n\n"
     "Ideal for backups or transferring your data to a new phone."),
    ("\U0001f4f1", "Import from your Contacts",
     "To quickly add contacts that already have birthdays saved on your phone:\n\n"
     "1. In your Contacts app, export your contacts to a .vcf (vCard) file. "
     "It is usually named 'Contacts.vcf' or similar.\n"
     "2. In Celebria, go to Settings → Data Backup → "
     "Import from Contacts (.vcf).\n"
     "3. Select the exported .vcf file.\n"
     "4. Celebria will find only contacts that have a birthday registered.\n"
     "5. Check which ones you want and tap IMPORT SELECTED.\n\n"
     "Only contacts with a birthday Day and Month in the file are imported.\n"
     "If the year is included, the app will calculate the age automatically."),
    ("\U0001f310", "Changing the language",
     "Tap the ES button in the top-right corner of any screen.\n\n"
     "The language changes instantly throughout the app and is remembered "
     "the next time you open it.\n\n"
     "To switch back to English, tap EN in the same position."),
    ("\U0001f504", "How to update the app",
     "Celebria automatically checks for a new version every time you open\n"
     "it (requires internet). If an update is available, a notice appears\n"
     "on the Home screen a few seconds after opening the app.\n\n"
     "── Step-by-step update guide ───────────────────────\n\n"
     "1. Tap the  ⬇ Download  button in the notice.\n"
     "   Chrome will open a download page.\n\n"
     "2. On that page, look for the file named\n"
     "   'Celebria-vX.X.X.apk'  and tap it.\n"
     "   (It is listed as an attached file on the page.)\n\n"
     "3. Chrome will download the file.\n"
     "   A progress bar will appear at the bottom of the screen.\n"
     "   Wait until it says  'Done'  or  'Open'.\n\n"
     "4. Tap  'Open'  (or go to Downloads and tap the .apk file).\n\n"
     "5. Android will ask if you want to install the app.\n"
     "   Tap  INSTALL.\n\n"
     "6. If Android says 'Install blocked' or 'Unknown source':\n"
     "   • Tap  Settings  in that prompt.\n"
     "   • Enable  'Allow from this source'.\n"
     "   • Go back and tap  INSTALL  again.\n"
     "   (This is normal — the app is not on the Play Store.)\n\n"
     "7. When done, tap  OPEN  to start using the new version.\n\n"
     "── If you tap 'Not now' ────────────────────────────\n"
     "The next time you open Celebria with internet, the notice\n"
     "will appear again so you can update.\n\n"
     "── Mandatory update ────────────────────────────────\n"
     "If the button appears in red and there is no 'Not now' option,\n"
     "the update is required. You must install it to keep using the app.\n\n"
     "If no notice appears, you already have the latest version."),
    ("\U0001f4f8", "Contact photo",
     "Each contact can have a personalized photo:\n\n"
     "1. Open the Add or Edit contact form.\n"
     "2. In the Photo section, tap Add photo.\n"
     "3. Select any image from your gallery or storage.\n"
     "4. The photo is saved locally — never uploaded to any server.\n\n"
     "Without a photo, a colored circle with the name's initial is shown "
     "in the relationship color (cyan=Family, green=Friend, etc.).\n\n"
     "Tap Remove photo in the form to clear it."),
    ("\U0001f381", "Gift note",
     "Save gift ideas for each contact:\n\n"
     "1. Open the Add or Edit contact form.\n"
     "2. In the Gift note field, write whatever comes to mind.\n"
     "   Example: 'Loves Colombian coffee' or 'Size M t-shirt'.\n\n"
     "The note appears in the contact detail view with the 🎁 icon.\n"
     "No character limit — write as much as you need to remember."),
    ("\U0001f4ca", "Quick Statistics",
     "Go to Settings → Statistics for a summary:\n\n"
     "• Total contacts registered\n"
     "• How many have birthdays today, this week, and this month\n"
     "• The next upcoming birthday with days remaining\n"
     "• Breakdown by relationship type (Family, Friends, Work, Other)\n"
     "• Bar chart of birthday distribution across months\n"
     "• ✨ Milestone birthdays — contacts turning 15, 18, 21, 25, 30,\n"
     "  40, 50, 60, 70, 75, 80, 90 or 100 this year\n\n"
     "The current month is highlighted in cyan."),
    ("\U0001f4a1", "Useful tips",
     "• Add the birth year to see the exact age each person is turning.\n\n"
     "• The card border color shows urgency:\n"
     "   Neon pink = TODAY  •  Yellow = this week  •  Cyan = next 30 days\n\n"
     "• ✨ Double amber border = milestone birthday this year (15, 18, 21, 25, 30...)\n\n"
     "• Tap a pink day in the Calendar to jump straight to that contact's detail.\n\n"
     "• Add notes like 'Likes chocolate?' to remember gift ideas.\n\n"
     "• Use the Work category for colleagues to keep them separate from friends.\n\n"
     "• The JSON backup file is plain text — you can open it in any editor."),
]


# ── Main ──────────────────────────────────────────────────────────────────────
def main(page: ft.Page):
    page.title = f"{APP_NAME} v{APP_VERSION}"
    page.bgcolor = C["bg"]
    page.padding = 0
    try:
        page.window.width  = 400
        page.window.height = 720
    except Exception:
        pass

    db = DB()
    LANG[0]  = db.get("lang",  "es")
    THEME[0] = db.get("theme", "dark")
    _apply_theme()
    page.bgcolor    = C["bg"]
    page.theme_mode = ft.ThemeMode.LIGHT if THEME[0] == "light" else ft.ThemeMode.DARK

    # ── Mutable state ─────────────────────────────────────────────────────
    state = {
        "screen":             "home",
        "edit_id":            None,
        "detail_id":          None,
        "cal_year":           date.today().year,
        "cal_month":          date.today().month,
        "search":             "",
        "filter":             "all",
        "rel":                "friend",
        "_rel_for":           None,   # tracks which edit_id loaded rel from DB
        "photo":              "",     # foto temporal durante add/edit
        "_birthday_contacts": [],     # contactos que cumplen hoy (para pantalla)
    }

    # ── Avatar helper ─────────────────────────────────────────────────────
    def _avatar(photo, name, relation, size=44):
        """Círculo con foto o con inicial del nombre según disponibilidad."""
        r = size // 2
        if photo and os.path.exists(photo):
            return ft.Image(
                src=photo, width=size, height=size,
                border_radius=r, fit=ft.BoxFit.COVER,
            )
        initial = (name[0].upper() if name else "?")
        return ft.Container(
            width=size, height=size, border_radius=r,
            bgcolor=rel_color(relation),
            content=ft.Text(
                initial, size=int(size / 2.4),
                color="#ffffff", weight=ft.FontWeight.BOLD,
                text_align=ft.TextAlign.CENTER,
            ),
            alignment=ft.Alignment.CENTER,
        )

    # ── Dialog helpers ────────────────────────────────────────────────────
    # page.show_dialog(AlertDialog) falla silenciosamente en Flet 0.85.1
    # Android. La única forma confiable es overlay directo + dlg.open = True.
    # NUNCA usar page.show_dialog() para AlertDialog — solo funciona para SnackBar.
    _dlg_stack: list = []

    def _open_dlg(dlg):
        """Muestra un AlertDialog modal via overlay — confiable en Flet 0.85.1."""
        try:
            page.overlay.append(dlg)
            dlg.open = True
            _dlg_stack.append(dlg)
            page.update()
        except Exception as _e:
            _toast(f"dlg open error: {_e}")

    def _close_dlg():
        """Cierra el último AlertDialog abierto con _open_dlg."""
        if _dlg_stack:
            d = _dlg_stack.pop()
            try:
                d.open = False
                page.update()   # primero: Flutter recibe open=False y hace pop del navigator
            except Exception:
                pass
            try:
                if d in page.overlay:
                    page.overlay.remove(d)
            except Exception:
                pass

    # ── Border helper (same pattern as ElBartenderMovil) ─────────────────
    def _bdr(width, color):
        s = ft.border.BorderSide(width, color)
        return ft.border.Border(top=s, right=s, bottom=s, left=s)

    # ── UI helpers ────────────────────────────────────────────────────────
    def _card(content, border_color=None, padding=16, expand=False):
        return ft.Container(
            content=content,
            bgcolor=C["card"],
            border_radius=12,
            border=_bdr(1, border_color or C["border"]),
            padding=padding,
            expand=expand,
        )

    # FIX: Container-based button — no ft.Button, no dict bgcolor
    def _btn(label, accent, on_click=None, expand=False):
        return ft.Container(
            content=ft.Text(
                label,
                color="#ffffff",
                size=13,
                weight=ft.FontWeight.W_600,
                text_align=ft.TextAlign.CENTER,
            ),
            bgcolor=accent,
            border_radius=10,
            padding=ft.Padding(left=14, top=10, right=14, bottom=10),
            on_click=on_click,
            ink=True,
            expand=expand,
            alignment=ft.Alignment.CENTER,
        )

    # FIX: removed text_style= parameter (may not exist in 0.85.1)
    def _field(label, value="", hint="", multiline=False,
               keyboard_type=ft.KeyboardType.TEXT):
        tf = ft.TextField(
            value=value,
            hint_text=hint,
            multiline=multiline,
            min_lines=3 if multiline else 1,
            max_lines=5 if multiline else 1,
            keyboard_type=keyboard_type,
            bgcolor=C["bg3"],
            border_color=C["border"],
            focused_border_color=C["cyan"],
            color=C["t1"],
            hint_style=ft.TextStyle(color=C["t3"]),
            border_radius=10,
            content_padding=ft.Padding(left=12, top=10, right=12, bottom=10),
        )
        return ft.Column([
            ft.Text(label, size=11, color=C["t2"], weight=ft.FontWeight.W_600),
            tf,
        ], spacing=4), tf

    def _sec(text):
        return ft.Text(text, size=12, color=C["cyan"], weight=ft.FontWeight.BOLD)

    def _footer():
        # Neon orange — vivo en oscuro, ambar oscuro en claro
        footer_color = "#ff8800" if THEME[0] == "dark" else "#cc5500"
        cr = f"{t('created_by')}: {APP_AUTHOR}   ·   {t('rights')}   ©{APP_YEAR}"
        return ft.Text(
            cr, size=10, color=footer_color,
            text_align=ft.TextAlign.CENTER,
        )

    def _opt_btn(label, active, on_click_fn, expand=True):
        return ft.Container(
            content=ft.Text(
                label, size=11,
                color=C["cyan"] if active else C["t3"],
                text_align=ft.TextAlign.CENTER,
                weight=ft.FontWeight.W_600,
            ),
            bgcolor=C["cyandim"] if active else C["bg3"],
            border_radius=8,
            border=_bdr(1, C["cyan"] if active else C["border"]),
            padding=ft.Padding(left=8, top=10, right=8, bottom=10),
            expand=expand,
            on_click=on_click_fn,
            ink=True,
        )

    def _contact_card(row, on_click=None):
        cid, name, day, month, year, phone, email, notes, relation = row[:9]
        photo = row[9] if len(row) > 9 else ""
        d_left = days_until(day, month)
        age    = calc_age(day, month, year)
        rc     = rel_color(relation)

        # Milestone detection: age turning THIS calendar year
        _this_year = date.today().year
        _age_this_year = (_this_year - year) if year else None
        is_milestone = (_age_this_year in MILESTONE_AGES) if _age_this_year is not None else False

        if d_left == 0:
            accent = C["pink"]; bdr_w = 2
        elif d_left <= 7:
            accent = C["yellow"]; bdr_w = 1
        else:
            accent = C["cyan"]; bdr_w = 1
        # Milestone overrides border to amber with thicker stroke
        if is_milestone:
            accent = C["yellow"]; bdr_w = 2
        bg = C["card"]  # same background for all — only border differs

        if d_left == 0:
            badge_txt = f"\U0001f389\n{t('today_badge')}"
            badge_col = C["pink"]
        elif d_left == 1:
            badge_txt = f"\U0001f305\n{t('tomorrow_badge')}"
            badge_col = C["yellow"]
        else:
            badge_txt = f"{d_left}\n{t('days_left')}"
            badge_col = accent
        if is_milestone:
            badge_txt = badge_txt + "\n✨"

        ds = f"{day} {month_name(month)}"
        if year: ds += f" {year}"
        if age is not None: ds += f"  •  {age} {t('years')}"

        return ft.Container(
            content=ft.Row([
                _avatar(photo, name, relation, size=44),
                ft.Column([
                    # FIX: max_lines=1 + overflow instead of no_wrap=True
                    ft.Text(name, size=14, color=rc, weight=ft.FontWeight.BOLD,
                            max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                    ft.Text(ds, size=11, color=C["t3"]),
                ], expand=True, spacing=2),
                ft.Container(
                    content=ft.Text(
                        badge_txt, size=10, color=badge_col,
                        text_align=ft.TextAlign.CENTER,
                        weight=ft.FontWeight.BOLD,
                    ),
                    width=56,
                    alignment=ft.Alignment.CENTER,
                ),
            ], vertical_alignment=ft.CrossAxisAlignment.CENTER),
            bgcolor=bg,
            border_radius=12,
            border=_bdr(bdr_w, accent),
            padding=ft.Padding(left=10, top=8, right=10, bottom=8),
            on_click=(lambda e, c=cid: on_click(c)) if on_click else None,
            ink=bool(on_click),
        )

    # ── Navigation bar & app bar ──────────────────────────────────────────
    NAV_SCREENS = ["home", "add", "calendar", "settings"]
    NAV_IDX = {s: i for i, s in enumerate(NAV_SCREENS)}

    def _nav_bar(active):
        def on_nav(e):
            navigate(NAV_SCREENS[e.control.selected_index])
        return ft.NavigationBar(
            selected_index=NAV_IDX.get(active, 0),
            on_change=on_nav,
            bgcolor=C["bg2"],
            indicator_color=C["cyandim"],
            destinations=[
                ft.NavigationBarDestination(
                    icon=ft.Icons.HOME_OUTLINED,
                    selected_icon=ft.Icons.HOME,
                    label=t("nav_home"),
                ),
                ft.NavigationBarDestination(
                    icon=ft.Icons.ADD_CIRCLE_OUTLINE,
                    selected_icon=ft.Icons.ADD_CIRCLE,
                    label=t("nav_add"),
                ),
                ft.NavigationBarDestination(
                    icon=ft.Icons.CALENDAR_MONTH_OUTLINED,
                    selected_icon=ft.Icons.CALENDAR_MONTH,
                    label=t("nav_calendar"),
                ),
                ft.NavigationBarDestination(
                    icon=ft.Icons.SETTINGS_OUTLINED,
                    selected_icon=ft.Icons.SETTINGS,
                    label=t("nav_settings"),
                ),
            ],
        )

    # FIX: only set leading_width when leading is provided
    def _appbar(title, leading=None, actions=None):
        bar = ft.AppBar(
            title=ft.Text(
                title, color=C["cyan"],
                weight=ft.FontWeight.BOLD, size=18,
            ),
            bgcolor=C["bg2"],
            leading=leading,
            actions=actions or [],
        )
        if leading is not None:
            bar.leading_width = 44
        return bar

    def _std_actions():
        return [
            ft.IconButton(
                icon=ft.Icons.HELP_OUTLINE,
                icon_color=C["cyan"],
                on_click=lambda e: navigate("help"),
                tooltip="Ayuda / Help",
            ),
            ft.TextButton(
                t("lang_btn"),
                on_click=lambda e: _flip_lang(),
                style=ft.ButtonStyle(color=C["cyan"]),
            ),
            ft.IconButton(
                icon=ft.Icons.LIGHT_MODE if THEME[0] == "dark"
                     else ft.Icons.DARK_MODE,
                icon_color=C["yellow"],
                on_click=lambda e: _toggle_theme(),
                tooltip="Toggle theme",
            ),
        ]

    # ── State mutators ────────────────────────────────────────────────────
    def navigate(scr):
        state["screen"] = scr
        render()

    def _flip_lang():
        LANG[0] = "en" if LANG[0] == "es" else "es"
        db.set("lang", LANG[0])
        render()

    def _toggle_theme():
        THEME[0] = "light" if THEME[0] == "dark" else "dark"
        db.set("theme", THEME[0])
        _apply_theme()
        page.bgcolor    = C["bg"]
        page.theme_mode = ft.ThemeMode.LIGHT if THEME[0] == "light" else ft.ThemeMode.DARK
        render()

    def _toast(msg):
        # En Flet 0.85.1, SnackBar es DialogControl → page.show_dialog()
        page.show_dialog(ft.SnackBar(
            content=ft.Text(msg, color=C["t1"]),
            bgcolor=C["bg2"],
        ))

    def _desktop_backup_path(filename):
        """Ruta para backup en desktop (~/.celebria/filename)."""
        p = Path.home() / ".celebria"
        p.mkdir(parents=True, exist_ok=True)
        return str(p / filename)

    # ── Master render ─────────────────────────────────────────────────────
    # FIX: reset appbar/navbar first; wrap in try/except to show errors on screen
    def render():
        page.controls.clear()
        page.appbar = None
        page.navigation_bar = None
        # Cerrar cualquier AlertDialog que haya quedado abierto en overlay
        for _od in list(page.overlay):
            if isinstance(_od, ft.AlertDialog):
                try: _od.open = False
                except Exception: pass
                try: page.overlay.remove(_od)
                except Exception: pass
        _dlg_stack.clear()
        page.bgcolor    = C["bg"]
        page.theme_mode = ft.ThemeMode.LIGHT if THEME[0] == "light" else ft.ThemeMode.DARK
        scr = state["screen"]
        try:
            if   scr == "home":     _show_home()
            elif scr == "add":      _show_add()
            elif scr == "detail":   _show_detail()
            elif scr == "calendar": _show_calendar()
            elif scr == "settings": _show_settings()
            elif scr == "help":     _show_help()
            elif scr == "stats":    _show_stats()
            elif scr == "birthday": _show_birthday()
        except Exception:
            import traceback
            err = traceback.format_exc()
            page.add(ft.Column(
                controls=[
                    ft.Text("ERROR — toca para copiar", color=C["red"],
                            size=14, weight=ft.FontWeight.BOLD),
                    ft.Text(err, color=C["t1"], size=10, selectable=True),
                ],
                scroll=ft.ScrollMode.AUTO,
                expand=True,
            ))

    # ─────────────────────────────────────────────────────────────────────
    # HOME
    # FIX: single page.add() call; Column(expand=True) + ListView(expand=True)
    # ─────────────────────────────────────────────────────────────────────
    def _show_home():
        page.appbar         = _appbar(f"\U0001f382  {APP_NAME}  v{APP_VERSION}", actions=_std_actions())
        page.navigation_bar = _nav_bar("home")

        def open_contact(cid):
            state["detail_id"] = cid
            navigate("detail")

        # ── Construir items de lista sin tocar el TextField ────────────────
        def _make_list_items():
            rows = db.all_contacts()
            if state["filter"] != "all":
                rows = [c for c in rows if c[8] == state["filter"]]
            if state["search"]:
                q = state["search"].lower()
                rows = [c for c in rows if q in c[1].lower()]

            items = []
            if not rows:
                items.append(ft.Container(
                    content=ft.Text(
                        t("no_contacts"), color=C["t2"], size=14,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    alignment=ft.Alignment.CENTER,
                    height=140,
                ))
            else:
                buckets = [
                    ("today_title",  [c for c in rows if days_until(c[2], c[3]) == 0]),
                    ("week_title",   [c for c in rows if 1 <= days_until(c[2], c[3]) <= 7]),
                    ("month_title",  [c for c in rows if 8 <= days_until(c[2], c[3]) <= 30]),
                    ("all_title",    [c for c in rows if days_until(c[2], c[3]) > 30]),
                ]
                for sec_key, bucket in buckets:
                    if bucket:
                        items.append(_sec(t(sec_key)))
                        for r in bucket:
                            items.append(_contact_card(r, on_click=open_contact))
            items += [_footer(), ft.Container(height=8)]
            return items

        # on_search: actualiza solo la lista — NO llama render(),
        # así el TextField no se destruye y el teclado permanece abierto.
        def on_search(e):
            state["search"] = e.control.value
            lv.controls = _make_list_items()
            page.update()

        def set_filter(fv):
            state["filter"] = fv
            render()   # OK: el usuario presionó un botón, no está escribiendo

        filter_btns = ft.Row(
            controls=[
                ft.Container(
                    content=ft.Text(
                        t(fk), size=11, text_align=ft.TextAlign.CENTER,
                        color=C["cyan"] if state["filter"] == fv else C["t3"],
                    ),
                    bgcolor=C["cyandim"] if state["filter"] == fv else C["bg3"],
                    border_radius=20,
                    padding=ft.Padding(left=12, top=6, right=12, bottom=6),
                    on_click=lambda e, v=fv: set_filter(v),
                    ink=True,
                )
                for fk, fv in [
                    ("filter_all", "all"), ("filter_fam", "family"),
                    ("filter_fri", "friend"), ("filter_wor", "work"),
                ]
            ],
            scroll=ft.ScrollMode.AUTO,
        )

        search_tf = ft.TextField(
            hint_text=t("search_hint"),
            value=state["search"],
            bgcolor=C["bg3"],
            border_color=C["border"],
            focused_border_color=C["cyan"],
            color=C["t1"],
            hint_style=ft.TextStyle(color=C["t3"]),
            border_radius=20,
            content_padding=ft.Padding(left=16, top=8, right=16, bottom=8),
            on_change=on_search,
        )

        lv = ft.ListView(
            controls=_make_list_items(),
            expand=True,
            spacing=6,
            padding=ft.Padding(left=12, top=4, right=12, bottom=8),
        )

        page.add(ft.Column(
            controls=[
                ft.Container(
                    content=ft.Column([search_tf, filter_btns], spacing=4),
                    padding=ft.Padding(left=12, top=8, right=12, bottom=4),
                ),
                lv,
            ],
            expand=True,
            spacing=0,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # ADD / EDIT
    # FIX: single page.add() with Column(expand=True, scroll=AUTO)
    # ─────────────────────────────────────────────────────────────────────
    def _show_add():
        editing = state["edit_id"] is not None
        row = db.get_contact(state["edit_id"]) if editing else None

        if editing and row:
            _, nv, dv, mv, yv, pv, ev, ov, relation = row[:9]
            photo_db    = row[9]  if len(row) > 9  else ""
            gift_note_v = row[10] if len(row) > 10 else ""
            # Solo cargar del DB la primera vez que se entra a este edit_id.
            # En re-renders (al pulsar un botón de relación) NO sobreescribir,
            # para que el cambio del usuario se mantenga.
            if state["_rel_for"] != state["edit_id"]:
                state["rel"]   = relation
                state["photo"] = photo_db
                state["_rel_for"] = state["edit_id"]
        else:
            nv = dv = mv = yv = pv = ev = ov = gift_note_v = ""
            relation = state.get("rel", "friend")

        page.appbar = _appbar(
            t("edit_title") if editing else t("add_title"),
            actions=_std_actions(),
        )
        page.navigation_bar = _nav_bar("add")

        (col_name,      tf_name)      = _field(t("field_name"),  str(nv or ""), t("field_name"))
        (col_phone,     tf_phone)     = _field(t("field_phone"), str(pv or ""), "+1-809-...",
                                               keyboard_type=ft.KeyboardType.PHONE)
        (col_email,     tf_email)     = _field(t("field_email"), str(ev or ""), "email@...",
                                               keyboard_type=ft.KeyboardType.EMAIL)
        (col_notes,     tf_notes)     = _field(t("field_notes"), str(ov or ""), "...", multiline=True)
        (col_gift_note, tf_gift_note) = _field(t("field_gift"),  str(gift_note_v or ""),
                                               t("gift_hint"), multiline=True)

        _dd_style = dict(
            bgcolor=C["bg3"],
            border_color=C["border"],
            focused_border_color=C["cyan"],
            color=C["t1"],
        )

        # Day dropdown (1–31)
        dd_day = ft.Dropdown(
            value=str(dv) if dv else None,
            hint_text="DD",
            options=[ft.dropdown.Option(str(i), str(i)) for i in range(1, 32)],
            **_dd_style,
        )
        col_day = ft.Column([
            ft.Text(t("field_day"), size=11, color=C["t2"], weight=ft.FontWeight.W_600),
            dd_day,
        ], spacing=4, expand=True)

        # Month dropdown (name list from current language)
        dd_month = ft.Dropdown(
            value=str(mv) if mv else None,
            hint_text="MM",
            options=[
                ft.dropdown.Option(str(i), month_name(i))
                for i in range(1, 13)
            ],
            **_dd_style,
        )
        col_month = ft.Column([
            ft.Text(t("field_month"), size=11, color=C["t2"], weight=ft.FontWeight.W_600),
            dd_month,
        ], spacing=4, expand=True)

        # Year dropdown (current year → 1920, optional)
        _cy = date.today().year
        dd_year = ft.Dropdown(
            value=str(yv) if yv else None,
            hint_text=t("field_year"),
            options=(
                [ft.dropdown.Option("", f"— {t('field_year')} —")] +
                [ft.dropdown.Option(str(y), str(y)) for y in range(_cy, 1919, -1)]
            ),
            **_dd_style,
        )
        col_year = ft.Column([
            ft.Text(t("field_year"), size=11, color=C["t2"], weight=ft.FontWeight.W_600),
            dd_year,
        ], spacing=4, expand=True)

        err_lbl = ft.Text("", color=C["red"], size=12)

        # ── Bloque de foto ───────────────────────────────────────────────
        photo_lbl = ft.Text(t("field_photo"), size=11, color=C["t2"],
                            weight=ft.FontWeight.W_600)
        _cur_photo = state["photo"]   # foto activa en este formulario

        # El avatar se construye a partir del photo_container mutable
        _photo_ctrl = [_avatar(_cur_photo, (nv or "?"), state.get("rel", "friend"), size=70)]

        def _refresh_photo_display():
            photo_wrap.content = _photo_ctrl[0]
            try:
                photo_wrap.update()
            except Exception:
                page.update()

        photo_wrap = ft.Container(
            content=_photo_ctrl[0],
            alignment=ft.Alignment.CENTER,
        )

        async def pick_photo(e):
            if not _is_android:
                _toast(t("mobile_only"))
                return
            files = await img_picker.pick_files(
                file_type=ft.FilePickerFileType.IMAGE,
                allow_multiple=False,
                with_data=True,   # bytes es más confiable que path en Android
            )
            if not files:
                return
            try:
                import time as _time
                f = files[0]
                photos_dir = Path(DB_PATH).parent / "photos"
                photos_dir.mkdir(parents=True, exist_ok=True)
                ext = Path(f.name).suffix.lower() if f.name else ".jpg"
                dest = str(photos_dir / f"p_{int(_time.time()*1000)}{ext or '.jpg'}")
                if f.bytes:
                    # Guardar bytes directamente (siempre disponible en Android)
                    with open(dest, "wb") as fh:
                        fh.write(f.bytes)
                elif f.path:
                    import shutil as _shutil
                    _shutil.copy2(f.path, dest)
                else:
                    _toast("Error: no se pudo leer la imagen")
                    return
                state["photo"] = dest
                _photo_ctrl[0] = _avatar(dest, tf_name.value or "?",
                                         state.get("rel", "friend"), size=70)
                _refresh_photo_display()
            except Exception as ex:
                _toast(f"Error: {ex}")

        def remove_photo(e):
            state["photo"] = ""
            _photo_ctrl[0] = _avatar("", tf_name.value or "?",
                                     state.get("rel", "friend"), size=70)
            _refresh_photo_display()

        photo_btns = ft.Row([
            ft.TextButton(
                t("photo_add") if not state["photo"] else t("photo_change"),
                on_click=pick_photo,
                style=ft.ButtonStyle(color=C["cyan"]),
            ),
            ft.TextButton(
                t("photo_remove"),
                on_click=remove_photo,
                style=ft.ButtonStyle(color=C["t3"]),
            ) if state["photo"] else ft.Container(width=0),
        ], spacing=4, alignment=ft.MainAxisAlignment.CENTER)

        photo_block = ft.Column([
            photo_lbl,
            ft.Container(
                content=ft.Row([photo_wrap, photo_btns], spacing=12,
                               vertical_alignment=ft.CrossAxisAlignment.CENTER),
                bgcolor=C["bg3"], border_radius=10,
                padding=ft.Padding(left=12, top=10, right=12, bottom=10),
            ),
        ], spacing=4)

        def on_save(e):
            n  = (tf_name.value      or "").strip()
            ds = (dd_day.value       or "").strip()
            ms = (dd_month.value     or "").strip()
            ys = (dd_year.value      or "").strip()
            ph = (tf_phone.value     or "").strip()
            em = (tf_email.value     or "").strip()
            no = (tf_notes.value     or "").strip()
            gn = (tf_gift_note.value or "").strip()
            fp = state.get("photo", "")
            err_lbl.value = ""
            if not n:
                err_lbl.value = t("err_name"); page.update(); return
            if not ds or not ms:
                err_lbl.value = t("err_date"); page.update(); return
            d, m = int(ds), int(ms)
            y = int(ys) if ys.isdigit() else None
            if editing:
                db.update(state["edit_id"], n, d, m, y, ph, em, no,
                          state["rel"], photo=fp, gift_note=gn)
            else:
                db.add(n, d, m, y, ph, em, no, state["rel"],
                       photo=fp, gift_note=gn)
                # Backup reminder every 10 contacts
                _total_now = len(db.all_contacts())
                if _total_now > 0 and _total_now % 10 == 0:
                    _toast(t("backup_remind_tip"))
            state["edit_id"] = None
            state["rel"]     = "friend"
            state["photo"]   = ""
            state["_rel_for"] = None
            navigate("home")

        def on_cancel(e):
            state["edit_id"] = None
            state["rel"]     = "friend"
            state["photo"]   = ""
            state["_rel_for"] = None
            navigate("home")

        def on_delete(e):
            def do_del(e2):
                _close_dlg()
                db.delete(state["edit_id"])
                state["edit_id"]  = None
                state["rel"]      = "friend"
                state["photo"]    = ""
                state["_rel_for"] = None
                navigate("home")
            dlg = ft.AlertDialog(
                modal=True,
                bgcolor=C["bg2"],
                title=ft.Text(t("confirm_delete"), color=C["yellow"]),
                actions=[
                    ft.TextButton(t("confirm_no"),  on_click=lambda e: _close_dlg(),
                                  style=ft.ButtonStyle(color=C["t3"])),
                    ft.TextButton(t("confirm_yes"), on_click=do_del,
                                  style=ft.ButtonStyle(color=C["red"])),
                ],
            )
            _open_dlg(dlg)

        def _set_rel(rv):
            state["rel"] = rv
            render()

        rel_opts = [
            ("family", "\U0001f46a", "rel_family"),
            ("friend", "\U0001f465", "rel_friend"),
            ("work",   "\U0001f4bc", "rel_work"),
            ("other",  "⭐",        "rel_other"),
        ]
        rel_row = ft.Row([
            ft.Container(
                content=ft.Text(
                    f"{ic} {t(lk)}", size=11,
                    color=C["cyan"] if state["rel"] == rv else C["t3"],
                    text_align=ft.TextAlign.CENTER,
                    weight=ft.FontWeight.W_600,
                ),
                bgcolor=C["cyandim"] if state["rel"] == rv else C["bg3"],
                border_radius=8,
                border=_bdr(1, C["cyan"] if state["rel"] == rv else C["border"]),
                padding=ft.Padding(left=6, top=8, right=6, bottom=8),
                expand=True,
                on_click=lambda e, r=rv: _set_rel(r),
                ink=True,
            )
            for rv, ic, lk in rel_opts
        ], spacing=4)

        btn_row = ft.Row([
            _btn(t("btn_cancel"), C["t3"], on_click=on_cancel, expand=True),
            _btn(f"\U0001f4be  {t('btn_save')}", C["cyan"], on_click=on_save, expand=True),
        ], spacing=10)

        controls = [
            col_name,
            ft.Row([col_day, col_month, col_year], spacing=8),
            ft.Column([
                ft.Text(t("field_relation"), size=11, color=C["t2"],
                        weight=ft.FontWeight.W_600),
                rel_row,
            ], spacing=4),
            col_phone, col_email, col_notes, col_gift_note,
            photo_block,
            err_lbl,
            btn_row,
        ]
        if editing:
            controls.append(
                _btn(f"\U0001f5d1  {t('btn_delete')}", C["red"],
                     on_click=on_delete, expand=True)
            )
        controls += [_footer(), ft.Container(height=16)]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(controls, spacing=10),
                padding=ft.Padding(left=16, top=8, right=16, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # DETAIL
    # ─────────────────────────────────────────────────────────────────────
    def _show_detail():
        cid = state["detail_id"]
        if not cid:
            navigate("home"); return
        row = db.get_contact(cid)
        if not row:
            navigate("home"); return

        _, name, day, month, year, phone, email, notes, relation = row[:9]
        photo     = row[9]  if len(row) > 9  else ""
        gift_note = row[10] if len(row) > 10 else ""
        d_left = days_until(day, month)
        age    = calc_age(day, month, year)
        rc     = rel_color(relation)

        def _go_edit(c):
            state["edit_id"] = c
            navigate("add")

        page.appbar = _appbar(
            name,
            leading=ft.IconButton(
                ft.Icons.ARROW_BACK,
                icon_color=C["cyan"],
                on_click=lambda e: navigate("home"),
            ),
            actions=[
                ft.TextButton(
                    f"✏  {t('btn_edit')}",
                    style=ft.ButtonStyle(color=C["purple"]),
                    on_click=lambda e: _go_edit(cid),
                ),
            ],
        )
        page.navigation_bar = None

        def on_whatsapp(e):
            pass  # manejado por url= en el Container

        if LANG[0] == "es":
            ds = f"{day} de {month_name(month)}"
        else:
            ds = f"{month_name(month)} {day}"
        if year: ds += f", {year}"

        stat1_val = t("today_badge") if d_left == 0 else str(d_left)
        stat1_lbl = "" if d_left == 0 else t("days_left")
        stat1_col = C["pink"] if d_left == 0 else C["cyan"]

        stats = ft.Row([
            _card(ft.Column([
                ft.Text(stat1_val, size=24, color=stat1_col,
                        weight=ft.FontWeight.BOLD, text_align=ft.TextAlign.CENTER),
                ft.Text(stat1_lbl, size=11, color=C["t3"],
                        text_align=ft.TextAlign.CENTER),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            border_color=stat1_col,
            padding=ft.Padding(left=8, top=10, right=8, bottom=10),
            expand=True),

            _card(ft.Column([
                ft.Text(str(age) if age is not None else "?",
                        size=24, color=C["green"],
                        weight=ft.FontWeight.BOLD, text_align=ft.TextAlign.CENTER),
                ft.Text(t("years"), size=11, color=C["t3"],
                        text_align=ft.TextAlign.CENTER),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            border_color=C["green"],
            padding=ft.Padding(left=8, top=10, right=8, bottom=10),
            expand=True),
        ])

        info_items = []
        for icon, lbl, val in [
            ("\U0001f4de", t("field_phone"),    phone),
            ("✉",         t("field_email"),    email),
            ("\U0001f464", t("field_relation"), t(f"rel_{relation}")),
            ("\U0001f4dd", t("field_notes"),    notes),
            ("\U0001f381", t("field_gift"),     gift_note),
        ]:
            if not val:
                continue
            info_items.append(_card(
                ft.Row([
                    ft.Text(icon, size=20, width=34),
                    ft.Column([
                        ft.Text(lbl, size=10, color=C["t3"]),
                        ft.Text(val, size=13, color=C["t1"]),
                    ], spacing=2, expand=True),
                ]),
                padding=ft.Padding(left=12, top=8, right=12, bottom=8),
            ))

        items = [
            _card(ft.Column([
                _avatar(photo, name, relation, size=80),
                ft.Text(name, size=20, color=rc, weight=ft.FontWeight.BOLD,
                        text_align=ft.TextAlign.CENTER),
                ft.Text(ds, size=13, color=C["t3"], text_align=ft.TextAlign.CENTER),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
            border_color=rc, padding=16),
            stats,
            *info_items,
        ]
        if phone:
            wa_digits = "".join(ch for ch in phone if ch.isdigit())
            items.append(
                ft.Container(
                    content=ft.Text(
                        f"\U0001f4ac  {t('btn_whatsapp')}",
                        color="#ffffff",
                        size=13,
                        weight=ft.FontWeight.W_600,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    bgcolor=C["green"],
                    border_radius=10,
                    padding=ft.Padding(left=14, top=10, right=14, bottom=10),
                    url=f"https://wa.me/{wa_digits}",
                    ink=True,
                    expand=True,
                    alignment=ft.Alignment.CENTER,
                )
            )
        items += [_footer(), ft.Container(height=16)]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(items, spacing=10),
                padding=ft.Padding(left=14, top=8, right=14, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # CALENDAR
    # ─────────────────────────────────────────────────────────────────────
    def _show_calendar():
        page.appbar         = _appbar(t("calendar_title"), actions=_std_actions())
        page.navigation_bar = _nav_bar("calendar")

        y, m = state["cal_year"], state["cal_month"]

        def prev_m(e):
            state["cal_month"] -= 1
            if state["cal_month"] < 1:
                state["cal_month"] = 12; state["cal_year"] -= 1
            render()

        def next_m(e):
            state["cal_month"] += 1
            if state["cal_month"] > 12:
                state["cal_month"] = 1; state["cal_year"] += 1
            render()

        contacts = db.all_contacts()
        bd_map: dict = {}
        for c in contacts:
            bd_map.setdefault((c[3], c[2]), []).append(c)   # store full rows

        first_wd, num_days = calendar.monthrange(y, m)
        today = date.today()

        def _open_cal_day(rows_for_day):
            """Open detail view for single birthday; show picker dialog for multiple."""
            if len(rows_for_day) == 1:
                state["detail_id"] = rows_for_day[0][0]
                navigate("detail")
            else:
                def _pick(cid):
                    _close_dlg()
                    state["detail_id"] = cid
                    navigate("detail")
                items = [
                    ft.ListTile(
                        leading=ft.Text(rel_icon(r[8]), size=18),
                        title=ft.Text(r[1], color=C["t1"], size=13),
                        subtitle=ft.Text(
                            f"{r[2]} {month_name(r[3])}",
                            color=C["t3"], size=11,
                        ),
                        on_click=lambda e, cid=r[0]: _pick(cid),
                    )
                    for r in rows_for_day
                ]
                dlg = ft.AlertDialog(
                    modal=True,
                    bgcolor=C["bg2"],
                    title=ft.Text(t("cal_multi_title"), color=C["cyan"],
                                  weight=ft.FontWeight.BOLD),
                    content=ft.Container(
                        content=ft.Column(items, scroll=ft.ScrollMode.AUTO, spacing=0),
                        height=min(300, len(rows_for_day) * 64),
                        width=260,
                    ),
                    actions=[
                        ft.TextButton(
                            t("btn_cancel"),
                            on_click=lambda e: _close_dlg(),
                            style=ft.ButtonStyle(color=C["t3"]),
                        ),
                    ],
                )
                _open_dlg(dlg)

        abbrs = T[LANG[0]]["days_abbr"]
        day_hdrs = ft.Row([
            ft.Text(a, size=11, color=C["violet"], weight=ft.FontWeight.BOLD,
                    expand=True, text_align=ft.TextAlign.CENTER)
            for a in abbrs
        ])

        cells = []
        for _ in range(first_wd):
            cells.append(ft.Container(expand=True, height=42))
        for dn in range(1, num_days + 1):
            bds      = bd_map.get((m, dn), [])
            is_today = (dn == today.day and m == today.month and y == today.year)
            bg = C["cyandim"] if is_today else (C["pinkdim"] if bds else C["bg3"])
            dc = C["cyan"]    if is_today else (C["pink"]    if bds else C["t1"])
            cells.append(ft.Container(
                content=ft.Column([
                    ft.Text(str(dn), size=13, color=dc, weight=ft.FontWeight.BOLD,
                            text_align=ft.TextAlign.CENTER),
                    ft.Text("\U0001f382" * min(len(bds), 2), size=8,
                            text_align=ft.TextAlign.CENTER)
                    if bds else ft.Container(height=11),
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=0),
                bgcolor=bg, border_radius=6,
                expand=True, height=42,
                alignment=ft.Alignment.CENTER,
                on_click=(lambda e, rows=bds: _open_cal_day(rows)) if bds else None,
                ink=bool(bds),
            ))

        grid_rows = []
        for i in range(0, len(cells), 7):
            chunk = cells[i:i + 7]
            while len(chunk) < 7:
                chunk.append(ft.Container(expand=True, height=42))
            grid_rows.append(ft.Row(chunk, spacing=2))

        month_contacts = sorted(
            [c for c in contacts if c[3] == m], key=lambda c: c[2]
        )
        month_items = []
        if month_contacts:
            month_items.append(_sec(f"\U0001f382  {month_name(m)}"))
            def _open_month_contact(cid):
                state["detail_id"] = cid
                navigate("detail")
            for c in month_contacts:
                month_items.append(_contact_card(c, on_click=_open_month_contact))

        nav_row = ft.Row([
            ft.IconButton(ft.Icons.CHEVRON_LEFT,  on_click=prev_m,
                          icon_color=C["violet"]),
            ft.Text(f"{month_name(m)} {y}", size=16, color=C["cyan"],
                    weight=ft.FontWeight.BOLD, expand=True,
                    text_align=ft.TextAlign.CENTER),
            ft.IconButton(ft.Icons.CHEVRON_RIGHT, on_click=next_m,
                          icon_color=C["violet"]),
        ], alignment=ft.MainAxisAlignment.CENTER)

        grid_box = ft.Container(
            content=ft.Column(grid_rows, spacing=2),
            bgcolor=C["bg2"], border_radius=12,
            border=_bdr(1, C["border"]),
            padding=ft.Padding(left=4, top=4, right=4, bottom=4),
        )

        items = [nav_row, day_hdrs, grid_box, *month_items,
                 _footer(), ft.Container(height=8)]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(items, spacing=6),
                padding=ft.Padding(left=12, top=8, right=12, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # ─────────────────────────────────────────────────────────────────────
    # STATS
    # ─────────────────────────────────────────────────────────────────────
    def _show_stats():
        page.appbar = _appbar(
            f"\U0001f4ca  {t('stats_title')}",
            leading=ft.IconButton(
                ft.Icons.ARROW_BACK, icon_color=C["cyan"],
                on_click=lambda e: navigate("settings"),
            ),
        )
        page.navigation_bar = None

        rows = db.all_contacts()
        today = date.today()

        total = len(rows)
        cnt_today = sum(1 for r in rows if days_until(r[2], r[3]) == 0)
        cnt_week  = sum(1 for r in rows if 1 <= days_until(r[2], r[3]) <= 7)
        cnt_month = sum(1 for r in rows if 8 <= days_until(r[2], r[3]) <= 30)

        # Próximo cumpleaños
        upcoming = sorted(
            [r for r in rows if days_until(r[2], r[3]) > 0],
            key=lambda r: days_until(r[2], r[3])
        )
        if upcoming:
            nr  = upcoming[0]
            nxt_txt = f"{nr[1]}  —  {days_until(nr[2], nr[3])} {t('stats_days')}"
            nxt_col = C["green"]
        else:
            nxt_txt = t("stats_none")
            nxt_col = C["t3"]

        # Por relación
        from collections import Counter
        rel_count = Counter(r[8] for r in rows)
        rel_labels = {"family": t("rel_family"), "friend": t("rel_friend"),
                      "work":   t("rel_work"),   "other":  t("rel_other")}
        rel_keys_order = ["family", "friend", "work", "other"]

        # Distribución por mes
        month_count = Counter(r[3] for r in rows)   # r[3] = month

        # ── Cards de resumen (2x2) ───────────────────────────────────────
        def _stat_card(val, lbl, col):
            return _card(ft.Column([
                ft.Text(str(val), size=28, color=col,
                        weight=ft.FontWeight.BOLD,
                        text_align=ft.TextAlign.CENTER),
                ft.Text(lbl, size=10, color=C["t3"],
                        text_align=ft.TextAlign.CENTER),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            padding=ft.Padding(left=8, top=10, right=8, bottom=10),
            expand=True)

        summary_row1 = ft.Row([
            _stat_card(total,      t("stats_total"),      C["cyan"]),
            _stat_card(cnt_today,  t("stats_today"),      C["pink"]),
        ], spacing=8)
        summary_row2 = ft.Row([
            _stat_card(cnt_week,   t("stats_week"),       C["yellow"]),
            _stat_card(cnt_month,  t("stats_month_sec"),  C["green"]),
        ], spacing=8)

        # ── Próximo cumpleaños ────────────────────────────────────────────
        next_card = _card(ft.Row([
            ft.Text("\U0001f382", size=24, width=36),
            ft.Column([
                ft.Text(t("stats_next"), size=10, color=C["t3"]),
                ft.Text(nxt_txt, size=13, color=nxt_col,
                        weight=ft.FontWeight.W_600),
            ], spacing=2, expand=True),
        ]), padding=ft.Padding(left=12, top=10, right=12, bottom=10))

        # ── Por relación ─────────────────────────────────────────────────
        rel_rows = []
        for rk in rel_keys_order:
            cnt = rel_count.get(rk, 0)
            if cnt == 0:
                continue
            bar_val = cnt / max(total, 1)
            rel_rows.append(ft.Row([
                ft.Text(rel_icon(rk), size=18, width=28),
                ft.Text(rel_labels[rk], size=12, color=C["t2"], width=72),
                ft.ProgressBar(
                    value=bar_val, expand=True,
                    bar_height=12, border_radius=6,
                    color=rel_color(rk), bgcolor=C["bg3"],
                ),
                ft.Text(str(cnt), size=12, color=C["t1"],
                        weight=ft.FontWeight.BOLD, width=28,
                        text_align=ft.TextAlign.RIGHT),
            ], spacing=6, vertical_alignment=ft.CrossAxisAlignment.CENTER))

        rel_card = _card(ft.Column([
            ft.Text(t("stats_by_rel"), size=11, color=C["t2"],
                    weight=ft.FontWeight.W_600),
            ft.Divider(height=6, color="transparent"),
            *rel_rows,
        ], spacing=8), padding=ft.Padding(left=12, top=10, right=12, bottom=10))

        # ── Distribución por mes ──────────────────────────────────────────
        month_names_short = [m[:3] for m in T[LANG[0]]["months"][1:]]
        max_mc = max(month_count.values(), default=1)
        MAX_BAR_H = 56
        month_bars = []
        for i, mn in enumerate(month_names_short, start=1):
            cnt = month_count.get(i, 0)
            is_cur = (i == today.month)
            bar_h = max(4, int(cnt / max(max_mc, 1) * MAX_BAR_H))
            spacer_h = MAX_BAR_H - bar_h
            bar_col = C["cyan"] if is_cur else C["violet"]
            month_bars.append(ft.Column([
                ft.Text(str(cnt) if cnt else " ", size=9,
                        color=C["cyan"] if is_cur else C["t3"],
                        text_align=ft.TextAlign.CENTER,
                        weight=ft.FontWeight.BOLD if is_cur else ft.FontWeight.NORMAL),
                ft.Container(height=spacer_h),          # empuja la barra hacia abajo
                ft.Container(width=18, height=bar_h, border_radius=3, bgcolor=bar_col),
                ft.Text(mn, size=8,
                        color=C["cyan"] if is_cur else C["t3"],
                        text_align=ft.TextAlign.CENTER,
                        weight=ft.FontWeight.BOLD if is_cur else ft.FontWeight.NORMAL),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER,
               spacing=1))

        month_card = _card(ft.Column([
            ft.Text(t("stats_by_month"), size=11, color=C["t2"],
                    weight=ft.FontWeight.W_600),
            ft.Divider(height=6, color="transparent"),
            ft.Row(month_bars, spacing=4,
                   alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
        ], spacing=4), padding=ft.Padding(left=12, top=10, right=12, bottom=10))

        # ── Milestone birthdays this year ─────────────────────────────────
        milestone_rows = []
        for r in rows:
            if not r[4]:   # no birth year → can't know age
                continue
            age_this_yr = today.year - r[4]
            if age_this_yr in MILESTONE_AGES:
                milestone_rows.append((r, age_this_yr))
        milestone_rows.sort(key=lambda x: days_until(x[0][2], x[0][3]))

        milestone_items = []
        if milestone_rows:
            for mr, ma in milestone_rows:
                d_ms = days_until(mr[2], mr[3])
                d_ms_txt = t("today_badge") if d_ms == 0 else f"{d_ms} {t('stats_days')}"
                milestone_items.append(ft.Row([
                    ft.Text("✨", size=16, width=28,
                            text_align=ft.TextAlign.CENTER),
                    ft.Column([
                        ft.Text(mr[1], size=12, color=C["yellow"],
                                weight=ft.FontWeight.W_600,
                                max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                        ft.Text(f"{ma} {t('years')}  •  {d_ms_txt}",
                                size=10, color=C["t3"]),
                    ], spacing=2, expand=True),
                ], spacing=6, vertical_alignment=ft.CrossAxisAlignment.CENTER))
        else:
            milestone_items.append(
                ft.Text(t("stats_no_milestones"), size=11, color=C["t3"])
            )

        milestone_card = _card(ft.Column([
            ft.Text(t("stats_milestones"), size=11, color=C["t2"],
                    weight=ft.FontWeight.W_600),
            ft.Divider(height=6, color="transparent"),
            *milestone_items,
        ], spacing=8), padding=ft.Padding(left=12, top=10, right=12, bottom=10))

        items = [
            summary_row1, summary_row2,
            next_card,
            rel_card,
            month_card,
            milestone_card,
            _footer(),
            ft.Container(height=16),
        ]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(items, spacing=10),
                padding=ft.Padding(left=14, top=8, right=14, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ── vCard import helpers ──────────────────────────────────────────────
    def _show_vcf_review(contacts):
        """Diálogo con checkboxes para seleccionar qué contactos vcf importar."""
        checked = [True] * len(contacts)
        cb_refs = []

        for i, c in enumerate(contacts):
            d, m, yr = c.get("day"), c.get("month"), c.get("year")
            yr_txt   = f"  ({yr})" if yr else ""
            date_txt = f"{d}/{m}{yr_txt}"
            cb = ft.Checkbox(
                label=f"{c['name']}  —  {date_txt}",
                value=True,
                on_change=lambda e, idx=i: checked.__setitem__(idx, e.control.value),
                label_style=ft.TextStyle(color=C["t1"], size=12),
                check_color=C["cyan"],
                active_color=C["cyandim"],
            )
            cb_refs.append(cb)

        def do_import_vcf(e):
            selected = [contacts[i] for i in range(len(contacts)) if checked[i]]
            if not selected:
                _toast(t("import_vcf_empty"))
                return
            for c in selected:
                db.add(
                    c["name"], c["day"], c["month"], c.get("year"),
                    c.get("phone", ""), "", "", "friend",
                )
            _close_dlg()
            _toast(f"✓  {len(selected)} {t('import_vcf_ok')}")
            render()

        def sel_all(e):
            for i, cb in enumerate(cb_refs):
                cb.value = True
                checked[i] = True
            page.update()

        def sel_none(e):
            for i, cb in enumerate(cb_refs):
                cb.value = False
                checked[i] = False
            page.update()

        dlg = ft.AlertDialog(
            modal=True,
            bgcolor=C["bg2"],
            title=ft.Text(
                f"{len(contacts)} {t('import_vcf_found')}",
                color=C["cyan"], weight=ft.FontWeight.BOLD, size=14,
            ),
            content=ft.Container(
                content=ft.Column(cb_refs, scroll=ft.ScrollMode.AUTO, spacing=2),
                height=320,
                width=300,
            ),
            actions=[
                ft.TextButton(t("import_vcf_all"),
                              on_click=sel_all,
                              style=ft.ButtonStyle(color=C["t2"])),
                ft.TextButton(t("import_vcf_clear"),
                              on_click=sel_none,
                              style=ft.ButtonStyle(color=C["t2"])),
                ft.TextButton(t("import_vcf_do"),
                              on_click=do_import_vcf,
                              style=ft.ButtonStyle(color=C["green"])),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        _open_dlg(dlg)

    async def _do_vcf_import(e):
        """Abre el selector de archivos .vcf y procesa el resultado."""
        if not _is_android:
            _toast(t("mobile_only"))
            return
        files = await vcf_picker.pick_files(
            allowed_extensions=["vcf"],
            dialog_title=t("import_vcf_title"),
            with_data=True,   # bytes es más confiable que path en Android
        )
        if not files:
            return
        try:
            f = files[0]
            if f.bytes:
                content = f.bytes.decode("utf-8", errors="replace")
            elif f.path:
                with open(f.path, "r", encoding="utf-8", errors="replace") as fh:
                    content = fh.read()
            else:
                _toast("Error: no se pudo leer el archivo")
                return
            contacts = _parse_vcf(content)
            if not contacts:
                _toast(t("import_vcf_none"))
                return
            _show_vcf_review(contacts)
        except Exception as ex:
            _toast(f"Error: {ex}")

    # ── Test-popup helper (called from Settings button) ───────────────────
    def _do_test_popup():
        """Navega a la pantalla de cumpleaños inmediatamente (botón de prueba)."""
        try:
            tc = [c for c in db.all_contacts() if days_until(c[2], c[3]) == 0]
            if not tc:
                _today = date.today()
                # Fila sintética: id=0, name, day, month, year, phone, email,
                # notes, relation, photo, gift_note (misma estructura all_contacts)
                tc = [(0, t("test_popup_demo"), _today.day, _today.month,
                       _today.year - 30, "", "", "", "friend", "", "")]
            state["_birthday_contacts"] = tc
            navigate("birthday")
        except Exception as _ex:
            _toast(f"Error al probar popup: {_ex}")

    # SETTINGS
    # ─────────────────────────────────────────────────────────────────────
    def _show_settings():
        page.appbar         = _appbar(t("settings_title"), actions=_std_actions())
        page.navigation_bar = _nav_bar("settings")

        cur_nd = int(db.get("notif_days", "0"))
        cur_hr = int(db.get("notif_hour", "8"))

        def set_theme(tid, e):
            THEME[0] = tid
            db.set("theme", THEME[0])
            _apply_theme()
            page.bgcolor = C["bg"]
            render()

        def set_lang(lc, e):
            LANG[0] = lc
            db.set("lang", LANG[0])
            render()

        def set_nd(nd, e):
            db.set("notif_days", nd)
            render()

        def set_hr(hr, e):
            db.set("notif_hour", hr)
            _toast(f"{t('alarm_saved')}  {hr}:00")
            render()

        def _toggle_setting(key):
            new_val = "0" if db.get(key, "1") == "1" else "1"
            db.set(key, new_val)
            render()

        def _toggle_remind_all(e):
            """Toggle remind_all_day — default OFF ("0"), so invert correctly."""
            new_val = "1" if db.get("remind_all_day", "0") == "0" else "0"
            db.set("remind_all_day", new_val)
            render()

        async def do_export(e):
            json_bytes = db.to_json().encode("utf-8")
            if _is_android:
                # Android: save_file() muestra diálogo "Guardar como" del sistema.
                # Retorna la ruta elegida, o None si el usuario cancela.
                try:
                    result = await save_picker.save_file(
                        file_name="Celebria_backup.json",
                        src_bytes=json_bytes,
                    )
                    if result is not None:
                        _toast(f"✓  {t('export_ok')}")
                except Exception as ex:
                    _toast(f"Error: {ex}")
            else:
                path = _desktop_backup_path("Celebria_backup.json")
                try:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(db.to_json())
                    _toast(f"✓  {t('export_ok')}: {path}")
                except Exception as ex:
                    _toast(f"Error: {ex}")

        async def do_import(e):
            if _is_android:
                # Android: pick_files() deja al usuario elegir el JSON
                files = await vcf_picker.pick_files(
                    allowed_extensions=["json"],
                    allow_multiple=False,
                    with_data=True,
                )
                if not files:
                    return
                try:
                    f = files[0]
                    txt = (f.bytes.decode("utf-8")
                           if f.bytes
                           else open(f.path, encoding="utf-8").read())
                    n = db.from_json(txt)
                    if n >= 0:
                        _toast(f"✓  {n} {t('import_ok')}")
                        render()
                    else:
                        _toast("Error en el archivo / File error")
                except Exception as ex:
                    _toast(f"Error: {ex}")
            else:
                path = _desktop_backup_path("Celebria_backup.json")
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        txt = f.read()
                    n = db.from_json(txt)
                    if n >= 0:
                        _toast(f"✓  {n} {t('import_ok')}")
                        render()
                    else:
                        _toast("Error en el archivo / File error")
                except FileNotFoundError:
                    _toast(f"{t('file_not_found')}: {path}")
                except Exception as ex:
                    _toast(f"Error: {ex}")

        items = [
            # ── Theme ────────────────────────────────────────────────────
            _sec(t("set_theme")),
            ft.Row([
                _opt_btn("\U0001f319  Dark",  THEME[0] == "dark",
                         lambda e: set_theme("dark",  e)),
                _opt_btn("☀  Light", THEME[0] == "light",
                         lambda e: set_theme("light", e)),
            ], spacing=10),

            # ── Language ─────────────────────────────────────────────────
            _sec(t("set_lang")),
            ft.Row([
                _opt_btn("\U0001f1e9\U0001f1f4  Español", LANG[0] == "es",
                         lambda e: set_lang("es", e)),
                _opt_btn("\U0001f1fa\U0001f1f8  English", LANG[0] == "en",
                         lambda e: set_lang("en", e)),
            ], spacing=10),

            # ── Notif days ───────────────────────────────────────────────
            _sec(t("set_notif")),
            ft.Row([
                _opt_btn(t("same_day"),   cur_nd == 0,
                         lambda e: set_nd(0, e)),
                _opt_btn(t("one_day"),    cur_nd == 1,
                         lambda e: set_nd(1, e)),
                _opt_btn(t("three_days"), cur_nd == 3,
                         lambda e: set_nd(3, e)),
                _opt_btn(t("one_week"),   cur_nd == 7,
                         lambda e: set_nd(7, e)),
            ], spacing=4),

            # ── Notif hour ───────────────────────────────────────────────
            _sec(t("set_notif_hour")),
            ft.Row([
                _opt_btn(f"{h}:00", cur_hr == h,
                         lambda e, h=h: set_hr(h, e))
                for h in [6, 7, 8, 9, 10, 12]
            ], spacing=4),

            # ── Popup toggle ─────────────────────────────────────────────
            _sec(t("set_popup")),
            ft.Row([
                _opt_btn(f"\U0001f382  {t('opt_show')}",
                         db.get("show_popup", "1") == "1",
                         lambda e: _toggle_setting("show_popup")),
                _opt_btn(f"\U0001f6ab  {t('opt_hide')}",
                         db.get("show_popup", "1") == "0",
                         lambda e: _toggle_setting("show_popup")),
            ], spacing=10),

            # ── Remind all day ────────────────────────────────────────────
            _sec(t("set_remind_all_day")),
            ft.Row([
                _opt_btn(
                    f"\U0001f514  {t('remind_all_day_on')}",
                    db.get("remind_all_day", "0") == "1",
                    _toggle_remind_all,
                ),
                _opt_btn(
                    f"\U0001f515  {t('remind_all_day_off')}",
                    db.get("remind_all_day", "0") == "0",
                    _toggle_remind_all,
                ),
            ], spacing=10),

            # ── Test popup ────────────────────────────────────────────────
            _btn(
                f"\U0001f388  {t('test_popup_btn')}",
                C["pink"],
                on_click=lambda e: _do_test_popup(),
                expand=True,
            ),
            # ── Backup ───────────────────────────────────────────────────
            _sec(t("set_backup")),
            ft.Row([
                _btn(f"\U0001f4e4  {t('btn_export')}", C["green"],
                     on_click=do_export, expand=True),
                _btn(f"\U0001f4e5  {t('btn_import')}", C["yellow"],
                     on_click=do_import, expand=True),
            ], spacing=10),
            _btn(f"\U0001f4f1  {t('import_vcf_btn')}", C["cyan"],
                 on_click=_do_vcf_import,
                 expand=True),

            # ── Stats + Manual ────────────────────────────────────────────
            ft.Row([
                _btn(f"\U0001f4ca  {t('stats_btn')}", C["violet"],
                     on_click=lambda e: navigate("stats"), expand=True),
                _btn(f"\U0001f4d6  {t('manual_btn')}", C["purple"],
                     on_click=lambda e: navigate("help"), expand=True),
            ], spacing=10),

            # ── About ────────────────────────────────────────────────────
            _sec(t("about_title")),
            _card(ft.Column([
                ft.Text(f"\U0001f382  {APP_NAME}  v{APP_VERSION}",
                        size=13, color=C["cyan"], weight=ft.FontWeight.BOLD),
                ft.Text(t("app_sub"),   size=11, color=C["t2"]),
            ], spacing=4)),

            _footer(),
            ft.Container(height=16),
        ]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(items, spacing=10),
                padding=ft.Padding(left=16, top=8, right=16, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # HELP
    # ─────────────────────────────────────────────────────────────────────
    def _show_help():
        page.appbar = _appbar(
            f"\U0001f4d6  {t('manual_btn')}",
            leading=ft.IconButton(
                ft.Icons.ARROW_BACK,
                icon_color=C["cyan"],
                on_click=lambda e: navigate("settings"),
            ),
        )
        page.navigation_bar = None

        sections = _HELP_ES if LANG[0] == "es" else _HELP_EN

        help_cards = [
            _card(ft.Column([
                ft.Row([
                    ft.Text(icon, size=20, width=34),
                    ft.Text(title_sec, size=13, color=C["cyan"],
                            weight=ft.FontWeight.BOLD, expand=True),
                ]),
                ft.Text(content, size=12, color=C["t1"]),
            ], spacing=6))
            for icon, title_sec, content in sections
        ]

        items = [
            ft.Text(
                f"Celebria v{APP_VERSION} — {t('app_sub')}",
                size=13, color=C["t2"], text_align=ft.TextAlign.CENTER,
            ),
            *help_cards,
            _footer(),
            ft.Container(height=16),
        ]

        page.add(ft.Column(
            controls=[ft.Container(
                content=ft.Column(items, spacing=10),
                padding=ft.Padding(left=12, top=8, right=12, bottom=8),
            )],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
        ))

    # ─────────────────────────────────────────────────────────────────────
    # BIRTHDAY SCREEN (reemplaza el AlertDialog que fallaba en Android)
    # Navegamos a esta pantalla en vez de mostrar un dialog.
    # Funciona 100 % en Android porque usa controles Flet normales.
    # ─────────────────────────────────────────────────────────────────────
    def _show_birthday():
        """Pantalla completa de cumpleaños — sin dialogs, sin AlertDialog."""
        today_contacts = state["_birthday_contacts"]
        if not today_contacts:
            navigate("home")
            return

        _confetti_running = [True]

        def _celebrate(e):
            _confetti_running[0] = False
            if db.get("remind_all_day", "0") == "0":
                db.set("birthday_dismissed_date", str(date.today()))
            navigate("home")

        # Construir tarjeta por cada cumpleañero
        contact_cards = []
        for row in today_contacts:
            _, name, day, month, year, *_ = row
            age = calc_age(day, month, year)
            _age_this_year = (date.today().year - year) if year else None
            _milestone = (
                (_age_this_year in MILESTONE_AGES)
                if _age_this_year is not None else False
            )
            if age is not None:
                line = f"{name}\n{t('popup_turns')} {age} {t('popup_years')} \U0001f382"
            else:
                line = f"{name}  \U0001f382"
            if _milestone:
                line += f"\n✨ {t('milestone_popup')}"
            contact_cards.append(
                ft.Container(
                    content=ft.Text(
                        line, size=16,
                        color=C["yellow"] if _milestone else C["cyan"],
                        weight=ft.FontWeight.W_600,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    bgcolor=C["purpledim"] if _milestone else C["cyandim"],
                    border_radius=12,
                    border=_bdr(1, C["yellow"]) if _milestone else None,
                    padding=ft.Padding(left=16, top=12, right=16, bottom=12),
                )
            )

        # Sin appbar ni navbar — pantalla de celebración inmersiva
        page.appbar         = None
        page.navigation_bar = None

        _confetti_txt = ft.Text(
            "", size=24, text_align=ft.TextAlign.CENTER,
        )

        page.add(ft.Column(
            controls=[
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Text(
                                "\U0001f388 \U0001f38a \U0001f389 \U0001f381 \U0001f389 \U0001f38a \U0001f388",
                                size=22, text_align=ft.TextAlign.CENTER,
                            ),
                            ft.Text("\U0001f382", size=88,
                                    text_align=ft.TextAlign.CENTER),
                            ft.Text(
                                t("popup_title"),
                                size=26, color=C["pink"],
                                weight=ft.FontWeight.BOLD,
                                text_align=ft.TextAlign.CENTER,
                            ),
                            ft.Text(
                                t("birthday_screen_sub"),
                                size=13, color=C["t2"],
                                text_align=ft.TextAlign.CENTER,
                            ),
                            _confetti_txt,
                            ft.Container(height=2, bgcolor=C["pink"],
                                         border_radius=1),
                            *contact_cards,
                            ft.Text(
                                "✨ \U0001f38a \U0001f389 \U0001f38a ✨",
                                size=18, text_align=ft.TextAlign.CENTER,
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=12,
                        scroll=ft.ScrollMode.AUTO,
                    ),
                    padding=ft.Padding(left=20, top=36, right=20, bottom=20),
                    expand=True,
                ),
                ft.Container(
                    content=_btn(
                        f"\U0001f389  {t('popup_close')}",
                        C["pink"],
                        on_click=_celebrate,
                        expand=False,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding(left=32, top=0, right=32, bottom=32),
                    width=320,
                ),
            ],
            expand=True,
        ))

        # Confeti animado: emojis aparecen uno a uno cada 220 ms
        import threading as _thr
        _CONFETTI = [
            "\U0001f389", "\U0001f38a", "\U0001f388", "\U0001f381", "✨",
            "\U0001f389", "\U0001f38a", "\U0001f388", "\U0001f381", "✨",
        ]

        def _confetti_step(i=0):
            if not _confetti_running[0] or i >= len(_CONFETTI):
                return
            _confetti_txt.value = "  ".join(_CONFETTI[:i + 1])
            try:
                page.update()
            except Exception:
                return
            _nt = _thr.Timer(0.22, _confetti_step, [i + 1])
            _nt.daemon = True
            _nt.start()

        _ct = _thr.Timer(0.5, _confetti_step, [0])
        _ct.daemon = True
        _ct.start()

        _play_birthday_sound()

    # ─────────────────────────────────────────────────────────────────────
    # BIRTHDAY POPUP (AlertDialog — kept for reference, not used on Android)
    # FIX: removed tight=True from Columns inside AlertDialog
    # ─────────────────────────────────────────────────────────────────────
    def _birthday_popup(today_contacts):
        try:
            # Build one card per birthday contact
            contact_cards = []
            for row in today_contacts:
                _, name, day, month, year, *_ = row
                age = calc_age(day, month, year)
                _age_this_year = (date.today().year - year) if year else None
                _milestone = (_age_this_year in MILESTONE_AGES) if _age_this_year is not None else False
                if age is not None:
                    line = f"{name}\n{t('popup_turns')} {age} {t('popup_years')} \U0001f382"
                else:
                    line = f"{name}  \U0001f382"
                if _milestone:
                    line += f"\n✨ {t('milestone_popup')}"
                contact_cards.append(
                    ft.Container(
                        content=ft.Text(
                            line, size=14,
                            color=C["yellow"] if _milestone else C["cyan"],
                            weight=ft.FontWeight.W_600,
                            text_align=ft.TextAlign.CENTER,
                        ),
                        bgcolor=C["purpledim"] if _milestone else C["cyandim"],
                        border_radius=12,
                        border=_bdr(1, C["yellow"]) if _milestone else None,
                        padding=ft.Padding(left=16, top=10, right=16, bottom=10),
                    )
                )

            def _close_popup(e):
                _close_dlg()

            dlg = ft.AlertDialog(
                modal=True,
                bgcolor=C["bg2"],
                # ── Title row: centered title (no X button — use the ¡Celebrar! button)
                title=ft.Text(
                    t("popup_title"), size=18, color=C["pink"],
                    weight=ft.FontWeight.BOLD,
                    text_align=ft.TextAlign.CENTER,
                ),
                # ── Scrollable content with fixed max height ───────────────
                content=ft.Container(
                    content=ft.Column([
                        ft.Text(
                            "\U0001f388 \U0001f38a \U0001f389 \U0001f381 \U0001f389 \U0001f38a \U0001f388",
                            size=20, text_align=ft.TextAlign.CENTER,
                        ),
                        ft.Text("\U0001f382", size=68, text_align=ft.TextAlign.CENTER),
                        ft.Container(
                            height=2, bgcolor=C["pink"], border_radius=1,
                        ),
                        *contact_cards,
                        ft.Text(
                            "✨ \U0001f38a \U0001f389 \U0001f38a ✨",
                            size=16, text_align=ft.TextAlign.CENTER,
                        ),
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                       spacing=8, scroll=ft.ScrollMode.AUTO),
                    height=320,
                    width=280,
                ),
                actions=[
                    ft.TextButton(
                        f"\U0001f389  {t('popup_close')}",
                        on_click=_close_popup,
                        style=ft.ButtonStyle(color=C["pink"]),
                    ),
                ],
                actions_alignment=ft.MainAxisAlignment.CENTER,
            )
            _open_dlg(dlg)
        except Exception as _ex:
            _toast(f"Popup error: {_ex}")

    # ── Platform detection + File pickers ────────────────────────────────
    # Los pickers se declaran ANTES de render() para que los closures los
    # capturen por nombre, pero se REGISTRAN DESPUÉS de render() para que
    # la sesión Flet / Flutter esté completamente lista.
    # Registrar antes de render() puede crashear (pantalla negra).
    _is_android = (page.platform == ft.PagePlatform.ANDROID)
    vcf_picker  = ft.FilePicker()   # importar .vcf e importar .json
    img_picker  = ft.FilePicker()   # seleccionar foto
    save_picker = ft.FilePicker()   # exportar JSON (save_file)
    # Audio de cumpleaños — declarado ANTES de render() igual que los pickers.
    # Se registra DESPUÉS de render() para que Flutter esté listo.
    # Para el momento en que aparece la pantalla de cumpleaños (≥3.5 s),
    # el audio ya está completamente cargado → play() funciona sin race condition.
    _bd_snd = FletAudio(src=_gen_birthday_wav(), volume=1.0) if _AUDIO_OK else None

    # ── Initial render ────────────────────────────────────────────────────
    render()

    # ── Registrar pickers después de render() ────────────────────────────
    # page._services (ServiceRegistry) evita el "Unknown control" red bar:
    # Flutter trata sus hijos como servicios (sin rendering visual).
    # Si falla (AttributeError u otro), fallback a overlay + visible=False
    # (Flutter Offstage: inicializado pero no pintado → sin barra roja).
    try:
        page._services.register_service(vcf_picker)
        page._services.register_service(img_picker)
        page._services.register_service(save_picker)
        if _bd_snd:
            page._services.register_service(_bd_snd)
    except Exception:
        try:
            _extra = []
            if _bd_snd:
                # visible=False mata el audio; 1px transparente lo mantiene vivo
                _extra.append(ft.Container(content=_bd_snd, width=1, height=1,
                                           bgcolor="transparent"))
            page.overlay.extend([
                ft.Container(content=vcf_picker,  visible=False),
                ft.Container(content=img_picker,  visible=False),
                ft.Container(content=save_picker, visible=False),
                *_extra,
            ])
            page.update()
        except Exception:
            pass

    def _play_birthday_sound():
        """Llama play() en el widget de audio pre-cargado al arrancar la app."""
        if _bd_snd is None:
            return
        async def _do():
            try:
                await _bd_snd.play()
            except Exception:
                pass
        page.run_task(_do)

    # Birthday popup — delay via threading.Timer (same pattern as update dialog).
    # page.show_dialog() fails silently on Android if called immediately after
    # render() — Flutter's Overlay/Scaffold isn't ready yet.
    # threading.Timer fires from a background thread, then uses page.run_task()
    # to dispatch to Flet's event loop — identical to how the update checker
    # shows its dialog, which is proven to work.
    # 3.5 s gives Flutter's Overlay/Scaffold enough time to initialize AND
    # gives the update-checker dialog time to appear first (if any), so both
    # dialogs don't race to occupy the same slot simultaneously.
    import threading as _threading
    today_contacts = [c for c in db.all_contacts() if days_until(c[2], c[3]) == 0]
    if today_contacts and db.get("show_popup", "1") == "1":
        _today_str   = str(date.today())
        _remind_all  = db.get("remind_all_day", "0") == "1"
        _dismissed   = db.get("birthday_dismissed_date", "") == _today_str
        # Mostrar si: remind_all_day ON (siempre)  O  todavía no se ha
        # descartado hoy (dismissed_date != hoy).
        if _remind_all or not _dismissed:
            def _fire_birthday_popup(tc=today_contacts):
                async def _show():
                    state["_birthday_contacts"] = tc
                    navigate("birthday")
                page.run_task(_show)
            _bd_timer = _threading.Timer(3.5, _fire_birthday_popup)
            _bd_timer.daemon = True
            _bd_timer.start()

    # ── Update checker — corre en segundo plano, no bloquea la UI ─────────
    def _check_for_update():
        import threading, urllib.request, json as _json

        def _ver_tuple(v):
            try:
                return tuple(int(x) for x in v.strip().lstrip("v").split("."))
            except Exception:
                return (0,)

        def _show_update_dialog(new_ver, dl_url, forced=False):
            if LANG[0] == "es":
                title_txt = ("\U0001f512  ¡Actualización requerida!"
                             if forced else "\U0001f389  ¡Nueva versión disponible!")
                body_txt  = (
                    f"Esta versión (v{APP_VERSION}) ya no es compatible.\n"
                    f"Debes actualizar a v{new_ver} para continuar usando Celebria."
                    if forced else
                    f"Celebria v{new_ver} ya está disponible.\n"
                    f"Tienes instalada la v{APP_VERSION}.\n\n"
                    f"📥 Al terminar la descarga, toca el archivo APK\n"
                    f"en la barra de notificaciones para instalarlo."
                )
                btn_later = "Ahora no"
                btn_dl    = "⬇  Descargar"
            else:
                title_txt = ("\U0001f512  Update required!"
                             if forced else "\U0001f389  Update available!")
                body_txt  = (
                    f"Version v{APP_VERSION} is no longer supported.\n"
                    f"You must update to v{new_ver} to keep using Celebria."
                    if forced else
                    f"Celebria v{new_ver} is now available.\n"
                    f"You have v{APP_VERSION} installed.\n\n"
                    f"📥 When the download finishes, tap the APK file\n"
                    f"in your notifications to install it."
                )
                btn_later = "Not now"
                btn_dl    = "⬇  Download"

            dl_color = C["red"] if forced else C["cyan"]

            actions = []
            if not forced:
                actions.append(ft.TextButton(
                    btn_later,
                    on_click=lambda e: _close_dlg(),
                    style=ft.ButtonStyle(color=C["t3"]),
                ))
            # Abre la página de releases (no la URL directa del APK).
            # La URL directa del APK puede quedar "atascada" en Chrome Android
            # porque GitHub no cierra la conexión correctamente.
            # La página de releases descarga el APK con el flujo normal de
            # Chrome y muestra "Abrir / Open" al terminar.
            releases_page = f"https://github.com/{GITHUB_REPO}/releases/tag/v{new_ver}"
            actions.append(ft.TextButton(
                btn_dl,
                url=releases_page,
                on_click=lambda e: _close_dlg(),
                style=ft.ButtonStyle(color=dl_color),
            ))

            dlg = ft.AlertDialog(
                modal=True,
                bgcolor=C["bg2"],
                title=ft.Text(
                    title_txt,
                    color=C["red"] if forced else C["cyan"],
                    weight=ft.FontWeight.BOLD, size=16,
                ),
                content=ft.Text(body_txt, color=C["t1"], size=13),
                actions=actions,
                actions_alignment=ft.MainAxisAlignment.END,
            )
            _open_dlg(dlg)

        def _run():
            try:
                # version.json en el repo — fuente única de verdad
                url = (f"https://raw.githubusercontent.com/"
                       f"{GITHUB_REPO}/main/version.json")
                req = urllib.request.Request(
                    url, headers={"User-Agent": "Celebria-App"}
                )
                with urllib.request.urlopen(req, timeout=6) as resp:
                    data = _json.loads(resp.read())

                latest  = data.get("latest",  "")
                minimum = data.get("minimum", "0.0.0")
                dl_url  = data.get("download_url",
                          f"https://github.com/{GITHUB_REPO}/releases/latest")

                cur = _ver_tuple(APP_VERSION)
                if _ver_tuple(latest) > cur:
                    forced = _ver_tuple(minimum) > cur
                    # Despachar al event loop de Flet (no llamar desde hilo de fondo
                    # directamente — causa que el diálogo aparezca tarde o en la
                    # siguiente pantalla en vez de en Home).
                    async def _show_on_main(lv=latest, du=dl_url, fv=forced):
                        _show_update_dialog(lv, du, forced=fv)
                    page.run_task(_show_on_main)
            except Exception:
                pass  # sin conexión → silencioso

        threading.Thread(target=_run, daemon=True).start()

    _check_for_update()


ft.app(target=main)
