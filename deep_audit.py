"""
deep_audit.py — Auditoría exhaustiva de main.py para Celebria (v2)
Detecta bugs, anti-patrones Flet 0.85.1, problemas async/await,
thread safety, overlay management, y más.
Uso: python deep_audit.py
"""
import ast, re, sys
from pathlib import Path

SRC_FILE = Path(__file__).parent / "main.py"
src = SRC_FILE.read_text(encoding="utf-8-sig")   # utf-8-sig strips BOM
lines = src.splitlines()

# Versión del source sin docstrings/strings para checks de código real
def _strip_strings(text):
    """Reemplaza contenido de strings con espacios (preserva longitud/líneas)."""
    result = []
    i = 0
    while i < len(text):
        # Triple-quoted strings
        for q in ('"""', "'''"):
            if text[i:i+3] == q:
                end = text.find(q, i+3)
                if end == -1:
                    end = len(text) - 3
                chunk = text[i:end+3]
                result.append('\n' * chunk.count('\n'))
                i = end + 3
                break
        else:
            # Single-quoted strings (non-greedy, single line)
            if text[i] in ('"', "'"):
                q = text[i]
                j = i + 1
                while j < len(text) and text[j] != q and text[j] != '\n':
                    if text[j] == '\\':
                        j += 1
                    j += 1
                result.append(' ' * (j - i + 1))
                i = j + 1
            else:
                result.append(text[i])
                i += 1
    return ''.join(result)

src_code_only = _strip_strings(src)   # para checks de código real (sin docstrings)

errors   = []
warnings = []
infos    = []

def E(msg, lineno=None):
    tag = f" [línea {lineno}]" if lineno else ""
    errors.append(f"❌ ERROR{tag}: {msg}")

def W(msg, lineno=None):
    tag = f" [línea {lineno}]" if lineno else ""
    warnings.append(f"🟡 WARN{tag}: {msg}")

def I(msg):
    infos.append(f"ℹ️  {msg}")

def find_lines(pattern, text=None, flags=re.MULTILINE):
    text = text or src
    return [(m.start(), src[:m.start()].count('\n') + 1)
            for m in re.finditer(pattern, text, flags)]

def lineno_of(pattern, text=None):
    text = text or src
    m = re.search(pattern, text, re.MULTILINE)
    return (src[:m.start()].count('\n') + 1) if m else None

def skip_comments(line):
    """True si la línea es solo un comentario Python."""
    return line.strip().startswith('#')

# ──────────────────────────────────────────────────────────────
# 1. SINTAXIS PYTHON
# ──────────────────────────────────────────────────────────────
print("[1] Sintaxis Python...")
try:
    tree = ast.parse(src, filename=str(SRC_FILE))
    I("Sintaxis Python OK")
except SyntaxError as e:
    E(f"SyntaxError en línea {e.lineno}: {e.msg}")
    print("\n".join(errors)); sys.exit(1)

# ──────────────────────────────────────────────────────────────
# 2. ANTI-PATRONES FLET 0.85.1 CONOCIDOS
# ──────────────────────────────────────────────────────────────
print("[2] Anti-patrones Flet 0.85.1...")

def check_pattern(pattern, msg, is_error=True, skip_comments_flag=True):
    for m in re.finditer(pattern, src, re.MULTILINE):
        pos = m.start()
        ln  = src[:pos].count('\n') + 1
        line = lines[ln-1]
        if skip_comments_flag and skip_comments(line):
            continue
        if is_error:
            E(msg, ln)
        else:
            W(msg, ln)

# ft.alignment.<x> → AttributeError
check_pattern(r'\bft\.alignment\.\w+',
    "ft.alignment.<x> NO existe en Flet 0.85.1. Usar ft.Alignment.CENTER (mayúscula A). AttributeError garantizado.")

# ButtonStyle(text_style=...) → crash
check_pattern(r'ButtonStyle\s*\([^)]*text_style',
    "ButtonStyle(text_style=...) NO existe en Flet 0.85.1 — CRASH. Usar _btn() o ButtonStyle(color=...)")

# page.snack_bar → no existe
check_pattern(r'page\.snack_bar',
    "page.snack_bar NO existe en Flet 0.85.1. Usar page.show_dialog(ft.SnackBar(...))")

# page.launch_url() → falla en Android 11+
check_pattern(r'page\.launch_url\s*\(',
    "page.launch_url() falla silenciosamente en Android 11+. Usar url= en el control (ft.TextButton, ft.Container, etc.)")

# ft.FilePickerResultEvent → no existe
check_pattern(r'ft\.FilePickerResultEvent',
    "ft.FilePickerResultEvent NO existe en Flet 0.85.1. Usar .files directamente")

# page.pop_dialog() → no usar
check_pattern(r'page\.pop_dialog\s*\(',
    "page.pop_dialog() — NO usar. Usar _close_dlg() helper")

# visible=False en Container con Audio — desconecta el widget
for m in re.finditer(r'Container\s*\([^)]*visible\s*=\s*False', src, re.DOTALL):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    if skip_comments(lines[ln-1]):
        continue
    ctx = src[max(0, pos-300):pos+400]
    if 'Audio' in ctx or 'FletAudio' in ctx:
        E("Container(visible=False) con FletAudio — Flutter desmonta el audio. "
          "Usar width=1, height=1, bgcolor='transparent'", ln)

# page.show_dialog(AlertDialog) — solo verificar en código real (no comments, no _show_birthday context)
for m in re.finditer(r'page\.show_dialog\s*\(', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    line = lines[ln-1].strip()
    if skip_comments(line):
        continue
    # Verificar qué se pasa: si es AlertDialog (no SnackBar), es un problema
    chunk = src[pos:pos+200]
    if 'AlertDialog' in chunk and 'SnackBar' not in chunk:
        W("page.show_dialog(AlertDialog) puede fallar en Android Flet 0.85.1. "
          "Usar _open_dlg()/_close_dlg() para AlertDialog; page.show_dialog() solo para SnackBar", ln)

# ──────────────────────────────────────────────────────────────
# 3. ASYNC/AWAIT — métodos async de flet_audio sin await
# ──────────────────────────────────────────────────────────────
print("[3] Async/await — flet_audio...")

ASYNC_AUDIO_METHODS = ["play", "pause", "resume", "seek", "release",
                       "get_current_position", "get_duration"]

for method in ASYNC_AUDIO_METHODS:
    for m in re.finditer(rf'\b(\w+)\.{method}\s*\(', src_code_only):
        pos = m.start()
        ln  = src[:pos].count('\n') + 1
        line = lines[ln-1].strip()
        # Skip comments, definitions, inline comments, and docstrings
        if skip_comments(line) or line.startswith('def ') or line.startswith('async def '):
            continue
        # Skip if inside a comment portion of the line (after #)
        code_part = line.split('#')[0]
        if method + '()' not in code_part and method + '(' not in code_part:
            continue
        # Skip if inside a string literal (docstring) — check if line is quoted
        if line.startswith('"""') or line.startswith("'''") or line.startswith('"') or line.startswith("'"):
            continue
        # Skip if already awaited
        pre = src[max(0, pos-30):pos]
        if 'await' in pre.split('\n')[-1]:
            continue
        var_name = m.group(1)
        # Only flag if the variable is an Audio control
        is_audio = (
            re.search(rf'\b{re.escape(var_name)}\s*=\s*(?:FletAudio|Audio)\s*\(', src)
            or var_name in ('snd', 'audio', '_audio', 'snd_obj', '_snd')
        )
        if is_audio:
            E(f"'{var_name}.{method}()' es async — NO se puede llamar sin 'await'. "
              f"Coroutine creada pero NUNCA ejecutada. "
              f"Solución: eliminar la llamada y confiar en autoplay=True, "
              f"o usar await desde contexto async.", ln)

# FilePicker async methods
for method in ["pick_files", "save_file", "pick_directory"]:
    for m in re.finditer(rf'\b(\w+)\.{method}\s*\(', src):
        pos = m.start()
        ln  = src[:pos].count('\n') + 1
        line = lines[ln-1].strip()
        if skip_comments(line):
            continue
        pre = src[max(0, pos-30):pos]
        if 'await' in pre.split('\n')[-1]:
            continue
        var_name = m.group(1)
        is_picker = (
            re.search(rf'\b{re.escape(var_name)}\s*=\s*ft\.FilePicker\s*\(', src)
            or 'picker' in var_name.lower()
        )
        if is_picker:
            E(f"'{var_name}.{method}()' es async en Flet 0.85.1 — sin 'await', el botón no hace nada. "
              f"Usar async def handler: files = await {var_name}.{method}(...)", ln)

# ──────────────────────────────────────────────────────────────
# 4. THREAD SAFETY — page.update() desde background threads
# ──────────────────────────────────────────────────────────────
print("[4] Thread safety...")

# Buscar threading.Timer(x, fn) — verificar si fn llama page.update() sin run_task
timer_callbacks = re.findall(r'threading\.Timer\s*\([^,]+,\s*(\w+)\)', src)
for cb in set(timer_callbacks):
    cb_def = re.search(rf'def\s+{re.escape(cb)}\s*\(', src)
    if not cb_def:
        continue
    start = cb_def.start()
    func_slice = src[start:start+1500]
    # Check for direct page.update() NOT inside a nested run_task
    # Find page.update() before any run_task
    update_pos = func_slice.find('page.update()')
    runtask_pos = func_slice.find('run_task')
    if update_pos != -1 and (runtask_pos == -1 or update_pos < runtask_pos):
        ln = src[:start].count('\n') + 1
        E(f"Función '{cb}' (callback de threading.Timer) llama page.update() directamente — "
          f"UNSAFE desde background thread. Envolver en page.run_task(async_fn)", ln)

# Lambdas en Timer que llamen page.update() sin run_task
for m in re.finditer(r'Timer\s*\([^,]+,\s*lambda[^:]*:\s*([^\n]+)', src):
    body = m.group(1)
    if 'page.update' in body and 'run_task' not in body:
        ln = src[:m.start()].count('\n') + 1
        E("threading.Timer lambda llama page.update() sin page.run_task() — unsafe", ln)

# ──────────────────────────────────────────────────────────────
# 5. OVERLAY MANAGEMENT
# ──────────────────────────────────────────────────────────────
print("[5] Overlay management...")

for m in re.finditer(r'page\.overlay\.append\s*\(', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    if skip_comments(lines[ln-1]):
        continue
    # Look ahead ~300 chars for page.update()
    after = src[pos:pos+300]
    after_lines = after.splitlines()[1:6]
    if not any('page.update' in l for l in after_lines):
        W(f"page.overlay.append() sin page.update() inmediato — "
          f"puede corromper estado WebSocket", ln)

# FletAudio NO debe estar en page.controls — solo en page.overlay
# Detectar FletAudio como content= en un Column/Row/Stack (no en Container de overlay)
for m in re.finditer(r'FletAudio\s*\(', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    if skip_comments(lines[ln-1]):
        continue
    # Buscar contexto: ¿está asignado a variable y esa var se mete en overlay?
    # La señal de error es si aparece directamente en controls= de Column/Row
    pre = src[max(0, pos-800):pos]
    if 'controls=[' in pre and 'overlay' not in pre[-400:] and 'wrapper' not in pre[-200:]:
        W(f"Posible FletAudio en controls= en vez de overlay. "
          f"FletAudio SOLO puede ir en page.overlay (dentro de Container 1x1 transparente)", ln)

# ──────────────────────────────────────────────────────────────
# 6. T-STRING KEYS (estructura real: T = {"es": {...}, "en": {...}})
# ──────────────────────────────────────────────────────────────
print("[6] T-string keys...")

es_match = re.search(r'"es"\s*:\s*\{(.*?)\n    \}', src, re.DOTALL)
en_match = re.search(r'"en"\s*:\s*\{(.*?)\n    \}', src, re.DOTALL)

t_defs_es = set(re.findall(r'"(\w+)"\s*:', es_match.group(1))) if es_match else set()
t_defs_en = set(re.findall(r'"(\w+)"\s*:', en_match.group(1))) if en_match else set()
t_calls   = set(re.findall(r'\bt\(\s*["\'](\w+)["\']\s*\)', src))

missing_es = t_calls - t_defs_es
missing_en = t_calls - t_defs_en
unused     = (t_defs_es | t_defs_en) - t_calls

for k in sorted(missing_es):
    ln = lineno_of(rf't\(["\']{{re.escape(k)}}["\']\)')
    E(f"T key '{k}' usada en t() pero NO definida en ES dict")
for k in sorted(missing_en):
    E(f"T key '{k}' usada en t() pero NO definida en EN dict")
for k in sorted(unused):
    W(f"T key '{k}' definida pero nunca usada (dead code)")

I(f"T-keys: {len(t_calls)} usadas | {len(t_defs_es)} ES | {len(t_defs_en)} EN | "
  f"{len(missing_es)} faltantes ES | {len(missing_en)} faltantes EN | {len(unused)} unused")

# ──────────────────────────────────────────────────────────────
# 7. NAVIGATE / RENDER BRANCHES
# ──────────────────────────────────────────────────────────────
print("[7] Navigate/render branches...")

screens_navigate = set(re.findall(r'navigate\s*\(\s*["\'](\w+)["\']', src))
# Render branches: if/elif scr == "x": or == 'x':
render_branches  = set(re.findall(r'(?:if|elif)\s+scr\s*==\s*["\'](\w+)["\']', src))

for s in sorted(screens_navigate):
    if s not in render_branches:
        E(f"navigate('{s}') llamado pero no hay rama 'scr == \"{s}\"' en render()")

for s in sorted(render_branches):
    if s not in screens_navigate:
        W(f"render() tiene rama '{s}' pero navigate('{s}') nunca se llama")

I(f"Screens navigate={sorted(screens_navigate)} | render={sorted(render_branches)}")

# ──────────────────────────────────────────────────────────────
# 8. STATE KEYS
# ──────────────────────────────────────────────────────────────
print("[8] State keys...")

state_init_match = re.search(r'state\s*=\s*\{([^}]+)\}', src, re.DOTALL)
if state_init_match:
    init_keys = set(re.findall(r'["\'](\w+)["\']', state_init_match.group(1)))
else:
    init_keys = set()
    W("No se encontró 'state = {...}' en main.py")

access_keys = set(re.findall(r'state\s*\[\s*["\'](\w+)["\']\s*\]', src))
uninit = access_keys - init_keys

for k in sorted(uninit):
    ln = lineno_of(rf'state\[["\']{re.escape(k)}["\']\]')
    E(f"state['{k}'] accedido pero no inicializado en dict state", ln)

I(f"State: {len(init_keys)} init | {len(access_keys)} accedidos | {len(uninit)} sin inicializar")

# ──────────────────────────────────────────────────────────────
# 9. FUNCIONES INTERNAS — ¿definidas?
# ──────────────────────────────────────────────────────────────
print("[9] Funciones internas...")

INTERNAL_FNS = [
    "_toast", "_open_dlg", "_close_dlg", "_btn", "_field",
    "_play_birthday_sound", "_show_birthday", "_show_home",
    "_show_settings", "_show_detail", "_show_add",
    "_show_calendar", "_show_stats", "_show_help",
    "_avatar", "_contact_card", "navigate", "render", "t",
    "_parse_vcf", "_gen_birthday_wav", "_verify_genesis",
    "days_until",
]
for fn in INTERNAL_FNS:
    if not re.search(rf'\bdef\s+{re.escape(fn)}\s*\(', src):
        W(f"Función '{fn}' referenciada pero no se encontró 'def {fn}('")

# ──────────────────────────────────────────────────────────────
# 10. _show_birthday — verificaciones
# ──────────────────────────────────────────────────────────────
print("[10] _show_birthday()...")

bd_match = re.search(
    r'(def _show_birthday\s*\(.*?)(?=\n    # ────|$)',
    src, re.DOTALL
)
if not bd_match:
    E("_show_birthday() no encontrada")
else:
    bd_body = bd_match.group(1)

    if 'page.add(' not in bd_body:
        E("_show_birthday() no llama page.add() — pantalla en blanco")

    bd_code_lines = [l for l in bd_body.splitlines()
                     if not l.strip().startswith('#')
                     and not l.strip().startswith('"""')]
    bd_code = '\n'.join(bd_code_lines)

    if re.search(r'(?:ft\.)?AlertDialog\s*\(', bd_code):
        E("_show_birthday() contiene AlertDialog() — usar solo controles Flet estándar")

    if 'navigate("home")' not in bd_body and "navigate('home')" not in bd_body:
        W("_show_birthday(): botón de celebrar no llama navigate('home')")

    # Audio: v1.4.18 pattern — timer inside _show_birthday
    has_audio_internal = '_play_birthday_sound' in bd_body
    has_audio_pre_nav  = '_play_birthday_sound' in src  # caller pattern
    if not has_audio_internal and not has_audio_pre_nav:
        E("Sin lógica de audio en main.py — no habrá sonido en el popup")
    elif has_audio_internal:
        # v1.4.19+: widget persistente en overlay — llamada directa es correcta
        # porque page.run_task(snd.play) schedula DESPUÉS de que el handler retorna
        if '_PERSISTENT_AUDIO' in src or 'page.run_task' in bd_body:
            I("_show_birthday() llama _play_birthday_sound() directamente (widget persistente, patrón v1.4.19) ✓")
        elif 'Timer' in bd_body:
            I("_show_birthday() usa threading.Timer para audio ✓")
        else:
            W("_show_birthday() llama _play_birthday_sound() sin Timer ni widget persistente — "
              "puede fallar si Flutter aún procesa page.add()")

# ──────────────────────────────────────────────────────────────
# 11. BIRTHDAY TIMER — secuencia correcta
# ──────────────────────────────────────────────────────────────
print("[11] Birthday timer...")

fire_match = re.search(r'def _fire_birthday_popup.*?_bd_timer\.start\(\)', src, re.DOTALL)
if fire_match:
    fire_body = fire_match.group(0)
    if 'page.run_task' not in fire_body:
        W("_fire_birthday_popup no usa page.run_task() — unsafe si se llama desde Timer thread")
    if 'navigate' not in fire_body:
        W("_fire_birthday_popup no llama navigate()")
    if '_play_birthday_sound' in fire_body:
        # Verificar que no está justo antes de navigate en el mismo async block
        W("_fire_birthday_popup llama _play_birthday_sound() antes de navigate() — "
          "múltiples page.update() en el mismo handler pueden corromper el estado")
    else:
        I("_fire_birthday_popup: navigate sin sonido (sonido en _show_birthday) ✓")

# ──────────────────────────────────────────────────────────────
# 12. _do_test_popup — no debe llamar _play_birthday_sound antes de navigate
# ──────────────────────────────────────────────────────────────
print("[12] _do_test_popup()...")

tp_match = re.search(r'def _do_test_popup.*?(?=\n    # |\n    def )', src, re.DOTALL)
if tp_match:
    tp_body = tp_match.group(0)
    if '_play_birthday_sound' in tp_body:
        # Verificar si está antes de navigate (problema) o en Timer (OK)
        play_pos = tp_body.find('_play_birthday_sound')
        nav_pos  = tp_body.find('navigate(')
        timer_pos = tp_body.find('Timer')
        if play_pos < nav_pos and timer_pos == -1:
            W("_do_test_popup() llama _play_birthday_sound() ANTES de navigate() sin Timer delay — "
              "múltiples page.update() en el mismo handler, posible corrupción")
        else:
            I("_do_test_popup(): audio separado de navigate (Timer o post-navigate) ✓")
    else:
        I("_do_test_popup(): no llama _play_birthday_sound() directamente ✓")

# ──────────────────────────────────────────────────────────────
# 13. VARIABLE SHADOWING — 't' → t() función de traducción
# ──────────────────────────────────────────────────────────────
print("[13] Variable shadowing...")

for m in re.finditer(r'\bt\s*=\s*threading\.Timer', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    E(f"'t = threading.Timer(...)' hace shadow de la función global t() (traducción). "
      f"Renombrar a '_cleanup_timer'", ln)

# ──────────────────────────────────────────────────────────────
# 14. FILEPICKER — path sin verificar None
# ──────────────────────────────────────────────────────────────
print("[14] FilePicker...")

for m in re.finditer(r'\bf\.path\b', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    ctx = src[max(0, pos-300):pos+200]
    if 'with_data' not in ctx and 'f.bytes' not in ctx:
        W(f"f.path usado sin verificar None — en Android puede ser None. "
          f"Usar with_data=True y f.bytes", ln)

# ──────────────────────────────────────────────────────────────
# 15. APP_VERSION
# ──────────────────────────────────────────────────────────────
print("[15] APP_VERSION...")
ver_match = re.search(r'APP_VERSION\s*=\s*["\']([^"\']+)["\']', src)
if ver_match:
    I(f"APP_VERSION = {ver_match.group(1)}")
else:
    W("APP_VERSION no encontrado")

# ──────────────────────────────────────────────────────────────
# 16. page.run_task — pasar función vs coroutine
# ──────────────────────────────────────────────────────────────
print("[16] page.run_task() usage...")

for m in re.finditer(r'page\.run_task\s*\(\s*(\w+)\s*\(\s*\)\s*\)', src):
    pos = m.start()
    ln  = src[:pos].count('\n') + 1
    fn_name = m.group(1)
    if skip_comments(lines[ln-1]):
        continue
    if re.search(rf'async\s+def\s+{re.escape(fn_name)}\s*\(', src):
        W(f"page.run_task({fn_name}()) — se pasa coroutine object (fn ya llamada). "
          f"Verificar si Flet espera callable o coroutine para run_task", ln)

# ──────────────────────────────────────────────────────────────
# 17. CLOSURES PELIGROSOS EN FOR LOOPS (lambda sin default arg)
# ──────────────────────────────────────────────────────────────
print("[17] Closures en lambdas...")

# Buscar for + lambda en el mismo bloque donde lambda usa la var del for
# solo si la variable no tiene default arg (lambda x=var: ...)
for m in re.finditer(r'for\s+(\w+)\s+in\s+[^\n:]+:', src):
    var = m.group(1)
    for_pos = m.end()
    # Buscar siguiente lambda que capture var sin default
    block = src[for_pos:for_pos+500]
    for lm in re.finditer(rf'lambda\s+(?!{re.escape(var)}\s*=)[^:]*:\s*[^\n]*\b{re.escape(var)}\b', block):
        ln = src[:for_pos + lm.start()].count('\n') + 1
        W(f"lambda captura '{var}' del for loop sin default arg — posible closure bug. "
          f"Usar lambda {var}={var}: ...", ln)
        break  # Solo reportar una vez por for

# ──────────────────────────────────────────────────────────────
# REPORTE FINAL
# ──────────────────────────────────────────────────────────────
print("\n" + "=" * 70)
print(f"  CELEBRIA DEEP AUDIT v2 — main.py  ({len(lines)} líneas)")
print("=" * 70)

if errors:
    print(f"\n  ❌ ERRORES ({len(errors)}):")
    for e in errors:
        print(f"  {e}")

if warnings:
    print(f"\n  🟡 WARNINGS ({len(warnings)}):")
    for w in warnings:
        print(f"  {w}")

if infos:
    print(f"\n  ℹ️  INFO ({len(infos)}):")
    for i in infos:
        print(f"  {i}")

print(f"\n{'='*70}")
print(f"  RESULTADO: {len(errors)} ERROR(ES)  {len(warnings)} WARNING(S)  {len(infos)} INFO")
print(f"{'='*70}\n")

sys.exit(1 if errors else 0)
