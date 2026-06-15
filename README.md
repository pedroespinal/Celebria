# 🎂 Celebria

**Recordatorio de Cumpleaños para Android**

Celebria es una app Android personal para nunca olvidar un cumpleaños.  
Diseño futurista oscuro, bilingüe ES/EN, sin publicidad y sin conexión requerida para su uso principal.

[![Versión](https://img.shields.io/badge/versión-1.5.1-00e5ff?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Plataforma](https://img.shields.io/badge/plataforma-Android-00ff88?style=flat-square)](https://github.com/pedroespinal/Celebria/releases/latest)
[![Python](https://img.shields.io/badge/Python-3-yellow?style=flat-square)](https://www.python.org/)
[![Flet](https://img.shields.io/badge/Flet-0.85.1-7c3aed?style=flat-square)](https://flet.dev/)

---

## 📥 Descargar

| Canal | Link |
|-------|------|
| ⬇ APK más reciente | [GitHub Releases](https://github.com/pedroespinal/Celebria/releases/latest) |
| 📋 Historial de versiones | [Todos los releases](https://github.com/pedroespinal/Celebria/releases) |

> **Nota:** Al instalar un APK descargado directamente, Android pedirá permiso para instalar apps de fuentes externas. Es normal — acepta y continúa.

---

## ✨ Características

- 🔔 **Notificaciones push** — avisa automáticamente del cumpleaños aunque la app esté cerrada, a la hora que configures
- 🎂 Popup de felicitación al abrir la app el día del cumpleaños, con melodía festiva generada en memoria
- 👥 Contactos con nombre, fecha, teléfono, email, notas y tipo de relación (Familia / Amigo / Trabajo / Otro)
- 📸 **Foto por contacto** — avatar personalizado o círculo con inicial en el color de la relación
- 🎁 **Nota de regalo** — guarda ideas de regalo por contacto
- 📊 **Estadísticas rápidas** — resumen total, cumpleaños próximos, distribución por relación y por mes
- 📱 **Importar desde Agenda** — lee archivos `.vcf` y extrae contactos con cumpleaños registrados
- 📋 Secciones automáticas: **Hoy · Esta Semana · Próximamente · Todos**
- 🔍 Búsqueda en tiempo real (teclado siempre abierto) + filtro por tipo de relación
- 📆 Calendario mensual con días de cumpleaños destacados
- 💬 Botón WhatsApp directo por contacto
- 📤 Exportar / Importar contactos en JSON
- 🌙 Tema oscuro / claro con toggle instantáneo
- 🌐 Bilingüe Español / Inglés con cambio en tiempo real (incluyendo footer y About)
- 🔄 Verificador de actualizaciones automático al abrir la app (aparece en Home)
- 🔒 Sistema de versión mínima forzada vía `version.json`

---

## 🛠 Stack técnico

| Componente       | Tecnología                                      |
|------------------|-------------------------------------------------|
| Lenguaje         | Python 3                                        |
| UI Framework     | Flet 0.85.1 → Flutter → Android                |
| Base de datos    | SQLite (local, sin servidor)                    |
| Audio            | flet_audio 0.85.1                              |
| Push notifications | flutter_local_notifications + sqflite + timezone + flutter_timezone |
| Build            | `flet build apk` + `flutter build apk --release` (2 pasos) |
| Release          | PowerShell + GitHub Releases API               |
| Credenciales     | Windows Credential Manager                      |

---

## 📁 Estructura del proyecto

```
C:\Celebria\
├── main.py                            # App completa en un solo archivo (~3044 líneas)
├── requirements.txt                   # flet-audio==0.85.1
├── pyproject.toml                     # Config Flet + paquetes Flutter de notificaciones
├── version.json                       # Control de versiones para actualizaciones in-app
├── release.ps1                        # Script de release completamente automatizado
├── README.md                          # Este archivo
├── flutter/                           # Overlay de archivos Dart personalizados
│   ├── lib/
│   │   ├── main.dart                  # Entry point con NotificationHelper.initialize()
│   │   └── notification_helper.dart  # Lógica de notificaciones push
│   ├── android/
│   │   ├── AndroidManifest.xml       # Permisos: POST_NOTIFICATIONS, BOOT_COMPLETED, VIBRATE
│   │   └── app/
│   │       └── build.gradle.kts      # isCoreLibraryDesugaringEnabled + desugar_jdk_libs
│   └── pubspec.yaml                   # (referencia — las deps van en pyproject.toml)
└── .gitignore
```

---

## 🔔 Cómo funcionan las notificaciones push

Las notificaciones se programan **cada vez que el usuario abre la app**. El código Dart
lee la base de datos SQLite, obtiene todos los contactos y agenda una notificación
por persona para el próximo cumpleaños (o N días antes, según la configuración).

La notificación usa `AndroidScheduleMode.inexactAllowWhileIdle` — se dispara dentro
de ±1 hora de la hora configurada, incluso en modo Doze, **sin requerir el permiso
`SCHEDULE_EXACT_ALARM`** (que en Android 12+ requiere aprobación del fabricante).

**Requisito en Android 13+:** la app pedirá permiso `POST_NOTIFICATIONS` la primera
vez que se abre. Si el usuario lo deniega, no llegará ninguna notificación.
Para activarlo después: Ajustes → Apps → Celebria → Permisos → Notificaciones → ON.

---

## 🔧 Cómo compilar

El build es un proceso de **dos fases** (necesario para incluir el código Dart de notificaciones):

```powershell
# Requisitos previos:
# - Python 3 + Flet 0.85.1 (pip install flet==0.85.1)
# - Flutter SDK en PATH
# - Android SDK con licencias aceptadas
# - Java 17

Set-Location "C:\Celebria"

# Fase 1: Flet empaqueta el código Python en app.zip y genera el proyecto Flutter
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8       = "1"
$env:NO_COLOR         = "1"
chcp 65001
flet build apk --artifact "Celebria-X.Y.Z"
# Puede fallar en el paso de Gradle — es normal; app.zip ya está creado

# Fase 2: Compilar Flutter con el código de notificaciones
# (release.ps1 hace esto automáticamente en el paso 2.5)
$env:SERIOUS_PYTHON_SITE_PACKAGES = "$PWD\build\site-packages"
Set-Location "build\flutter"
flutter build apk --release --no-version-check --suppress-analytics
# APK en: build\flutter\build\app\outputs\apk\release\app-release.apk
```

> **Nota:** `release.ps1` maneja este proceso completo automáticamente.

---

## 🚀 Cómo publicar un release

```powershell
.\release.ps1 -Version "X.Y.Z" -Notes "Descripción del cambio" -SkipTest
```

El script hace todo automáticamente en 6 pasos:

1. ~~Prueba local~~ (omitida con `-SkipTest`)
2. Actualiza `APP_VERSION` en `main.py`
3. Actualiza `version.json` (`latest` + `download_url`)
4. **[2/6]** `flet build apk` — empaqueta Python (puede fallar en Gradle, solo importa que `app.zip` se cree)
5. **[2.5/6]** Copia archivos Dart personalizados, inyecta paquetes de notificación, recompila con `flutter build apk --release`
6. `git commit` + `git tag` + `git push`
7. Crea el release en GitHub vía API y sube el APK

> Requiere token OAuth de GitHub almacenado en Windows Credential Manager  
> bajo la clave `git:https://github.com`

---

## 🔄 Sistema de actualizaciones forzadas

La app lee `version.json` al arrancar para verificar si hay una versión nueva:

```json
{
  "latest":       "1.5.1",
  "minimum":      "1.0.0",
  "download_url": "https://github.com/pedroespinal/Celebria/releases/download/v1.5.1/Celebria-v1.5.1.apk"
}
```

| Campo          | Actualizado por     | Propósito                                      |
|----------------|---------------------|------------------------------------------------|
| `latest`       | `release.ps1`       | Versión más reciente disponible                |
| `minimum`      | **Manual**          | Versión mínima soportada                       |
| `download_url` | `release.ps1`       | Link directo al APK (referencia)               |

**Lógica:**
- `instalada < minimum` → diálogo obligatorio, sin opción de cerrar
- `minimum ≤ instalada < latest` → diálogo sugerido con opción "Ahora no"
- `instalada == latest` → silencioso

El botón "Descargar" abre la **página de releases** de GitHub (no la URL directa del APK) para garantizar que Chrome en Android complete la descarga correctamente.

Para forzar una actualización: editar `minimum` directamente en GitHub y hacer push.  
No requiere recompilar la app.

---

## ⚠ Quirks conocidos

- `flet build apk` requiere `chcp 65001` + `NO_COLOR=1` en Windows para evitar crash de Unicode por la librería `rich`
- `flet_audio` se envuelve en `Container(visible=False)` → Flutter Offstage: el control funciona (audio) pero no se renderiza, evitando la barra roja
- `flutter_local_notifications` requiere `isCoreLibraryDesugaringEnabled = true` + `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` en `build.gradle.kts` — sin esto Gradle falla con `checkReleaseAarMetadata`
- `flutter build apk --release` directo (sin Flet) requiere `$env:SERIOUS_PYTHON_SITE_PACKAGES = "$PWD\build\site-packages"` o Gradle falla con "SERIOUS_PYTHON_SITE_PACKAGES is not set"
- `FilePicker` genera "Unknown control" red bar si se añade a `page.overlay`. Fix definitivo: declarar los pickers ANTES de `render()` y registrarlos DESPUÉS con `page._services.register_service(picker)`. Registrar antes de `render()` causa **pantalla negra**
- `FilePicker.pick_files()` es **async** en Flet 0.85.1 — usar `async def handler(e): files = await picker.pick_files(...)`. Sin `await` retorna una corutina que se descarta silenciosamente
- `ft.FilePickerResultEvent` no existe en Flet 0.85.1
- `page.launch_url()` falla silenciosamente en Android 11+ — usar siempre la propiedad `url=` directamente en el control
- `page.snack_bar` no existe en Flet 0.85.1 — usar `page.show_dialog(ft.SnackBar(...))`
- Llamadas de UI desde hilos de fondo (background threads) deben hacerse con `page.run_task(async_fn)` para ejecutarse en el event loop correcto de Flet
- Las fotos de contactos se almacenan en `FLET_APP_STORAGE_DATA/photos/` (Android) o `~/.celebria/photos/` (desktop)
- Exportar JSON en Android usa `save_file(src_bytes=)` (requiere bytes); importar usa `pick_files(with_data=True)` (bytes más confiable que path en Android)

---

## 👤 Autor

**Pedro Espinal** — Todos los derechos reservados © 2026
