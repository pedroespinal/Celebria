#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
audit.py — Auditor automático de bugs para C:\\Celebria\\main.py
Ejecutar: python audit.py

Detecta:
  1. Errores de sintaxis (AST parse)
  2. T-string keys: usadas pero no definidas / definidas pero no usadas /
     asimetría ES vs EN
  3. navigate("screen") sin rama "elif scr == screen" en render()
  4. state["key"] accedido pero no inicializado en el dict base
  5. Anti-patrones conocidos de Flet 0.85.1 que crashean en Android
  6. ft.ElevatedButton / ft.ButtonStyle params que pueden no existir en 0.85.1
  7. Llamadas a funciones internas que podrían no estar definidas
  8. page.add() vs controles de Flet: detecta Column/Row sin 'controls='
  9. Closures peligrosos en lambdas dentro de bucles for
 10. Resumen final con severidad
"""

import ast, re, sys, textwrap, io
from pathlib import Path
from collections import defaultdict

# Forzar UTF-8 en la salida (evita UnicodeEncodeError en consolas cp1252)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# ── Config ────────────────────────────────────────────────────────────────────
MAIN_PY = Path(r"C:\Celebria\main.py")

# ── Colores ANSI ──────────────────────────────────────────────────────────────
RED   = "\033[91m"
YEL   = "\033[93m"
GRN   = "\033[92m"
CYN   = "\033[96m"
RST   = "\033[0m"
BOLD  = "\033[1m"

issues: list[tuple[str, int | None, str]] = []   # (severity, lineno, msg)

def E(msg, line=None): issues.append(("ERROR",   line, msg))
def W(msg, line=None): issues.append(("WARN",    line, msg))
def I(msg, line=None): issues.append(("INFO",    line, msg))

# ── Lectura ───────────────────────────────────────────────────────────────────
if not MAIN_PY.exists():
    print(f"{RED}No se encuentra {MAIN_PY}{RST}")
    sys.exit(1)

src   = MAIN_PY.read_text(encoding="utf-8-sig")  # utf-8-sig strips BOM if present
lines = src.splitlines()

def line_of(pattern, start=0):
    """Devuelve el número de línea (1-based) de la primera aparición."""
    for i, ln in enumerate(lines[start:], start=start+1):
        if re.search(pattern, ln):
            return i
    return None

def all_lines_of(pattern):
    return [(i+1, lines[i]) for i in range(len(lines)) if re.search(pattern, lines[i])]

# ═══════════════════════════════════════════════════════════════════════════════
print(f"\n{BOLD}{CYN}{'═'*66}{RST}")
print(f"{BOLD}{CYN}  CELEBRIA AUDIT — {MAIN_PY.name}  ({len(lines)} líneas){RST}")
print(f"{BOLD}{CYN}{'═'*66}{RST}\n")

# ── 1. SINTAXIS ───────────────────────────────────────────────────────────────
print(f"{BOLD}[1] Sintaxis Python{RST}")
try:
    tree = ast.parse(src, filename=str(MAIN_PY))
    print(f"    {GRN}✅ OK{RST}")
except SyntaxError as ex:
    E(f"SyntaxError línea {ex.lineno}: {ex.msg}", ex.lineno)
    print(f"    {RED}❌ {issues[-1][2]}{RST}")
    # Sin AST no podemos continuar
    for sev, ln, msg in issues:
        print(f"  {RED}[{sev}]{RST} L{ln}: {msg}" if ln else f"  {RED}[{sev}]{RST} {msg}")
    sys.exit(1)

# ── 2. T-STRING KEYS ─────────────────────────────────────────────────────────
print(f"{BOLD}[2] Auditoría T-string keys{RST}")

T_es: dict[str,str] = {}
T_en: dict[str,str] = {}

# Buscar: T = {"es": {...}, "en": {...}}  — top-level assignment
for node in ast.walk(tree):
    if not isinstance(node, ast.Assign):
        continue
    for target in node.targets:
        if not (isinstance(target, ast.Name) and target.id == "T"):
            continue
        if not isinstance(node.value, ast.Dict):
            continue
        for k, v in zip(node.value.keys, node.value.values):
            if not (isinstance(k, ast.Constant) and isinstance(v, ast.Dict)):
                continue
            d = {}
            for sk, sv in zip(v.keys, v.values):
                if isinstance(sk, ast.Constant) and isinstance(sv, ast.Constant):
                    d[str(sk.value)] = str(sv.value)
            if k.value == "es":
                T_es = d
            elif k.value == "en":
                T_en = d

if not T_es or not T_en:
    W("No se pudo parsear el dict T = {'es': {...}, 'en': {...}}")

all_es = set(T_es)
all_en = set(T_en)

# Todas las llamadas t("key") o t('key')
t_used: set[str] = set(re.findall(r'\bt\(\s*["\']([^"\']+)["\']\s*\)', src))

missing_es = t_used - all_es
missing_en = t_used - all_en
only_es    = all_es - all_en
only_en    = all_en - all_es
unused     = (all_es | all_en) - t_used

for key in sorted(missing_es):
    ln = line_of(rf't\(\s*["\'{re.escape(key)}["\']')
    E(f't("{key}") usada pero FALTA en dict ES', ln)

for key in sorted(missing_en):
    ln = line_of(rf't\(\s*["\'{re.escape(key)}["\']')
    E(f't("{key}") usada pero FALTA en dict EN', ln)

for key in sorted(only_es):
    E(f'T key "{key}" está en ES pero FALTA en EN')

for key in sorted(only_en):
    E(f'T key "{key}" está en EN pero FALTA en ES')

# Nota: algunas keys se usan via t(var) dinámico — el auditor no las detecta.
# Ej: t(sec_key) con sec_key="today_title"; t(fk) con fk="filter_all", etc.
# Solo marcar las que claramente no tienen ningún uso dinámico obvio.
DYNAMIC_KEYS = {
    # Usadas via t(sec_key) en _show_home() buckets:
    "today_title", "week_title", "month_title", "all_title",
    # Usadas via t(fk) en filter_btns de _show_home():
    "filter_all", "filter_fam", "filter_fri", "filter_wor",
}
for key in sorted(unused - DYNAMIC_KEYS):
    W(f'T key "{key}" definida pero nunca usada (¿dead code?)')

total_keys = len(t_used)
errs_t     = len(missing_es) + len(missing_en) + len(only_es) + len(only_en)
print(f"    {GRN if errs_t==0 else RED}{'✅' if errs_t==0 else '❌'} "
      f"{total_keys} keys usadas | {len(all_es)} ES | {len(all_en)} EN | "
      f"{len(unused)} no usadas | {errs_t} errores{RST}")

# ── 3. navigate() VS render() BRANCHES ───────────────────────────────────────
print(f"{BOLD}[3] navigate() vs render() branches{RST}")

nav_calls: set[str] = set(re.findall(
    r'\bnavigate\(\s*["\']([^"\']+)["\']\s*\)', src))

# Ramas en render: if scr == "..." o elif scr == "..."
render_branches: set[str] = set(re.findall(
    r'(?:if|elif)\s+scr\s*==\s*["\']([^"\']+)["\']', src))

for scr in sorted(nav_calls):
    if scr not in render_branches:
        ln = line_of(rf'navigate\(\s*["\'{re.escape(scr)}["\']')
        E(f'navigate("{scr}") llamada pero sin rama en render()', ln)
    else:
        I(f'  navigate("{scr}") → rama OK')

# Screens accedidas via array (NAV_SCREENS) — no aparecen como navigate("x") literal
NAV_SCREENS_DYNAMIC = set(re.findall(
    r'NAV_SCREENS\s*=\s*\[([^\]]+)\]', src))
dynamic_nav: set[str] = set()
for grp in NAV_SCREENS_DYNAMIC:
    dynamic_nav |= set(re.findall(r'["\']([^"\']+)["\']', grp))

orphan = render_branches - nav_calls - dynamic_nav
for scr in sorted(orphan):
    W(f'render() tiene rama "{scr}" pero nunca se llama navigate("{scr}") '
      f'(ni aparece en NAV_SCREENS)')

errs_nav = sum(1 for s,_,_ in issues if s == "ERROR")
ok = len(nav_calls - (nav_calls - render_branches))
print(f"    {GRN if not (nav_calls - render_branches) else RED}"
      f"{'✅' if not (nav_calls - render_branches) else '❌'} "
      f"{ok}/{len(nav_calls)} screens OK — branches: {sorted(render_branches)}{RST}")

# ── 4. state[] KEY AUDIT ─────────────────────────────────────────────────────
print(f"{BOLD}[4] state dict keys{RST}")

# Encontrar bloque state = { ... }
state_block = re.search(r'\bstate\s*=\s*\{([^}]+)\}', src, re.DOTALL)
state_init: set[str] = set()
if state_block:
    state_init = set(re.findall(r'"([^"]+)"\s*:', state_block.group(1)))
else:
    W("No se encontró 'state = {...}' en el código")

# Todos los accesos state["key"] o state['key']
state_accesses: set[str] = set(
    re.findall(r'\bstate\[["\'"]([^"\']+)["\']\]', src))

for key in sorted(state_accesses - state_init):
    ln = line_of(rf'state\[["\'{re.escape(key)}["\']')
    E(f'state["{key}"] accedido pero NO inicializado en state dict', ln)

errs_st = len(state_accesses - state_init)
print(f"    {GRN if errs_st==0 else RED}{'✅' if errs_st==0 else '❌'} "
      f"{len(state_init)} inicializados | {len(state_accesses)} accedidos | "
      f"{errs_st} sin inicializar{RST}")

# ── 5. ANTI-PATRONES FLET 0.85.1 ────────────────────────────────────────────
print(f"{BOLD}[5] Anti-patrones Flet 0.85.1{RST}")

AP = [
    # (regex_pattern, severity, mensaje)
    (r'page\.snack_bar\s*=',
     "ERROR",
     "page.snack_bar no existe — usa page.show_dialog(ft.SnackBar(...))"),

    (r'page\.pop_dialog\s*\(',
     "ERROR",
     "page.pop_dialog() no funciona — usa _close_dlg()"),

    (r'page\.launch_url\s*\(',
     "ERROR",
     "page.launch_url() falla silenciosamente en Android 11+ — usa url= en el control"),

    (r'ft\.FilePickerResultEvent',
     "ERROR",
     "ft.FilePickerResultEvent no existe en 0.85.1 — usa el valor de retorno .files"),

    (r'page\.show_dialog\s*\(\s*(?:ft\.)?AlertDialog|AlertDialog\s*\(\s*modal',
     "WARN",
     "AlertDialog via page.show_dialog() falla en Android — usa _open_dlg() o navigate()"),

    (r'Container\(.*visible\s*=\s*False.*[Aa]udio|[Aa]udio.*Container.*visible\s*=\s*False',
     "ERROR",
     "Container(visible=False, FletAudio) mata el audio — usa width=1,height=1,bgcolor='transparent'"),

    (r'\bawait\s+asyncio\.sleep\b',
     "ERROR",
     "asyncio.sleep() dentro de page.run_task() puede ser GC'd — usa threading.Timer"),

    (r'page\.show_dialog\s*\(\s*ft\.SnackBar',
     "INFO",
     "page.show_dialog(SnackBar) es el patrón CORRECTO para toasts ✅"),

    (r'\.path\b.*FilePicker|FilePicker.*\.path\b',
     "WARN",
     "FilePickerFile.path puede ser None en Android — usa with_data=True y f.bytes"),

    (r'tempfile\.gettempdir\s*\(\s*\).*wav|wav.*tempfile\.gettempdir',
     "INFO",
     "tempfile.gettempdir() como FALLBACK de desktop — Android usa FLET_APP_STORAGE_DATA ✅"),

    (r'\bft\.ElevatedButton\b',
     "INFO",
     "ft.ElevatedButton detectado — verificar que bgcolor/color/style params existen en 0.85.1"),

    (r'^(?!\s*#).*ft\.ButtonStyle\s*\(.*text_style',
     "ERROR",
     "ButtonStyle(text_style=...) — NO existe en Flet 0.85.1, CRASH garantizado. "
     "Usar _btn() o ButtonStyle(color=...) sin text_style."),

    (r'expand\s*=\s*True.*ft\.Column|ft\.Column.*expand\s*=\s*True',
     "INFO",
     "Column(expand=True) detectado — OK si la pantalla lo necesita"),
]

found_ap = 0
for pat, sev, msg in AP:
    hits = all_lines_of(pat)
    for lineno, line_text in hits:
        stripped = line_text.strip()
        # Ignorar comentarios puros (líneas que empiezan con #)
        if stripped.startswith("#"):
            continue
        snippet = stripped[:80]
        if sev == "ERROR":
            E(f"ANTI-PATRÓN: {msg}\n{'':10}→ L{lineno}: {snippet}", lineno)
            found_ap += 1
        elif sev == "WARN":
            W(f"ANTI-PATRÓN: {msg}\n{'':10}→ L{lineno}: {snippet}", lineno)
            found_ap += 1
        # INFO: solo contabilizar, no imprimir en issues

print(f"    {GRN if found_ap==0 else YEL}{'✅' if found_ap==0 else '⚠️'} "
      f"{found_ap} anti-patrones peligrosos encontrados{RST}")

# ── 6. FUNCIONES INTERNAS REFERENCIADAS SIN DEFINIR ─────────────────────────
print(f"{BOLD}[6] Funciones internas — ¿definidas?{RST}")

INTERNAL_FNS = [
    # La app usa _show_add para AMBOS add+edit (state["edit_id"] controla el modo)
    # No existe _show_edit — quitado de la lista para evitar falso positivo
    "_show_birthday", "_show_home", "_show_add",
    "_show_detail", "_show_calendar", "_show_settings", "_show_help",
    "_show_stats", "_birthday_popup", "_do_test_popup",
    "_open_dlg", "_close_dlg", "_play_birthday_sound",
    "_contact_card", "_toast", "_bdr", "_btn", "_opt_btn",
    "_sec", "_card", "_footer", "_appbar", "_nav_bar",
    "navigate", "render",
]
missing_fns = []
for fn in INTERNAL_FNS:
    if f"def {fn}" not in src and f"def {fn}(" not in src:
        missing_fns.append(fn)
        E(f"Función '{fn}' referenciada pero 'def {fn}' NO encontrada")

if not missing_fns:
    print(f"    {GRN}✅ Todas las funciones internas encontradas{RST}")
else:
    print(f"    {RED}❌ {len(missing_fns)} funciones no definidas: {missing_fns}{RST}")

# ── 7. LAMBDA CLOSURES EN BUCLE FOR ─────────────────────────────────────────
print(f"{BOLD}[7] Closures peligrosos en lambdas dentro de for{RST}")

# Busca patrones como: for x in ...: ... lambda e: fn(x) sin variable capturada
dangerous = []
in_for = False
for i, ln in enumerate(lines):
    if re.search(r'\bfor\s+\w+\s+in\b', ln):
        in_for = True
    if in_for and re.search(r'lambda\s+\w+\s*:', ln):
        # Comprueba si hay una variable libre que debería estar capturada
        m = re.search(r'for\s+(\w+)\s+in', lines[max(0,i-10):i+1][-1] if i>0 else ln)
        if m:
            var = m.group(1)
            lm  = re.search(r'lambda[^:]+:(.+)', ln)
            if lm and var in lm.group(1):
                # La variable del for aparece en el body de la lambda sin estar en args
                lm_args = re.search(r'lambda([^:]+):', ln)
                if lm_args and var not in lm_args.group(1):
                    dangerous.append((i+1, ln.strip()[:80], var))
    if re.search(r'^\s*(def |class )', ln):
        in_for = False

if dangerous:
    for lineno, snippet, var in dangerous:
        W(f"Posible closure bug: variable '{var}' del for sin capturar en lambda\n"
          f"{'':10}→ L{lineno}: {snippet}", lineno)
else:
    print(f"    {GRN}✅ Sin closures peligrosos detectados{RST}")

# ── 8. page.add() SIN page.update() — solo en _show_birthday ────────────────
print(f"{BOLD}[8] _show_birthday — verificación de controles{RST}")

# Extraer el cuerpo de _show_birthday
bd_match = re.search(
    r'def _show_birthday\(\):(.*?)(?=\n    def |\n    # ─{10})', src, re.DOTALL)

if bd_match:
    bd_body = bd_match.group(1)

    # Verificar que page.add() existe
    if "page.add(" not in bd_body:
        E("_show_birthday() no llama page.add() — la pantalla quedará en blanco")

    # Verificar que no usa AlertDialog (ignorar docstrings/comentarios)
    # Buscar ft.AlertDialog o AlertDialog( fuera de comentarios/strings
    bd_code_lines = [ln for ln in bd_body.splitlines()
                     if not ln.lstrip().startswith('#')
                     and not ln.lstrip().startswith('"""')
                     and not ln.lstrip().startswith("'''")]
    bd_code_only = "\n".join(bd_code_lines)
    if re.search(r'(?:ft\.)?AlertDialog\s*\(', bd_code_only):
        E("_show_birthday() contiene AlertDialog() — debería usar solo controles Flet")

    # Verificar que usa _play_birthday_sound()
    if "_play_birthday_sound" not in bd_body:
        W("_show_birthday() no llama _play_birthday_sound() — sin sonido")

    # Verificar navigate("home") en _celebrate
    if 'navigate("home")' not in bd_body and "navigate('home')" not in bd_body:
        W("_show_birthday(): _celebrate no llama navigate('home') — el botón podría no funcionar")

    # ft.ButtonStyle con text_style (no existe en Flet 0.85.1 — CRASH garantizado)
    if re.search(r'ButtonStyle\s*\(.*text_style', bd_code_only):
        E("_show_birthday() usa ButtonStyle(text_style=...) — NO existe en Flet 0.85.1, CRASH garantizado. "
          "Usar _btn() en su lugar.")

    print(f"    {GRN}✅ _show_birthday() encontrada y verificada{RST}")
else:
    E("No se pudo extraer el cuerpo de _show_birthday() para auditarlo")
    print(f"    {RED}❌ No se puede auditar _show_birthday(){RST}")

# ── 9. SETTINGS — _toggle_remind_all DEFINIDA DENTRO DE _show_settings ───────
print(f"{BOLD}[9] Settings — _toggle_remind_all{RST}")

if "_toggle_remind_all" in src:
    if "def _toggle_remind_all" in src:
        # Verificar que está dentro de _show_settings (debe venir después de su def)
        idx_settings = src.find("def _show_settings")
        idx_toggle   = src.find("def _toggle_remind_all")
        if idx_toggle > idx_settings:
            print(f"    {GRN}✅ _toggle_remind_all definida dentro de _show_settings{RST}")
        else:
            W("_toggle_remind_all definida ANTES de _show_settings — podría no tener acceso al closure de db/render")
    else:
        E("_toggle_remind_all referenciada pero 'def _toggle_remind_all' no encontrada")
        print(f"    {RED}❌ _toggle_remind_all no definida{RST}")
else:
    W("_toggle_remind_all no aparece en el código — el toggle de 'recordar todo el día' no funcionará")
    print(f"    {YEL}⚠️  _toggle_remind_all no encontrada{RST}")

# ── 10. RESUMEN FINAL ─────────────────────────────────────────────────────────
errors_all   = [(sev,ln,msg) for sev,ln,msg in issues if sev == "ERROR"]
warnings_all = [(sev,ln,msg) for sev,ln,msg in issues if sev == "WARN"]
infos_all    = [(sev,ln,msg) for sev,ln,msg in issues if sev == "INFO"]

print(f"\n{BOLD}{CYN}{'═'*66}{RST}")
print(f"{BOLD}  RESULTADO: "
      f"{RED}{len(errors_all)} ERROR(ES){RST}{BOLD}  "
      f"{YEL}{len(warnings_all)} WARNING(S){RST}{BOLD}  "
      f"{GRN}{len(infos_all)} INFO{RST}")
print(f"{BOLD}{CYN}{'═'*66}{RST}")

if errors_all:
    print(f"\n{RED}{BOLD}🔴 ERRORES (deben corregirse):{RST}")
    for _, ln, msg in errors_all:
        loc = f" [L{ln}]" if ln else ""
        # Indent wrapped lines
        lines_msg = msg.split('\n')
        print(f"  {RED}●{RST}{loc} {lines_msg[0]}")
        for extra in lines_msg[1:]:
            print(f"    {extra}")

if warnings_all:
    print(f"\n{YEL}{BOLD}🟡 WARNINGS (revisar):{RST}")
    for _, ln, msg in warnings_all:
        loc = f" [L{ln}]" if ln else ""
        lines_msg = msg.split('\n')
        print(f"  {YEL}●{RST}{loc} {lines_msg[0]}")
        for extra in lines_msg[1:]:
            print(f"    {extra}")

if not errors_all and not warnings_all:
    print(f"\n{GRN}{BOLD}✅ Sin errores ni warnings — main.py limpio.{RST}")
elif not errors_all:
    print(f"\n{GRN}{BOLD}✅ Sin errores críticos. Solo warnings.{RST}")

print()
